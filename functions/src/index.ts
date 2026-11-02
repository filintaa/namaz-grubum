import {initializeApp} from "firebase-admin/app";
import {FieldValue, GeoPoint, Timestamp, getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {getStorage} from "firebase-admin/storage";
import {getAuth} from "firebase-admin/auth";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {createHash, randomUUID} from "node:crypto";
import sharp from "sharp";
import {CalculationMethod, Coordinates, Madhab, PrayerTimes} from "adhan";
import tzLookup from "tz-lookup";

initializeApp();

const db = getFirestore();
const prayerNames = new Set(["fajr", "dhuhr", "asr", "maghrib", "isha"]);
const photoLifetimeMs = 12 * 60 * 60 * 1000;
const completedStatuses = new Set(["completed", "completed_with_photo", "qada_completed"]);

type Role = "owner" | "moderator" | "member";

function requireAuth(uid: string | undefined): string {
  if (!uid) throw new HttpsError("unauthenticated", "Oturum açmanız gerekiyor.");
  return uid;
}

function requireModerator(request: {auth?: {uid: string; token: Record<string, unknown>}}): string {
  const userId = requireAuth(request.auth?.uid);
  if (request.auth?.token.admin !== true && request.auth?.token.moderator !== true) {
    throw new HttpsError("permission-denied", "Moderasyon yetkisi gerekli.");
  }
  return userId;
}

async function notifyUser(userId: string, title: string, body: string): Promise<void> {
  const devices = await db.collection(`users/${userId}/devices`).where("enabled", "==", true).get();
  const tokens = devices.docs.map((device) => device.data().token)
    .filter((token): token is string => typeof token === "string" && token.length > 0);
  if (tokens.length === 0) return;
  await getMessaging().sendEachForMulticast({
    tokens: [...new Set(tokens)].slice(0, 500),
    notification: {title, body},
    data: {type: "moderation_result"},
  });
}

function requiredString(value: unknown, field: string, maxLength = 128): string {
  if (typeof value !== "string" || value.trim().length === 0 || value.length > maxLength) {
    throw new HttpsError("invalid-argument", `${field} geçersiz.`);
  }
  return value.trim();
}

async function enforceRateLimit(
  userId: string,
  action: string,
  limit: number,
  windowSeconds: number,
): Promise<void> {
  const now = Timestamp.now();
  const bucket = Math.floor(now.seconds / windowSeconds);
  const reference = db.doc(`rateLimits/${userId}_${action}_${bucket}`);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const count = Number(snapshot.data()?.count ?? 0);
    if (count >= limit) {
      throw new HttpsError("resource-exhausted", "İşlem limiti doldu. Lütfen daha sonra tekrar deneyin.");
    }
    transaction.set(reference, {
      userId,
      action,
      count: count + 1,
      updatedAt: now,
      expiresAt: Timestamp.fromMillis(now.toMillis() + windowSeconds * 2_000),
    }, {merge: true});
  });
}

function normalizeSearch(value: string): string {
  return value
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/ı/g, "i")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function groupSearchPrefixes(...values: Array<string | null | undefined>): string[] {
  const words = values.flatMap((value) => normalizeSearch(value ?? "").split(" "))
    .filter((word) => word.length >= 2);
  const prefixes = new Set<string>();
  for (const word of words) {
    for (let length = 2; length <= Math.min(word.length, 20); length += 1) {
      prefixes.add(word.slice(0, length));
    }
  }
  return [...prefixes].slice(0, 200);
}

function dateKeyInTimezone(date: Date, timezone: string): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const value = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${value.year}-${value.month}-${value.day}`;
}

function addDateKeyDays(dateKey: string, days: number): string {
  const date = new Date(`${dateKey}T12:00:00.000Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

async function validateCurrentDateKey(
  userId: string,
  prayer: string,
  dateKey: string,
  allowPreviousIsha = true,
): Promise<void> {
  const profile = await db.doc(`users/${userId}`).get();
  const timezone = typeof profile.data()?.timezone === "string"
    ? profile.data()?.timezone as string
    : "Europe/Istanbul";
  const current = dateKeyInTimezone(new Date(), timezone);
  const previous = addDateKeyDays(current, -1);
  if (dateKey !== current && !(allowPreviousIsha && prayer === "isha" && dateKey === previous)) {
    throw new HttpsError("invalid-argument", "Yalnızca güncel namaz günü kullanılabilir.");
  }
}

export function prayerTimesFor(
  dateKey: string,
  latitude: number,
  longitude: number,
  timezone: string,
  madhhab: string,
): PrayerTimes {
  const coordinates = new Coordinates(latitude, longitude);
  const usesTurkeyMethod = timezone === "Europe/Istanbul";
  const parameters = usesTurkeyMethod
    ? CalculationMethod.Turkey()
    : CalculationMethod.MoonsightingCommittee();
  // Diyanet's published Turkey timetable uses the earlier Asr boundary.
  // Applying Hanafi again on top of CalculationMethod.Turkey moves Asr about
  // 50 minutes later than the official timetable. Outside Turkey the user's
  // selected madhhab remains authoritative.
  parameters.madhab = usesTurkeyMethod
    ? Madhab.Shafi
    : madhhab === "hanafi" ? Madhab.Hanafi : Madhab.Shafi;
  return new PrayerTimes(coordinates, new Date(`${dateKey}T12:00:00.000Z`), parameters);
}

async function activeMembership(groupId: string, userId: string): Promise<Role> {
  const snapshot = await db.doc(`groups/${groupId}/members/${userId}`).get();
  const data = snapshot.data();
  if (!snapshot.exists || data?.status !== "active") {
    throw new HttpsError("permission-denied", "Aktif grup üyeliği gerekli.");
  }
  return data?.role as Role;
}

export const registerDevice = onCall({region: "europe-west1"}, async (request) => {
  const userId = requireAuth(request.auth?.uid);
  const token = requiredString(request.data?.token, "token", 4096);
  const platform = requiredString(request.data?.platform, "platform", 16);
  if (!["android", "ios"].includes(platform)) {
    throw new HttpsError("invalid-argument", "Cihaz platformu geçersiz.");
  }

  const tokenHash = createHash("sha256").update(token).digest("hex");
  const profile = await db.doc(`users/${userId}`).get();
  const enabled = profile.data()?.notificationPreferences?.enabled !== false;
  const existingOwners = await db.collectionGroup("devices")
    .where("token", "==", token)
    .get();
  const batch = db.batch();
  existingOwners.docs
    .filter((device) => device.ref.parent.parent?.id !== userId)
    .forEach((device) => batch.delete(device.ref));
  batch.set(db.doc(`users/${userId}/devices/${tokenHash}`), {
    token,
    platform,
    enabled,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  await batch.commit();
  return {registered: true};
});

export const setNotificationsEnabled = onCall({region: "europe-west1"}, async (request) => {
  const userId = requireAuth(request.auth?.uid);
  const enabled = request.data?.enabled === true;
  const devices = await db.collection(`users/${userId}/devices`).get();
  const batch = db.batch();
  devices.docs.forEach((device) => batch.update(device.ref, {enabled, updatedAt: FieldValue.serverTimestamp()}));
  batch.update(db.doc(`users/${userId}`), {
    "notificationPreferences.enabled": enabled,
    updatedAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return {enabled};
});

export const discoverGroups = onCall({region: "europe-west1"}, async (request) => {
  const userId = requireAuth(request.auth?.uid);
  const profile = await db.doc(`users/${userId}`).get();
  const user = profile.data();
  if (!profile.exists || user?.status !== "active" || typeof user.gender !== "string") {
    throw new HttpsError("failed-precondition", "Aktif kullanıcı profili gerekli.");
  }
  const rawQuery = typeof request.data?.query === "string" ? request.data.query.slice(0, 80) : "";
  const normalizedQuery = normalizeSearch(rawQuery);
  const searchPrefix = normalizedQuery.split(" ").find((word) => word.length >= 2) ?? "";
  const limit = Math.max(1, Math.min(Number(request.data?.limit ?? 20), 30));
  let query: FirebaseFirestore.Query = db.collection("groups")
    .where("gender", "==", user.gender)
    .where("status", "==", "active");
  if (searchPrefix) query = query.where("searchPrefixes", "array-contains", searchPrefix);
  query = query.orderBy("createdAt", "desc").orderBy("__name__").limit(limit + 1);
  if (typeof request.data?.cursor === "string" && request.data.cursor.length <= 512) {
    try {
      const decoded = JSON.parse(Buffer.from(request.data.cursor, "base64url").toString("utf8")) as
        {createdAt: number; id: string};
      if (Number.isFinite(decoded.createdAt) && typeof decoded.id === "string") {
        query = query.startAfter(Timestamp.fromMillis(decoded.createdAt), decoded.id);
      }
    } catch (_) {
      throw new HttpsError("invalid-argument", "Sayfalama anahtarı geçersiz.");
    }
  }
  const snapshot = await query.get();
  const page = snapshot.docs.slice(0, limit);
  const last = page.at(-1);
  const nextCursor = snapshot.docs.length > limit && last
    ? Buffer.from(JSON.stringify({
      createdAt: (last.data().createdAt as Timestamp).toMillis(), id: last.id,
    })).toString("base64url")
    : null;
  return {
    groups: page.map((document) => ({id: document.id, ...document.data()})),
    nextCursor,
  };
});

export const syncPrayerSchedule = onCall({region: "europe-west1"}, async (request) => {
  const userId = requireAuth(request.auth?.uid);
  const latitude = Number(request.data?.latitude);
  const longitude = Number(request.data?.longitude);
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90 ||
      !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    throw new HttpsError("invalid-argument", "Konum koordinatları geçersiz.");
  }
  await enforceRateLimit(userId, "sync_prayer_schedule", 12, 3_600);
  const profileRef = db.doc(`users/${userId}`);
  const profile = await profileRef.get();
  const data = profile.data();
  if (!profile.exists || data?.status !== "active") {
    throw new HttpsError("failed-precondition", "Aktif kullanıcı profili gerekli.");
  }
  let timezone: string;
  try {
    timezone = tzLookup(latitude, longitude);
  } catch (_) {
    throw new HttpsError("invalid-argument", "Koordinatlar için saat dilimi bulunamadı.");
  }
  const madhhab = data.madhhab === "shafii" ? "shafii" : "hanafi";
  const usesTurkeyMethod = timezone === "Europe/Istanbul";
  const todayKey = dateKeyInTimezone(new Date(), timezone);
  const batch = db.batch();
  for (let day = 0; day < 8; day += 1) {
    const dateKey = addDateKeyDays(todayKey, day);
    const nextDateKey = addDateKeyDays(todayKey, day + 1);
    const times = prayerTimesFor(dateKey, latitude, longitude, timezone, madhhab);
    const nextTimes = prayerTimesFor(nextDateKey, latitude, longitude, timezone, madhhab);
    const windows = {
      fajr: {startsAt: Timestamp.fromDate(times.fajr), endsAt: Timestamp.fromDate(times.sunrise)},
      dhuhr: {startsAt: Timestamp.fromDate(times.dhuhr), endsAt: Timestamp.fromDate(times.asr)},
      asr: {startsAt: Timestamp.fromDate(times.asr), endsAt: Timestamp.fromDate(times.maghrib)},
      maghrib: {startsAt: Timestamp.fromDate(times.maghrib), endsAt: Timestamp.fromDate(times.isha)},
      isha: {startsAt: Timestamp.fromDate(times.isha), endsAt: Timestamp.fromDate(nextTimes.fajr)},
    };
    batch.set(db.doc(`users/${userId}/prayerDays/${dateKey}`), {
      dateKey,
      windows,
      timezone,
      coordinates: new GeoPoint(latitude, longitude),
      calculationMethod: usesTurkeyMethod ? "turkey" : "moonsighting_committee",
      madhhabPreference: madhhab,
      asrCalculation: usesTurkeyMethod ? "diyanet" : madhhab,
      generatedAt: FieldValue.serverTimestamp(),
      source: "adhan_4.4.6_server",
    });
  }
  batch.update(profileRef, {
    timezone,
    prayerCoordinates: new GeoPoint(latitude, longitude),
    prayerLocationSource: request.data?.locationSource === "device" ? "device" : "city",
    prayerLocationCity: request.data?.locationSource === "city" &&
      typeof request.data?.locationCity === "string"
      ? request.data.locationCity.trim().slice(0, 80)
      : FieldValue.delete(),
    locationEnabled: request.data?.locationEnabled === true,
    prayerScheduleUpdatedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return {synced: true, timezone, fromDate: todayKey, days: 8};
});

export const createGroup = onCall({region: "europe-west1"}, async (request) => {
  const userId = requireAuth(request.auth?.uid);
  const name = requiredString(request.data?.name, "name", 60);
  const countryCode = requiredString(request.data?.countryCode, "countryCode", 2).toUpperCase();
  const verificationType = requiredString(request.data?.verificationType, "verificationType", 16);
  const idempotencyKey = requiredString(request.data?.idempotencyKey, "idempotencyKey", 128);
  const logoEmoji = typeof request.data?.logoEmoji === "string" && request.data.logoEmoji.length <= 12
    ? request.data.logoEmoji
    : null;
  const prayers = Array.isArray(request.data?.prayers)
    ? [...new Set(request.data.prayers.filter((value: unknown) => typeof value === "string"))]
    : [];
  if (prayers.length === 0 || prayers.some((prayer) => !prayerNames.has(prayer as string))) {
    throw new HttpsError("invalid-argument", "En az bir geçerli namaz seçilmeli.");
  }
  if (!["button", "photo"].includes(verificationType)) {
    throw new HttpsError("invalid-argument", "Doğrulama tipi geçersiz.");
  }

  const groupRef = db.collection("groups").doc();
  const userRef = db.doc(`users/${userId}`);
  const memberRef = groupRef.collection("members").doc(userId);
  const membershipRef = db.doc(`users/${userId}/groupMemberships/${groupRef.id}`);
  const requestRef = db.doc(`idempotency/${userId}_${idempotencyKey}`);
  const now = Timestamp.now();

  return db.runTransaction(async (transaction) => {
    const [previousRequest, userSnapshot] = await Promise.all([
      transaction.get(requestRef),
      transaction.get(userRef),
    ]);
    if (previousRequest.exists) return previousRequest.data()?.result;
    const user = userSnapshot.data();
    if (!userSnapshot.exists || user?.status !== "active") {
      throw new HttpsError("failed-precondition", "Aktif kullanıcı profili gerekli.");
    }
    if (Number(user.activeGroupCount ?? 0) >= 3) {
      throw new HttpsError("resource-exhausted", "En fazla 3 gruba katılabilirsiniz.");
    }
    const group = {
      name,
      logoUrl: null,
      logoEmoji,
      logoObjectKey: null,
      ownerId: userId,
      moderatorIds: [],
      gender: user.gender,
      countryCode,
      city: typeof request.data?.city === "string" ? request.data.city.trim().slice(0, 80) : null,
      searchPrefixes: groupSearchPrefixes(
        name,
        typeof request.data?.city === "string" ? request.data.city : null,
        countryCode,
      ),
      prayers,
      verificationType,
      joinApprovalRequired: request.data?.joinApprovalRequired === true,
      memberCount: 1,
      activeMemberCount: 1,
      capacity: 50,
      currentStreak: 0,
      participationRate: 0,
      createdAt: now,
      status: "active",
    };
    const denormalizedMember = {
      role: "owner",
      joinedAt: now,
      status: "active",
      displayName: user.displayName,
      city: user.city ?? null,
      countryCode: user.countryCode,
      personalGroupStats: {sevenDayCompleted: 0, thirtyDayCompleted: 0},
    };
    const response = {groupId: groupRef.id};
    transaction.create(groupRef, group);
    transaction.create(memberRef, denormalizedMember);
    transaction.create(membershipRef, {groupId: groupRef.id, role: "owner", status: "active", joinedAt: now});
    transaction.update(userRef, {activeGroupCount: FieldValue.increment(1), updatedAt: now});
    transaction.create(requestRef, {
      userId,
      operation: "createGroup",
      result: response,
      createdAt: now,
      expiresAt: Timestamp.fromMillis(now.toMillis() + 86_400_000),
    });
    return response;
  });
});

export const joinGroup = onCall({region: "europe-west1"}, async (request) => {
  const userId = requireAuth(request.auth?.uid);
  const groupId = requiredString(request.data?.groupId, "groupId");
  const idempotencyKey = requiredString(request.data?.idempotencyKey, "idempotencyKey", 128);
  const groupRef = db.doc(`groups/${groupId}`);
  const memberRef = groupRef.collection("members").doc(userId);
  const membershipRef = db.doc(`users/${userId}/groupMemberships/${groupId}`);
  const requestRef = db.doc(`idempotency/${userId}_${idempotencyKey}`);
  const now = Timestamp.now();
  await enforceRateLimit(userId, "join_group", 10, 3_600);
  const outcome = await db.runTransaction(async (transaction) => {
    const [previous, groupSnapshot, userSnapshot, memberSnapshot] = await Promise.all([
      transaction.get(requestRef), transaction.get(groupRef), transaction.get(db.doc(`users/${userId}`)), transaction.get(memberRef),
    ]);
    if (previous.exists) {
      return {
        response: previous.data()?.result,
        shouldNotifyManagers: false,
        groupName: "",
        requesterName: "",
      };
    }
    const group = groupSnapshot.data();
    const user = userSnapshot.data();
    if (!groupSnapshot.exists || group?.status !== "active") throw new HttpsError("not-found", "Grup bulunamadı.");
    if (!userSnapshot.exists || user?.status !== "active") throw new HttpsError("failed-precondition", "Aktif kullanıcı profili gerekli.");
    if (memberSnapshot.data()?.status === "active") return {approved: true, alreadyMember: true};
    const rejoinAllowedAt = memberSnapshot.data()?.rejoinAllowedAt as Timestamp | undefined;
    if (["removed", "suspended"].includes(memberSnapshot.data()?.status as string) &&
        (!rejoinAllowedAt || rejoinAllowedAt.toMillis() > now.toMillis())) {
      throw new HttpsError("permission-denied", "Bu gruba yeniden katılımınız geçici olarak kapalı.");
    }
    if (Number(user.activeGroupCount ?? 0) >= 3) throw new HttpsError("resource-exhausted", "En fazla 3 gruba katılabilirsiniz.");
    if (Number(group.memberCount ?? 0) >= Number(group.capacity ?? 50)) throw new HttpsError("resource-exhausted", "Grup dolu.");
    const approved = group.joinApprovalRequired !== true;
    if (approved) {
      transaction.set(memberRef, {role: "member", status: "active", joinedAt: now, displayName: user.displayName, city: user.city ?? null, countryCode: user.countryCode, personalGroupStats: {sevenDayCompleted: 0, thirtyDayCompleted: 0}});
      transaction.set(membershipRef, {groupId, role: "member", status: "active", joinedAt: now});
      transaction.update(groupRef, {memberCount: FieldValue.increment(1), activeMemberCount: FieldValue.increment(1), updatedAt: now});
      transaction.update(userSnapshot.ref, {activeGroupCount: FieldValue.increment(1), updatedAt: now});
    } else {
      transaction.set(groupRef.collection("joinRequests").doc(userId), {userId, displayName: user.displayName, city: user.city ?? null, countryCode: user.countryCode, status: "pending", createdAt: now}, {merge: true});
    }
    const result = {approved, pending: !approved};
    transaction.create(requestRef, {userId, operation: "joinGroup", result, createdAt: now, expiresAt: Timestamp.fromMillis(now.toMillis() + 86_400_000)});
    return {
      response: result,
      shouldNotifyManagers: !approved,
      groupName: typeof group.name === "string" ? group.name : "Grubun",
      requesterName: typeof user.displayName === "string" ? user.displayName : "Bir kullanıcı",
    };
  });
  if (outcome.shouldNotifyManagers) {
    const members = await groupRef.collection("members")
      .where("status", "==", "active")
      .get();
    const managerIds = members.docs
      .filter((member) => ["owner", "moderator"].includes(member.data().role as string))
      .map((member) => member.id)
      .filter((managerId) => managerId !== userId);
    await Promise.allSettled(managerIds.map((managerId) => notifyUser(
      managerId,
      "Yeni katılım isteği",
      `${outcome.requesterName}, ${outcome.groupName} grubuna katılmak istiyor.`,
    )));
  }
  return outcome.response;
});

export const leaveGroup = onCall({region: "europe-west1"}, async (request) => {
  const userId = requireAuth(request.auth?.uid);
  const groupId = requiredString(request.data?.groupId, "groupId");
  const groupRef = db.doc(`groups/${groupId}`);
  const memberRef = groupRef.collection("members").doc(userId);
  const membershipRef = db.doc(`users/${userId}/groupMemberships/${groupId}`);
  await db.runTransaction(async (transaction) => {
    const [groupSnapshot, memberSnapshot] = await Promise.all([transaction.get(groupRef), transaction.get(memberRef)]);
    if (!memberSnapshot.exists || memberSnapshot.data()?.status !== "active") throw new HttpsError("failed-precondition", "Aktif üyelik bulunamadı.");
    if (memberSnapshot.data()?.role === "owner") throw new HttpsError("failed-precondition", "Grup sahibi önce sahipliği devretmelidir.");
    transaction.update(memberRef, {status: "left", leftAt: Timestamp.now()});
    transaction.delete(membershipRef);
    transaction.update(groupSnapshot.ref, {memberCount: FieldValue.increment(-1), activeMemberCount: FieldValue.increment(-1), updatedAt: FieldValue.serverTimestamp()});
    transaction.update(db.doc(`users/${userId}`), {activeGroupCount: FieldValue.increment(-1), updatedAt: FieldValue.serverTimestamp()});
  });
  return {left: true};
});

export const transferGroupOwnership = onCall({region: "europe-west1"}, async (request) => {
  const ownerId = requireAuth(request.auth?.uid);
  const groupId = requiredString(request.data?.groupId, "groupId");
  const targetUserId = requiredString(request.data?.targetUserId, "targetUserId");
  if (targetUserId === ownerId) {
    throw new HttpsError("invalid-argument", "Yeni sahip farklı bir üye olmalıdır.");
  }
  const groupRef = db.doc(`groups/${groupId}`);
  const ownerMemberRef = groupRef.collection("members").doc(ownerId);
  const targetMemberRef = groupRef.collection("members").doc(targetUserId);
  await db.runTransaction(async (transaction) => {
    const [group, ownerMember, targetMember] = await Promise.all([
      transaction.get(groupRef), transaction.get(ownerMemberRef), transaction.get(targetMemberRef),
    ]);
    if (!group.exists || group.data()?.ownerId !== ownerId || ownerMember.data()?.role !== "owner") {
      throw new HttpsError("permission-denied", "Sahipliği yalnızca mevcut grup sahibi devredebilir.");
    }
    if (!targetMember.exists || targetMember.data()?.status !== "active") {
      throw new HttpsError("failed-precondition", "Yeni sahip aktif bir grup üyesi olmalıdır.");
    }
    const moderators = Array.isArray(group.data()?.moderatorIds)
      ? group.data()?.moderatorIds.filter((id: unknown) => typeof id === "string" && id !== targetUserId)
      : [];
    if (!moderators.includes(ownerId)) moderators.push(ownerId);
    transaction.update(groupRef, {
      ownerId: targetUserId,
      moderatorIds: moderators,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(ownerMemberRef, {role: "moderator", updatedAt: FieldValue.serverTimestamp()});
    transaction.update(targetMemberRef, {role: "owner", updatedAt: FieldValue.serverTimestamp()});
    transaction.update(db.doc(`users/${ownerId}/groupMemberships/${groupId}`), {
      role: "moderator", updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(db.doc(`users/${targetUserId}/groupMemberships/${groupId}`), {
      role: "owner", updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return {transferred: true};
});

export const setMemberRole = onCall({region: "europe-west1"}, async (request) => {
  const ownerId = requireAuth(request.auth?.uid);
  const groupId = requiredString(request.data?.groupId, "groupId");
  const targetUserId = requiredString(request.data?.targetUserId, "targetUserId");
  const nextRole = requiredString(request.data?.role, "role", 16) as Role;
  if (!['moderator', 'member'].includes(nextRole) || targetUserId === ownerId) {
    throw new HttpsError("invalid-argument", "Üye rolü geçersiz.");
  }
  const groupRef = db.doc(`groups/${groupId}`);
  const targetMemberRef = groupRef.collection("members").doc(targetUserId);
  await db.runTransaction(async (transaction) => {
    const [group, target] = await Promise.all([
      transaction.get(groupRef), transaction.get(targetMemberRef),
    ]);
    if (!group.exists || group.data()?.status !== "active" || group.data()?.ownerId !== ownerId) {
      throw new HttpsError("permission-denied", "Rolleri yalnızca grup sahibi değiştirebilir.");
    }
    if (!target.exists || target.data()?.status !== "active" || target.data()?.role === "owner") {
      throw new HttpsError("failed-precondition", "Aktif üye bulunamadı.");
    }
    const currentModerators = Array.isArray(group.data()?.moderatorIds)
      ? group.data()?.moderatorIds.filter((id: unknown) => typeof id === "string")
      : [];
    const moderatorIds = nextRole === "moderator"
      ? [...new Set([...currentModerators, targetUserId])]
      : currentModerators.filter((id: string) => id !== targetUserId);
    transaction.update(groupRef, {moderatorIds, updatedAt: FieldValue.serverTimestamp()});
    transaction.update(targetMemberRef, {role: nextRole, updatedAt: FieldValue.serverTimestamp()});
    transaction.update(db.doc(`users/${targetUserId}/groupMemberships/${groupId}`), {
      role: nextRole, updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return {updated: true, role: nextRole};
});

export const removeGroupMember = onCall({region: "europe-west1"}, async (request) => {
  const managerId = requireAuth(request.auth?.uid);
  const groupId = requiredString(request.data?.groupId, "groupId");
  const targetUserId = requiredString(request.data?.targetUserId, "targetUserId");
  if (targetUserId === managerId) {
    throw new HttpsError("invalid-argument", "Kendinizi bu ekrandan çıkaramazsınız.");
  }
  const groupRef = db.doc(`groups/${groupId}`);
  const managerRef = groupRef.collection("members").doc(managerId);
  const targetRef = groupRef.collection("members").doc(targetUserId);
  await db.runTransaction(async (transaction) => {
    const [group, manager, target] = await Promise.all([
      transaction.get(groupRef), transaction.get(managerRef), transaction.get(targetRef),
    ]);
    const managerRole = manager.data()?.role as Role | undefined;
    const targetRole = target.data()?.role as Role | undefined;
    if (!group.exists || group.data()?.status !== "active" || manager.data()?.status !== "active" || !['owner', 'moderator'].includes(managerRole ?? "")) {
      throw new HttpsError("permission-denied", "Yönetici yetkisi gerekli.");
    }
    if (!target.exists || target.data()?.status !== "active" || targetRole === "owner") {
      throw new HttpsError("failed-precondition", "Çıkarılabilir aktif üye bulunamadı.");
    }
    if (managerRole === "moderator" && targetRole !== "member") {
      throw new HttpsError("permission-denied", "Yöneticiler diğer yöneticileri çıkaramaz.");
    }
    const moderators = Array.isArray(group.data()?.moderatorIds)
      ? group.data()?.moderatorIds.filter((id: unknown) => typeof id === "string" && id !== targetUserId)
      : [];
    const now = Timestamp.now();
    const rejoinAllowedAt = Timestamp.fromMillis(now.toMillis() + 7 * 86_400_000);
    transaction.update(targetRef, {status: "removed", removedAt: now, removedBy: managerId, rejoinAllowedAt});
    transaction.set(db.doc(`users/${targetUserId}/groupMemberships/${groupId}`), {
      groupId, role: targetRole ?? "member", status: "removed", removedAt: now, rejoinAllowedAt,
    }, {merge: true});
    transaction.update(groupRef, {
      moderatorIds: moderators,
      memberCount: FieldValue.increment(-1),
      activeMemberCount: FieldValue.increment(-1),
      updatedAt: now,
    });
    transaction.update(db.doc(`users/${targetUserId}`), {
      activeGroupCount: FieldValue.increment(-1), updatedAt: now,
    });
  });
  return {removed: true};
});

export const suspendGroupMember = onCall({region: "europe-west1"}, async (request) => {
  const managerId = requireAuth(request.auth?.uid);
  const groupId = requiredString(request.data?.groupId, "groupId");
  const targetUserId = requiredString(request.data?.targetUserId, "targetUserId");
  const durationDays = Number(request.data?.durationDays);
  if (![1, 7, 30].includes(durationDays) || targetUserId === managerId) {
    throw new HttpsError("invalid-argument", "Uzaklaştırma süresi veya hedef geçersiz.");
  }
  const groupRef = db.doc(`groups/${groupId}`);
  const managerRef = groupRef.collection("members").doc(managerId);
  const targetRef = groupRef.collection("members").doc(targetUserId);
  await db.runTransaction(async (transaction) => {
    const [group, manager, target] = await Promise.all([
      transaction.get(groupRef), transaction.get(managerRef), transaction.get(targetRef),
    ]);
    const managerRole = manager.data()?.role as Role | undefined;
    const targetRole = target.data()?.role as Role | undefined;
    if (!group.exists || group.data()?.status !== "active" || manager.data()?.status !== "active" ||
        !["owner", "moderator"].includes(managerRole ?? "")) {
      throw new HttpsError("permission-denied", "Yönetici yetkisi gerekli.");
    }
    if (!target.exists || target.data()?.status !== "active" || targetRole === "owner" ||
        (managerRole === "moderator" && targetRole !== "member")) {
      throw new HttpsError("permission-denied", "Bu üye uzaklaştırılamaz.");
    }
    const now = Timestamp.now();
    const rejoinAllowedAt = Timestamp.fromMillis(now.toMillis() + durationDays * 86_400_000);
    transaction.update(targetRef, {
      status: "suspended", suspendedAt: now, suspendedBy: managerId,
      suspensionDays: durationDays, rejoinAllowedAt,
    });
    transaction.set(db.doc(`users/${targetUserId}/groupMemberships/${groupId}`), {
      groupId, role: targetRole ?? "member", status: "suspended", suspendedAt: now, rejoinAllowedAt,
    }, {merge: true});
    transaction.update(groupRef, {
      memberCount: FieldValue.increment(-1), activeMemberCount: FieldValue.increment(-1), updatedAt: now,
    });
    transaction.update(db.doc(`users/${targetUserId}`), {
      activeGroupCount: FieldValue.increment(-1), updatedAt: now,
    });
  });
  return {suspended: true, durationDays};
});

export const blockUser = onCall({region: "europe-west1"}, async (request) => {
  const userId = requireAuth(request.auth?.uid);
  const targetUserId = requiredString(request.data?.targetUserId, "targetUserId");
  if (targetUserId === userId) throw new HttpsError("invalid-argument", "Kendinizi engelleyemezsiniz.");
  const target = await db.doc(`users/${targetUserId}`).get();
  if (!target.exists) throw new HttpsError("not-found", "Kullanıcı bulunamadı.");
  await db.doc(`users/${userId}/blockedUsers/${targetUserId}`).set({
    targetUserId, createdAt: FieldValue.serverTimestamp(),
  });
  return {blocked: true};
});

export const unblockUser = onCall({region: "europe-west1"}, async (request) => {
  const userId = requireAuth(request.auth?.uid);
  const targetUserId = requiredString(request.data?.targetUserId, "targetUserId");
  await db.doc(`users/${userId}/blockedUsers/${targetUserId}`).delete();
  return {blocked: false};
});

export const archiveGroup = onCall({region: "europe-west1"}, async (request) => {
  const ownerId = requireAuth(request.auth?.uid);
  const groupId = requiredString(request.data?.groupId, "groupId");
  const groupRef = db.doc(`groups/${groupId}`);
  await db.runTransaction(async (transaction) => {
    const group = await transaction.get(groupRef);
    if (!group.exists || group.data()?.status !== "active" || group.data()?.ownerId !== ownerId) {
      throw new HttpsError("permission-denied", "Grubu yalnızca sahibi arşivleyebilir.");
    }
    const members = await transaction.get(
      groupRef.collection("members").where("status", "==", "active").limit(50),
    );
    const now = Timestamp.now();
    transaction.update(groupRef, {
      status: "archived", archivedAt: now, archivedBy: ownerId,
      activeMemberCount: 0, updatedAt: now,
    });
    for (const member of members.docs) {
      transaction.update(member.ref, {status: "archived", archivedAt: now});
      transaction.set(db.doc(`users/${member.id}/groupMemberships/${groupId}`), {
        groupId, role: member.data().role ?? "member", status: "archived", archivedAt: now,
      }, {merge: true});
      transaction.update(db.doc(`users/${member.id}`), {
        activeGroupCount: FieldValue.increment(-1), updatedAt: now,
      });
    }
  });
  return {archived: true};
});

export const updateGroup = onCall({region: "europe-west1"}, async (request) => {
  const userId = requireAuth(request.auth?.uid);
  const groupId = requiredString(request.data?.groupId, "groupId");
  const name = requiredString(request.data?.name, "name", 60);
  const prayers = Array.isArray(request.data?.prayers) ? [...new Set(request.data.prayers.filter((value: unknown) => typeof value === "string"))] : [];
  if (prayers.length === 0 || prayers.some((prayer) => !prayerNames.has(prayer as string))) throw new HttpsError("invalid-argument", "En az bir geçerli namaz seçilmeli.");
  const role = await activeMembership(groupId, userId);
  if (!['owner', 'moderator'].includes(role)) throw new HttpsError("permission-denied", "Yönetici yetkisi gerekli.");
  const groupRef = db.doc(`groups/${groupId}`);
  const group = await groupRef.get();
  await groupRef.update({
    name,
    prayers,
    searchPrefixes: groupSearchPrefixes(name, group.data()?.city, group.data()?.countryCode),
    joinApprovalRequired: request.data?.joinApprovalRequired === true,
    updatedAt: FieldValue.serverTimestamp(),
  });
  return {updated: true};
});

export const resolveJoinRequest = onCall({region: "europe-west1"}, async (request) => {
  const managerId = requireAuth(request.auth?.uid);
  const groupId = requiredString(request.data?.groupId, "groupId");
  const targetUserId = requiredString(request.data?.targetUserId, "targetUserId");
  const approve = request.data?.approve === true;
  const role = await activeMembership(groupId, managerId);
  if (!['owner', 'moderator'].includes(role)) throw new HttpsError("permission-denied", "Yönetici yetkisi gerekli.");
  const groupRef = db.doc(`groups/${groupId}`);
  const joinRef = groupRef.collection("joinRequests").doc(targetUserId);
  await db.runTransaction(async (transaction) => {
    const [groupSnapshot, requestSnapshot, userSnapshot] = await Promise.all([transaction.get(groupRef), transaction.get(joinRef), transaction.get(db.doc(`users/${targetUserId}`))]);
    if (requestSnapshot.data()?.status !== "pending") throw new HttpsError("failed-precondition", "Bekleyen katılım isteği yok.");
    if (!approve) { transaction.update(joinRef, {status: "rejected", resolvedAt: Timestamp.now(), resolvedBy: managerId}); return; }
    if (Number(groupSnapshot.data()?.memberCount ?? 0) >= Number(groupSnapshot.data()?.capacity ?? 50)) throw new HttpsError("resource-exhausted", "Grup dolu.");
    const user = userSnapshot.data();
    if (!userSnapshot.exists || user?.status !== "active") throw new HttpsError("failed-precondition", "Aktif kullanıcı profili gerekli.");
    if (Number(user.activeGroupCount ?? 0) >= 3) throw new HttpsError("resource-exhausted", "Kullanıcı grup limitine ulaştı.");
    transaction.set(groupRef.collection("members").doc(targetUserId), {role: "member", status: "active", joinedAt: Timestamp.now(), displayName: user?.displayName ?? "Üye", city: user?.city ?? null, countryCode: user?.countryCode ?? null, personalGroupStats: {sevenDayCompleted: 0, thirtyDayCompleted: 0}});
    transaction.set(db.doc(`users/${targetUserId}/groupMemberships/${groupId}`), {groupId, role: "member", status: "active", joinedAt: Timestamp.now()});
    transaction.update(joinRef, {status: "approved", resolvedAt: Timestamp.now(), resolvedBy: managerId});
    transaction.update(groupRef, {memberCount: FieldValue.increment(1), activeMemberCount: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp()});
    transaction.update(userSnapshot.ref, {activeGroupCount: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp()});
  });
  return {approved: approve};
});

export const recordCheckin = onCall({region: "europe-west1"}, async (request) => {
  const userId = requireAuth(request.auth?.uid);
  const groupId = requiredString(request.data?.groupId, "groupId");
  const prayer = requiredString(request.data?.prayer, "prayer", 16);
  const dateKey = requiredString(request.data?.dateKey, "dateKey", 10);
  const action = requiredString(request.data?.action, "action", 16);
  const idempotencyKey = requiredString(request.data?.idempotencyKey, "idempotencyKey", 128);
  if (!prayerNames.has(prayer) || !["awake", "complete", "qada"].includes(action)) {
    throw new HttpsError("invalid-argument", "Namaz durumu geçersiz.");
  }
  if (action === "awake" && prayer !== "fajr") {
    throw new HttpsError("failed-precondition", "Kalktım durumu yalnızca Sabah için kullanılabilir.");
  }
  await activeMembership(groupId, userId);

  const userProfile = await db.doc(`users/${userId}`).get();
  const timezone = typeof userProfile.data()?.timezone === "string"
    ? userProfile.data()?.timezone as string
    : "Europe/Istanbul";
  const currentDateKey = dateKeyInTimezone(new Date(), timezone);
  const previousDateKey = addDateKeyDays(currentDateKey, -1);
  if (dateKey !== currentDateKey &&
      !(prayer === "isha" && action !== "qada" && dateKey === previousDateKey)) {
    throw new HttpsError("invalid-argument", "Yalnızca güncel namaz durumu kaydedilebilir.");
  }

  const groupRef = db.doc(`groups/${groupId}`);
  const scheduleRef = db.doc(`users/${userId}/prayerDays/${dateKey}`);
  const checkinRef = db.doc(`groups/${groupId}/prayerDays/${dateKey}/checkins/${userId}_${prayer}`);
  const statsRef = db.doc(`groups/${groupId}/dailyStats/${dateKey}`);
  const requestRef = db.doc(`idempotency/${userId}_${idempotencyKey}`);
  const now = Timestamp.now();

  const result = await db.runTransaction(async (transaction) => {
    const [requestSnapshot, groupSnapshot, scheduleSnapshot, checkinSnapshot] = await Promise.all([
      transaction.get(requestRef),
      transaction.get(groupRef),
      transaction.get(scheduleRef),
      transaction.get(checkinRef),
    ]);
    if (requestSnapshot.exists) return requestSnapshot.data()?.result;

    const group = groupSnapshot.data();
    if (!groupSnapshot.exists || !Array.isArray(group?.prayers) || !group.prayers.includes(prayer)) {
      throw new HttpsError("failed-precondition", "Bu grup seçilen namazı takip etmiyor.");
    }
    const window = scheduleSnapshot.data()?.windows?.[prayer] as
      {startsAt?: Timestamp; endsAt?: Timestamp} | undefined;
    if (!window?.startsAt || !window.endsAt) {
      throw new HttpsError("failed-precondition", "Güvenilir namaz vakti bulunamadı.");
    }
    const inWindow = now.toMillis() >= window.startsAt.toMillis()
      && now.toMillis() < window.endsAt.toMillis();
    if (action !== "qada" && !inWindow) {
      throw new HttpsError("failed-precondition", "Normal onay penceresi kapalı.");
    }
    if (action === "qada" && now.toMillis() < window.endsAt.toMillis()) {
      throw new HttpsError("failed-precondition", "Vakit devam ederken kaza kaydı oluşturulamaz.");
    }

    const previous = checkinSnapshot.data()?.status as string | undefined;
    if (completedStatuses.has(previous ?? "")) {
      return {status: previous, duplicate: true};
    }
    const status = action === "awake" ? "awake" : action === "complete" ? "completed" : "qada_completed";
    const checkin = {
      userId,
      prayer,
      dateKey,
      prayerStartAt: window.startsAt,
      prayerEndAt: window.endsAt,
      status,
      awakeAt: action === "awake" ? now : (checkinSnapshot.data()?.awakeAt ?? null),
      completedAt: action === "awake" ? null : now,
      photoId: null,
      updatedAt: now,
    };
    transaction.set(checkinRef, checkin, {merge: true});
    if (action === "awake" && previous !== "awake") {
      transaction.set(statsRef, {[prayer]: {awakeCount: FieldValue.increment(1)}}, {merge: true});
    }
    if (["complete", "qada"].includes(action) && !completedStatuses.has(previous ?? "")) {
      transaction.set(statsRef, {[prayer]: {
        completedCount: FieldValue.increment(1),
        ...(action === "qada" ? {qadaCount: FieldValue.increment(1)} : {}),
      }}, {merge: true});
    }
    const response = {status, duplicate: false};
    transaction.create(requestRef, {
      userId,
      operation: "recordCheckin",
      result: response,
      createdAt: now,
      expiresAt: Timestamp.fromMillis(now.toMillis() + 86_400_000),
    });
    return response;
  });
  return result;
});

export const recordAlarmAction = onCall({region: "europe-west1"}, async (request) => {
  const userId = requireAuth(request.auth?.uid);
  const prayer = requiredString(request.data?.prayer, "prayer", 16);
  const dateKey = requiredString(request.data?.dateKey, "dateKey", 10);
  const action = requiredString(request.data?.action, "action", 16);
  if (prayer !== "fajr" || action !== "awake") throw new HttpsError("invalid-argument", "Alarm eylemi geçersiz.");
  const schedule = await db.doc(`users/${userId}/prayerDays/${dateKey}`).get();
  const window = schedule.data()?.windows?.[prayer] as {startsAt?: Timestamp; endsAt?: Timestamp} | undefined;
  const now = Timestamp.now();
  if (!window?.startsAt || !window.endsAt || now.toMillis() < window.startsAt.toMillis() || now.toMillis() >= window.endsAt.toMillis()) {
    throw new HttpsError("failed-precondition", "Alarm eylemi yalnızca namaz vakti içinde kullanılabilir.");
  }
  const memberships = await db.collection(`users/${userId}/groupMemberships`).where("status", "==", "active").get();
  let updated = 0;
  for (const membership of memberships.docs) {
    const groupId = membership.data().groupId as string | undefined;
    if (!groupId) continue;
    const groupRef = db.doc(`groups/${groupId}`);
    const checkinRef = db.doc(`groups/${groupId}/prayerDays/${dateKey}/checkins/${userId}_${prayer}`);
    const statsRef = db.doc(`groups/${groupId}/dailyStats/${dateKey}`);
    const didUpdate = await db.runTransaction(async (transaction) => {
      const [group, checkin] = await Promise.all([transaction.get(groupRef), transaction.get(checkinRef)]);
      if (!Array.isArray(group.data()?.prayers) || !group.data()?.prayers.includes(prayer)) return false;
      const previous = checkin.data()?.status as string | undefined;
      if (["awake", "completed", "completed_with_photo"].includes(previous ?? "")) return false;
      transaction.set(checkinRef, {userId, prayer, dateKey, prayerStartAt: window.startsAt, prayerEndAt: window.endsAt, status: "awake", awakeAt: now, completedAt: null, photoId: null, updatedAt: now}, {merge: true});
      transaction.set(statsRef, {[prayer]: {awakeCount: FieldValue.increment(1)}}, {merge: true});
      return true;
    });
    if (didUpdate) updated += 1;
  }
  return {status: "awake", updatedGroups: updated};
});

export const wakeMember = onCall({region: "europe-west1"}, async (request) => {
  const senderId = requireAuth(request.auth?.uid);
  const groupId = requiredString(request.data?.groupId, "groupId");
  const targetUserId = requiredString(request.data?.targetUserId, "targetUserId");
  const prayer = requiredString(request.data?.prayer, "prayer", 16);
  const dateKey = requiredString(request.data?.dateKey, "dateKey", 10);
  if (!prayerNames.has(prayer) || senderId === targetUserId) {
    throw new HttpsError("invalid-argument", "Hatırlatma hedefi geçersiz.");
  }

  await enforceRateLimit(senderId, "wake_member", 20, 3_600);
  await validateCurrentDateKey(senderId, prayer, dateKey);

  const [, , senderBlocked, targetBlocked] = await Promise.all([
    activeMembership(groupId, senderId),
    activeMembership(groupId, targetUserId),
    db.doc(`users/${senderId}/blockedUsers/${targetUserId}`).get(),
    db.doc(`users/${targetUserId}/blockedUsers/${senderId}`).get(),
  ]);
  if (senderBlocked.exists || targetBlocked.exists) {
    throw new HttpsError("permission-denied", "Engellenen kullanıcılar arasında hatırlatma gönderilemez.");
  }

  const throttleId = `${groupId}_${dateKey}_${prayer}_${targetUserId}`;
  const throttleRef = db.doc(`wakeNudges/${throttleId}`);
  const now = Timestamp.now();
  const shouldSend = await db.runTransaction(async (transaction) => {
    const [current, checkin] = await Promise.all([
      transaction.get(throttleRef),
      transaction.get(db.doc(`groups/${groupId}/prayerDays/${dateKey}/checkins/${targetUserId}_${prayer}`)),
    ]);
    if (completedStatuses.has(checkin.data()?.status as string)) return false;
    const lastSentAt = current.data()?.lastSentAt as Timestamp | undefined;
    if (lastSentAt && now.toMillis() - lastSentAt.toMillis() < 180_000) {
      throw new HttpsError("resource-exhausted", "Bu üyeye kısa süre önce hatırlatma gönderildi.");
    }
    transaction.set(throttleRef, {
      groupId,
      targetUserId,
      prayer,
      dateKey,
      lastSentAt: now,
      expiresAt: Timestamp.fromMillis(now.toMillis() + 86_400_000),
    });
    return true;
  });
  if (!shouldSend) return {sent: false, reason: "already_completed"};

  const tokenSnapshot = await db.collection(`users/${targetUserId}/devices`).where("enabled", "==", true).get();
  const devices = tokenSnapshot.docs
    .map((document) => ({
      reference: document.ref,
      token: document.data().token as string | undefined,
    }))
    .filter((device): device is {reference: FirebaseFirestore.DocumentReference; token: string} =>
      typeof device.token === "string" && device.token.length > 0);
  const tokens = devices.map((device) => device.token);
  if (tokens.length > 0) {
    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: "Grubun seni bekliyor",
        body: "Namaz vakti devam ediyor.",
      },
      data: {type: "wake_nudge", groupId, prayer, dateKey},
      android: {priority: "high", ttl: 900_000, notification: {sound: "default"}},
      apns: {
        headers: {"apns-priority": "10", "apns-expiration": String(Math.floor(Date.now() / 1000) + 900)},
        payload: {aps: {sound: "default", interruptionLevel: "time-sensitive"}},
      },
    });
    const invalidTokenCodes = new Set([
      "messaging/invalid-registration-token",
      "messaging/registration-token-not-registered",
    ]);
    await Promise.all(response.responses.map((result, index) => {
      const device = devices[index];
      if (!device || !result.error || !invalidTokenCodes.has(result.error.code)) {
        return Promise.resolve();
      }
      return device.reference.delete();
    }));
  }
  return {sent: true};
});

export const sendAdminReminder = onCall({region: "europe-west1"}, async (request) => {
  const senderId = requireAuth(request.auth?.uid);
  const groupId = requiredString(request.data?.groupId, "groupId");
  const prayer = requiredString(request.data?.prayer, "prayer", 16);
  const dateKey = requiredString(request.data?.dateKey, "dateKey", 10);
  const role = await activeMembership(groupId, senderId);
  if (!prayerNames.has(prayer) || !["owner", "moderator"].includes(role)) {
    throw new HttpsError("permission-denied", "Yönetici yetkisi gerekli.");
  }
  await validateCurrentDateKey(senderId, prayer, dateKey);

  const counterRef = db.doc(`adminReminders/${groupId}_${dateKey}_${prayer}`);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(counterRef);
    const count = Number(snapshot.data()?.count ?? 0);
    if (count >= 2) throw new HttpsError("resource-exhausted", "Hatırlatma limiti doldu.");
    transaction.set(counterRef, {
      count: count + 1,
      groupId,
      prayer,
      dateKey,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  });

  const [members, checkins] = await Promise.all([
    db.collection(`groups/${groupId}/members`).where("status", "==", "active").get(),
    db.collection(`groups/${groupId}/prayerDays/${dateKey}/checkins`).where("prayer", "==", prayer).get(),
  ]);
  const completed = new Set(checkins.docs
    .filter((document) => ["completed", "completed_with_photo", "qada_completed"].includes(document.data().status as string))
    .map((document) => document.data().userId as string));
  const targetIds = members.docs.map((member) => member.id)
    .filter((id) => id !== senderId && !completed.has(id));
  const deviceSnapshots = await Promise.all(targetIds.map((id) =>
    db.collection(`users/${id}/devices`).where("enabled", "==", true).get()));
  const devices = deviceSnapshots.flatMap((snapshot) => snapshot.docs
    .map((device) => ({reference: device.ref, token: device.data().token as string | undefined}))
    .filter((device): device is {reference: FirebaseFirestore.DocumentReference; token: string} =>
      typeof device.token === "string" && device.token.length > 0));
  const uniqueDevices = [...new Map(devices.map((device) => [device.token, device])).values()];
  let successCount = 0;
  let failureCount = 0;
  const invalidTokenCodes = new Set([
    "messaging/invalid-registration-token",
    "messaging/registration-token-not-registered",
  ]);
  for (let index = 0; index < uniqueDevices.length; index += 500) {
    const chunk = uniqueDevices.slice(index, index + 500);
    const response = await getMessaging().sendEachForMulticast({
      tokens: chunk.map((device) => device.token),
      notification: {title: "Grubun seni bekliyor", body: "Namaz vakti devam ediyor."},
      data: {type: "admin_reminder", groupId, prayer, dateKey},
      android: {priority: "high", ttl: 900_000, notification: {sound: "default"}},
      apns: {
        headers: {"apns-priority": "10", "apns-expiration": String(Math.floor(Date.now() / 1000) + 900)},
        payload: {aps: {sound: "default", interruptionLevel: "time-sensitive"}},
      },
    });
    successCount += response.successCount;
    failureCount += response.failureCount;
    await Promise.all(response.responses.map((result, responseIndex) => {
      const device = chunk[responseIndex];
      return device && result.error && invalidTokenCodes.has(result.error.code)
        ? device.reference.delete()
        : Promise.resolve();
    }));
  }
  return {sent: true, targetCount: targetIds.length, tokenCount: uniqueDevices.length, successCount, failureCount};
});

export const reportContent = onCall({region: "europe-west1"}, async (request) => {
  const reporterId = requireAuth(request.auth?.uid);
  const targetType = requiredString(request.data?.targetType, "targetType", 16);
  const targetId = requiredString(request.data?.targetId, "targetId");
  const reason = requiredString(request.data?.reason, "reason", 64);
  if (!["photo", "user", "group"].includes(targetType)) {
    throw new HttpsError("invalid-argument", "Şikayet hedefi geçersiz.");
  }
  if (targetType === "user" && targetId === reporterId) {
    throw new HttpsError("invalid-argument", "Kendinizi şikayet edemezsiniz.");
  }
  await enforceRateLimit(reporterId, "report_content", 20, 86_400);

  const reportRef = db.doc(`reports/${targetType}_${targetId}_${reporterId}`);
  await db.runTransaction(async (transaction) => {
    const duplicate = await transaction.get(reportRef);
    if (duplicate.exists) throw new HttpsError("already-exists", "Bu içerik daha önce şikayet edildi.");

    let targetOwnerId: string | null = null;
    let groupId: string | null = null;
    let targetLabel = targetType;
    if (targetType === "photo") {
      const photoRef = db.doc(`photos/${targetId}`);
      const photoSnapshot = await transaction.get(photoRef);
      const photo = photoSnapshot.data();
      if (!photoSnapshot.exists || typeof photo?.groupId !== "string") {
        throw new HttpsError("not-found", "Fotoğraf bulunamadı.");
      }
      const memberRef = db.doc(`groups/${photo.groupId}/members/${reporterId}`);
      const groupRef = db.doc(`groups/${photo.groupId}`);
      const [memberSnapshot, groupSnapshot] = await Promise.all([
        transaction.get(memberRef),
        transaction.get(groupRef),
      ]);
      if (memberSnapshot.data()?.status !== "active") {
        throw new HttpsError("permission-denied", "Yalnızca grup üyeleri şikayet edebilir.");
      }
      targetOwnerId = photo.userId as string | null;
      groupId = photo.groupId as string;
      targetLabel = "Namaz fotoğrafı";
      const count = Number(photo.reportCount ?? 0) + 1;
      const memberCount = Number(groupSnapshot.data()?.memberCount ?? 0);
      const threshold = Math.max(3, Math.ceil(memberCount * 0.05));
      transaction.update(photoRef, {
        reportCount: count,
        ...(count >= threshold ? {status: "hidden_pending_review"} : {}),
      });
    } else if (targetType === "user") {
      const target = await transaction.get(db.doc(`users/${targetId}`));
      if (!target.exists || target.data()?.status !== "active") {
        throw new HttpsError("not-found", "Aktif kullanıcı bulunamadı.");
      }
      targetOwnerId = targetId;
      targetLabel = target.data()?.displayName as string ?? "Kullanıcı";
    } else {
      const target = await transaction.get(db.doc(`groups/${targetId}`));
      if (!target.exists || target.data()?.status !== "active") {
        throw new HttpsError("not-found", "Aktif grup bulunamadı.");
      }
      targetOwnerId = target.data()?.ownerId as string | null;
      groupId = targetId;
      targetLabel = target.data()?.name as string ?? "Grup";
    }

    transaction.create(reportRef, {
      reporterId,
      targetType,
      targetId,
      reason,
      targetOwnerId,
      groupId,
      targetLabel,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      status: "pending",
    });
  });
  return {reported: true};
});

export const listModerationReports = onCall({region: "europe-west1"}, async (request) => {
  requireModerator(request);
  const status = request.data?.status === "resolved" ? "resolved" : "pending";
  const reports = await db.collection("reports")
    .where("status", "==", status)
    .orderBy("createdAt", "desc")
    .limit(100)
    .get();
  return {
    reports: reports.docs.map((document) => {
      const data = document.data();
      const createdAt = data.createdAt as Timestamp | undefined;
      const resolvedAt = data.resolvedAt as Timestamp | undefined;
      return {
        id: document.id,
        reporterId: data.reporterId,
        targetType: data.targetType,
        targetId: data.targetId,
        targetLabel: data.targetLabel ?? data.targetType,
        reason: data.reason,
        status: data.status,
        resolution: data.resolution ?? null,
        createdAt: createdAt?.toDate().toISOString() ?? null,
        resolvedAt: resolvedAt?.toDate().toISOString() ?? null,
      };
    }),
  };
});

export const resolveModerationReport = onCall({region: "europe-west1"}, async (request) => {
  const moderatorId = requireModerator(request);
  const reportId = requiredString(request.data?.reportId, "reportId");
  const resolution = requiredString(request.data?.resolution, "resolution", 32);
  if (!["dismissed", "content_removed", "account_suspended"].includes(resolution)) {
    throw new HttpsError("invalid-argument", "Moderasyon kararı geçersiz.");
  }
  const reportRef = db.doc(`reports/${reportId}`);
  let reporterId = "";
  let suspendedUserId = "";
  let removedPhotoId = "";
  await db.runTransaction(async (transaction) => {
    const report = await transaction.get(reportRef);
    const data = report.data();
    if (!report.exists || data?.status !== "pending") {
      throw new HttpsError("failed-precondition", "Bekleyen şikayet bulunamadı.");
    }
    reporterId = data.reporterId as string;
    const targetType = data.targetType as string;
    const targetId = data.targetId as string;
    if (resolution === "content_removed") {
      if (targetType === "photo") {
        removedPhotoId = targetId;
        transaction.update(db.doc(`photos/${targetId}`), {
          status: "removed_by_moderator", moderatedAt: Timestamp.now(), moderatedBy: moderatorId,
        });
      } else if (targetType === "group") {
        const members = await transaction.get(
          db.collection(`groups/${targetId}/members`).where("status", "==", "active").limit(50),
        );
        const now = Timestamp.now();
        transaction.update(db.doc(`groups/${targetId}`), {
          status: "suspended", suspendedAt: now, suspendedBy: moderatorId,
          activeMemberCount: 0,
        });
        for (const member of members.docs) {
          transaction.update(member.ref, {status: "suspended", suspendedAt: now, suspendedBy: moderatorId});
          transaction.set(db.doc(`users/${member.id}/groupMemberships/${targetId}`), {
            groupId: targetId, status: "suspended", suspendedAt: now,
          }, {merge: true});
          transaction.update(db.doc(`users/${member.id}`), {
            activeGroupCount: FieldValue.increment(-1), updatedAt: now,
          });
        }
      } else {
        throw new HttpsError("failed-precondition", "Kullanıcı şikayetinde hesap kararı seçilmelidir.");
      }
    }
    if (resolution === "account_suspended") {
      const targetOwnerId = data.targetOwnerId as string | undefined;
      if (!targetOwnerId) throw new HttpsError("failed-precondition", "Hedef hesap bulunamadı.");
      transaction.update(db.doc(`users/${targetOwnerId}`), {
        status: "suspended", suspendedAt: Timestamp.now(), suspendedBy: moderatorId,
      });
      suspendedUserId = targetOwnerId;
    }
    transaction.update(reportRef, {
      status: "resolved", resolution, resolvedAt: Timestamp.now(), resolvedBy: moderatorId,
      updatedAt: Timestamp.now(),
    });
  });
  if (removedPhotoId) {
    const photoRef = db.doc(`photos/${removedPhotoId}`);
    const photo = await photoRef.get();
    const objectKey = photo.data()?.objectKey as string | undefined;
    if (objectKey) await getStorage().bucket().file(objectKey).delete({ignoreNotFound: true});
    await photoRef.update({objectKey: FieldValue.delete(), deletedAt: FieldValue.serverTimestamp()});
  }
  if (suspendedUserId) {
    const memberships = await db.collection(`users/${suspendedUserId}/groupMemberships`)
      .where("status", "==", "active")
      .get();
    for (const membership of memberships.docs) {
      const groupId = membership.data().groupId as string | undefined;
      if (!groupId) continue;
      const batch = db.batch();
      batch.set(db.doc(`groups/${groupId}/members/${suspendedUserId}`), {
        status: "suspended_by_moderation", suspendedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      batch.update(membership.ref, {
        status: "suspended_by_moderation", suspendedAt: FieldValue.serverTimestamp(),
      });
      batch.update(db.doc(`groups/${groupId}`), {
        memberCount: FieldValue.increment(-1), activeMemberCount: FieldValue.increment(-1),
        updatedAt: FieldValue.serverTimestamp(),
      });
      await batch.commit();
    }
    await db.doc(`users/${suspendedUserId}`).update({activeGroupCount: 0});
  }
  if (reporterId) {
    await notifyUser(
      reporterId,
      "Şikayetin incelendi",
      resolution === "dismissed" ? "İnceleme tamamlandı; işlem uygulanmadı." : "İnceleme tamamlandı ve gerekli işlem uygulandı.",
    );
  }
  return {resolved: true, resolution};
});

export const registerPrayerPhoto = onCall({
  region: "europe-west1",
}, async (request) => {
  const userId = requireAuth(request.auth?.uid);
  const groupId = requiredString(request.data?.groupId, "groupId");
  const prayer = requiredString(request.data?.prayer, "prayer", 16);
  const dateKey = requiredString(request.data?.dateKey, "dateKey", 10);
  const objectKey = requiredString(request.data?.objectKey, "objectKey", 512);
  const idempotencyKey = requiredString(request.data?.idempotencyKey, "idempotencyKey", 128);
  if (!prayerNames.has(prayer)) {
    throw new HttpsError("invalid-argument", "Namaz geçersiz.");
  }
  await activeMembership(groupId, userId);
  await validateCurrentDateKey(userId, prayer, dateKey);
  const group = await db.doc(`groups/${groupId}`).get();
  if (group.data()?.verificationType !== "photo") {
    throw new HttpsError("failed-precondition", "Bu grup fotoğraf doğrulaması kullanmıyor.");
  }

  const expectedPrefix = `prayer-photos/${groupId}/${dateKey}/${userId}/`;
  if (!objectKey.startsWith(expectedPrefix)) {
    throw new HttpsError("permission-denied", "Fotoğraf yolu geçersiz.");
  }

  const file = getStorage().bucket().file(objectKey);
  try {
    const [metadata] = await file.getMetadata();
    const size = Number(metadata.size ?? 0);
    if (metadata.contentType !== "image/jpeg" || size <= 0 || size >= 5 * 1024 * 1024) {
      throw new Error("invalid_metadata");
    }
    const [bytes] = await file.download();
    const decoded = await sharp(bytes, {limitInputPixels: 20_000_000, failOn: "error"}).metadata();
    if (decoded.format !== "jpeg" || !decoded.width || !decoded.height) throw new Error("invalid_jpeg");
  } catch (_) {
    await file.delete({ignoreNotFound: true});
    throw new HttpsError("invalid-argument", "Yüklenen dosya geçerli bir JPEG fotoğraf değil.");
  }

  const requestRef = db.doc(`idempotency/${userId}_${idempotencyKey}`);
  const now = Timestamp.now();
  const expiresAt = Timestamp.fromMillis(now.toMillis() + photoLifetimeMs);
  const scheduleRef = db.doc(`users/${userId}/prayerDays/${dateKey}`);
  const checkinRef = db.doc(`groups/${groupId}/prayerDays/${dateKey}/checkins/${userId}_${prayer}`);
  const statsRef = db.doc(`groups/${groupId}/dailyStats/${dateKey}`);
  return db.runTransaction(async (transaction) => {
    const [previous, scheduleSnapshot, checkinSnapshot] = await Promise.all([
      transaction.get(requestRef), transaction.get(scheduleRef), transaction.get(checkinRef),
    ]);
    if (previous.exists) return previous.data()?.result;
    const window = scheduleSnapshot.data()?.windows?.[prayer] as {startsAt?: Timestamp; endsAt?: Timestamp} | undefined;
    if (!window?.startsAt || !window.endsAt || now.toMillis() < window.startsAt.toMillis() || now.toMillis() >= window.endsAt.toMillis()) {
      throw new HttpsError("failed-precondition", "Fotoğraf doğrulaması namaz vakti içinde yapılabilir.");
    }

    const photoRef = db.collection("photos").doc();
    const result = {
      photoId: photoRef.id,
      expiresAt: expiresAt.toDate().toISOString(),
    };
    transaction.create(photoRef, {
      userId,
      groupId,
      prayer,
      dateKey,
      objectKey,
      createdAt: now,
      expiresAt,
      status: "visible",
      reportCount: 0,
    });
    const wasCompleted = ["completed", "completed_with_photo"].includes((checkinSnapshot.data()?.status as string | undefined) ?? "");
    transaction.set(checkinRef, {
      userId, prayer, dateKey, prayerStartAt: window.startsAt, prayerEndAt: window.endsAt,
      status: "completed_with_photo", completedAt: now, photoId: photoRef.id, updatedAt: now,
    }, {merge: true});
    if (!wasCompleted) transaction.set(statsRef, {[prayer]: {completedCount: FieldValue.increment(1)}}, {merge: true});
    transaction.create(requestRef, {
      userId,
      operation: "registerPrayerPhoto",
      result,
      createdAt: now,
      expiresAt: Timestamp.fromMillis(now.toMillis() + 86_400_000),
    });
    return result;
  });
});

export const setGroupLogo = onCall({region: "europe-west1"}, async (request) => {
  const userId = requireAuth(request.auth?.uid);
  const groupId = requiredString(request.data?.groupId, "groupId");
  const objectKey = requiredString(request.data?.objectKey, "objectKey", 512);
  const groupRef = db.doc(`groups/${groupId}`);
  const group = await groupRef.get();
  if (!group.exists || group.data()?.ownerId !== userId) {
    throw new HttpsError("permission-denied", "Grup logosunu yalnızca grup sahibi değiştirebilir.");
  }
  if (!objectKey.startsWith(`group-logos/${groupId}/${userId}/`)) {
    throw new HttpsError("permission-denied", "Logo yolu geçersiz.");
  }
  await groupRef.update({
    logoObjectKey: objectKey,
    logoEmoji: null,
    updatedAt: FieldValue.serverTimestamp(),
  });
  return {updated: true};
});

export const syncAccountProfile = onCall({region: "europe-west1"}, async (request) => {
  const userId = requireAuth(request.auth?.uid);
  const user = await getAuth().getUser(userId);
  if (!user.email) throw new HttpsError("failed-precondition", "E-posta hesabı bulunamadı.");
  await db.doc(`users/${userId}`).set({
    email: user.email,
    emailVerified: user.emailVerified,
    accountType: "email",
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  return {email: user.email, emailVerified: user.emailVerified};
});

export const deleteMyAccount = onCall({region: "europe-west1"}, async (request) => {
  const userId = requireAuth(request.auth?.uid);
  const userRef = db.doc(`users/${userId}`);
  const memberships = await userRef.collection("groupMemberships").get();
  const ownedMemberships = memberships.docs.filter((membership) =>
    membership.data().status === "active" && membership.data().role === "owner");
  if (ownedMemberships.length > 0) {
    throw new HttpsError(
      "failed-precondition",
      "Hesabı silmeden önce sahibi olduğunuz grupların sahipliğini devredin.",
      {groupIds: ownedMemberships.map((membership) => membership.id)},
    );
  }
  await Promise.all(memberships.docs.map(async (membership) => {
    const groupId = membership.data().groupId as string | undefined;
    if (!groupId) return;
    const memberRef = db.doc(`groups/${groupId}/members/${userId}`);
    await db.runTransaction(async (transaction) => {
      const member = await transaction.get(memberRef);
      if (member.data()?.status !== "active") return;
      transaction.delete(memberRef);
      transaction.update(db.doc(`groups/${groupId}`), {memberCount: FieldValue.increment(-1), activeMemberCount: FieldValue.increment(-1), updatedAt: FieldValue.serverTimestamp()});
    });
  }));
  const photos = await db.collection("photos").where("userId", "==", userId).get();
  await Promise.all(photos.docs.map(async (photo) => {
    const objectKey = photo.data().objectKey as string | undefined;
    if (objectKey) await getStorage().bucket().file(objectKey).delete({ignoreNotFound: true});
    await photo.ref.update({
      status: "deleted", deletedAt: FieldValue.serverTimestamp(),
      objectKey: FieldValue.delete(), userId: null, ownerDeleted: true,
    });
  }));
  const anonymousId = `deleted_${randomUUID().replaceAll("-", "")}`;
  const checkins = await db.collectionGroup("checkins").where("userId", "==", userId).get();
  for (let index = 0; index < checkins.docs.length; index += 200) {
    const batch = db.batch();
    for (const checkin of checkins.docs.slice(index, index + 200)) {
      const prayer = checkin.data().prayer as string | undefined;
      const replacement = checkin.ref.parent.doc(`${anonymousId}_${prayer ?? "prayer"}`);
      batch.set(replacement, {
        ...checkin.data(),
        userId: null,
        displayName: "Silinmiş kullanıcı",
        anonymized: true,
        anonymizedAt: FieldValue.serverTimestamp(),
      });
      batch.delete(checkin.ref);
    }
    await batch.commit();
  }
  const relatedReports = await db.collection("reports")
    .where("reporterId", "==", userId)
    .get();
  for (let index = 0; index < relatedReports.docs.length; index += 400) {
    const batch = db.batch();
    relatedReports.docs.slice(index, index + 400).forEach((report) => batch.update(report.ref, {
      reporterId: null,
      reporterDeleted: true,
      updatedAt: FieldValue.serverTimestamp(),
    }));
    await batch.commit();
  }
  const targetedReports = await db.collection("reports")
    .where("targetOwnerId", "==", userId)
    .get();
  for (let index = 0; index < targetedReports.docs.length; index += 400) {
    const batch = db.batch();
    targetedReports.docs.slice(index, index + 400).forEach((report) => batch.update(report.ref, {
      targetOwnerId: null,
      targetOwnerDeleted: true,
      updatedAt: FieldValue.serverTimestamp(),
    }));
    await batch.commit();
  }
  await db.recursiveDelete(userRef);
  await getAuth().deleteUser(userId);
  return {deleted: true};
});

export const deleteExpiredPhotos = onSchedule({
  schedule: "every 30 minutes",
  region: "europe-west1",
  retryCount: 3,
}, async () => {
  const expired = await db.collection("photos")
    .where("status", "in", ["visible", "hidden_pending_review"])
    .where("expiresAt", "<=", Timestamp.now())
    .limit(200)
    .get();

  for (const document of expired.docs) {
    const objectKey = document.data().objectKey as string | undefined;
    if (!objectKey) continue;
    await getStorage().bucket().file(objectKey).delete({ignoreNotFound: true});
    await document.ref.update({
      status: "deleted",
      deletedAt: FieldValue.serverTimestamp(),
      objectKey: FieldValue.delete(),
    });
  }
});

export const refreshGroupSearchPrefixes = onSchedule({
  schedule: "every day 03:20",
  timeZone: "Europe/Istanbul",
  region: "europe-west1",
  retryCount: 3,
}, async () => {
  const groups = await db.collection("groups").limit(500).get();
  const writer = db.bulkWriter();
  for (const group of groups.docs) {
    const data = group.data();
    const prefixes = groupSearchPrefixes(data.name, data.city, data.countryCode);
    const existing = Array.isArray(data.searchPrefixes) ? data.searchPrefixes as string[] : [];
    if (JSON.stringify(existing) !== JSON.stringify(prefixes)) {
      writer.update(group.ref, {searchPrefixes: prefixes, searchIndexedAt: FieldValue.serverTimestamp()});
    }
  }
  await writer.close();
});

function dateKeyDaysAgo(daysAgo: number): string {
  const date = new Date();
  date.setUTCHours(12, 0, 0, 0);
  date.setUTCDate(date.getUTCDate() - daysAgo);
  return date.toISOString().slice(0, 10);
}

export const rebuildStatistics = onSchedule({
  schedule: "15 3 * * *",
  timeZone: "Europe/Istanbul",
  region: "europe-west1",
  timeoutSeconds: 540,
  memory: "512MiB",
}, async () => {
  const groups = await db.collection("groups").where("status", "==", "active").get();
  const sevenDayKeys = new Set(Array.from({length: 7}, (_, index) => dateKeyDaysAgo(index)));
  const thirtyDayKeys = Array.from({length: 30}, (_, index) => dateKeyDaysAgo(index));
  const personalKeys = new Map<string, Set<string>>();
  const personalDates = new Map<string, Set<string>>();
  const activeUserIds = new Set<string>();
  const validLeaderboardIds = new Set<string>();
  const writer = db.bulkWriter();

  for (const groupDocument of groups.docs) {
    const group = groupDocument.data();
    const activeMembers = Number(group.activeMemberCount ?? group.memberCount ?? 0);
    const prayers = Array.isArray(group.prayers)
      ? group.prayers.filter((value: unknown): value is string => typeof value === "string" && prayerNames.has(value))
      : [];
    if (activeMembers <= 0 || prayers.length === 0) continue;

    const [dailySnapshots, memberSnapshot] = await Promise.all([
      Promise.all(thirtyDayKeys.map((dateKey) =>
        db.collection(`groups/${groupDocument.id}/prayerDays/${dateKey}/checkins`).get())),
      db.collection(`groups/${groupDocument.id}/members`).where("status", "==", "active").get(),
    ]);
    const completedByDate = new Map<string, number>();
    const memberCounts = new Map<string, {seven: number; thirty: number}>();

    dailySnapshots.forEach((snapshot, index) => {
      const dateKey = thirtyDayKeys[index];
      if (!dateKey) return;
      let completedCount = 0;
      snapshot.docs.forEach((checkin) => {
        const data = checkin.data();
        if (!completedStatuses.has(data.status as string)) return;
        const userId = data.userId as string | undefined;
        const prayer = data.prayer as string | undefined;
        if (!userId || !prayer) return;
        completedCount += 1;
        const counts = memberCounts.get(userId) ?? {seven: 0, thirty: 0};
        counts.thirty += 1;
        if (sevenDayKeys.has(dateKey)) counts.seven += 1;
        memberCounts.set(userId, counts);
        const keys = personalKeys.get(userId) ?? new Set<string>();
        keys.add(`${dateKey}_${prayer}`);
        personalKeys.set(userId, keys);
        const dates = personalDates.get(userId) ?? new Set<string>();
        dates.add(dateKey);
        personalDates.set(userId, dates);
      });
      completedByDate.set(dateKey, completedCount);
    });

    for (const member of memberSnapshot.docs) {
      activeUserIds.add(member.id);
      const counts = memberCounts.get(member.id) ?? {seven: 0, thirty: 0};
      writer.update(member.ref, {
        personalGroupStats: {
          sevenDayCompleted: counts.seven,
          thirtyDayCompleted: counts.thirty,
          calculatedAt: FieldValue.serverTimestamp(),
        },
      });
    }

    const scoreFor = (days: number): number => {
      const keys = thirtyDayKeys.slice(0, days);
      const completed = keys.reduce((sum, key) => sum + (completedByDate.get(key) ?? 0), 0);
      return completed / (activeMembers * prayers.length * days);
    };
    const sevenDayScore = Math.min(1, scoreFor(7));
    const thirtyDayScore = Math.min(1, scoreFor(30));
    let currentStreak = 0;
    for (const dateKey of thirtyDayKeys) {
      const dailyRate = (completedByDate.get(dateKey) ?? 0) / (activeMembers * prayers.length);
      if (dailyRate < 0.5) break;
      currentStreak += 1;
    }
    writer.update(groupDocument.ref, {
      participationRate: sevenDayScore,
      currentStreak,
      statsUpdatedAt: FieldValue.serverTimestamp(),
    });

    const createdAt = group.createdAt as Timestamp | undefined;
    const hasSevenDays = createdAt && Date.now() - createdAt.toMillis() >= 7 * 86_400_000;
    if (activeMembers >= 5 && hasSevenDays) {
      for (const [periodDays, score] of [[7, sevenDayScore], [30, thirtyDayScore]] as const) {
        const entryId = `${periodDays}_${groupDocument.id}`;
        validLeaderboardIds.add(entryId);
        writer.set(db.doc(`leaderboards/${entryId}`), {
          groupId: groupDocument.id,
          groupName: group.name ?? "Grup",
          periodDays,
          score,
          activeMemberCount: activeMembers,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }
  }

  for (const userId of activeUserIds) {
    const keys = personalKeys.get(userId) ?? new Set<string>();
    const dates = personalDates.get(userId) ?? new Set<string>();
    const sevenCompleted = [...keys].filter((key) => sevenDayKeys.has(key.slice(0, 10))).length;
    let currentStreak = 0;
    for (const dateKey of thirtyDayKeys) {
      if (!dates.has(dateKey)) break;
      currentStreak += 1;
    }
    writer.update(db.doc(`users/${userId}`), {
      stats: {
        sevenDayCompleted: sevenCompleted,
        thirtyDayCompleted: keys.size,
        currentStreak,
        calculatedAt: FieldValue.serverTimestamp(),
      },
    });
  }

  const existingEntries = await db.collection("leaderboards").get();
  existingEntries.docs
    .filter((entry) => !validLeaderboardIds.has(entry.id))
    .forEach((entry) => writer.delete(entry.ref));
  await writer.close();
});
