import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';

import {
  applicationDefault,
  initializeApp as initializeAdminApp,
} from 'firebase-admin/app';
import {getAuth as getAdminAuth} from 'firebase-admin/auth';
import {
  Timestamp,
  getFirestore as getAdminFirestore,
} from 'firebase-admin/firestore';
import {getStorage as getAdminStorage} from 'firebase-admin/storage';
import {initializeApp as initializeClientApp} from 'firebase/app';
import {
  deleteApp as deleteClientApp,
  getApps as getClientApps,
} from 'firebase/app';
import {
  getAuth as getClientAuth,
  signInWithEmailAndPassword,
} from 'firebase/auth';
import {
  collection,
  getDocs,
  getFirestore as getClientFirestore,
  query,
  where,
} from 'firebase/firestore';
import {getFunctions, httpsCallable} from 'firebase/functions';
import {
  getBytes,
  getStorage as getClientStorage,
  ref,
  uploadBytes,
} from 'firebase/storage';
import sharp from 'sharp';

const projectId = 'namaz-grubum';
const storageBucket = 'namaz-grubum.firebasestorage.app';
const runId = randomUUID();
const shortId = runId.slice(0, 8);
const email = `photo-e2e-${runId}@example.test`;
const password = `E2e-${randomUUID()}-Aa1!`;
const groupId = `photo-e2e-${runId}`;
const idempotencyKey = `photo-e2e-${runId}`;
const dateKey = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Europe/Istanbul',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
}).format(new Date());

initializeAdminApp({
  credential: applicationDefault(),
  projectId,
  storageBucket,
});
const adminAuth = getAdminAuth();
const adminDb = getAdminFirestore();
const bucket = getAdminStorage().bucket();

let uid;
let objectKey;
let photoId;
let clientApp;

function checkpoint(name, details = '') {
  const suffix = details ? ` — ${details}` : '';
  console.log(`PASS ${name}${suffix}`);
}

try {
  const user = await adminAuth.createUser({
    email,
    password,
    emailVerified: true,
    displayName: `Photo E2E ${shortId}`,
  });
  uid = user.uid;
  checkpoint('authenticated test user created', uid);

  const now = Timestamp.now();
  const startsAt = Timestamp.fromMillis(now.toMillis() - 5 * 60 * 1000);
  const endsAt = Timestamp.fromMillis(now.toMillis() + 30 * 60 * 1000);
  const batch = adminDb.batch();
  batch.set(adminDb.doc(`users/${uid}`), {
    displayName: `Photo E2E ${shortId}`,
    displayInitial: 'P',
    gender: 'male',
    madhhab: 'hanafi',
    countryCode: 'TR',
    city: 'İstanbul',
    timezone: 'Europe/Istanbul',
    status: 'active',
    activeGroupCount: 1,
    onboardingCompleted: true,
    createdAt: now,
    updatedAt: now,
  });
  batch.set(adminDb.doc(`groups/${groupId}`), {
    name: `Canlı Fotoğraf Testi ${shortId}`,
    ownerId: uid,
    moderatorIds: [],
    gender: 'male',
    countryCode: 'TR',
    city: 'İstanbul',
    prayers: ['dhuhr'],
    verificationType: 'photo',
    joinApprovalRequired: false,
    memberCount: 1,
    activeMemberCount: 1,
    capacity: 50,
    status: 'active',
    createdAt: now,
  });
  batch.set(adminDb.doc(`groups/${groupId}/members/${uid}`), {
    role: 'owner',
    status: 'active',
    joinedAt: now,
    displayName: `Photo E2E ${shortId}`,
    city: 'İstanbul',
    countryCode: 'TR',
  });
  batch.set(adminDb.doc(`users/${uid}/groupMemberships/${groupId}`), {
    groupId,
    role: 'owner',
    status: 'active',
    joinedAt: now,
  });
  batch.set(adminDb.doc(`users/${uid}/prayerDays/${dateKey}`), {
    dateKey,
    timezone: 'Europe/Istanbul',
    windows: {dhuhr: {startsAt, endsAt}},
    createdAt: now,
  });
  await batch.commit();
  checkpoint('active photo group and active prayer window seeded', dateKey);

  clientApp = initializeClientApp(
    {
      apiKey: 'AIzaSyArTNQL0zROGfe4fz2ocC2US6my3PCePP0',
      appId: '1:146883312066:android:29be71f531227d4b54be5b',
      authDomain: `${projectId}.firebaseapp.com`,
      projectId,
      storageBucket,
    },
    `photo-e2e-${runId}`,
  );
  const credential = await signInWithEmailAndPassword(
    getClientAuth(clientApp),
    email,
    password,
  );
  assert.equal(credential.user.uid, uid);
  checkpoint('client signed in through production Firebase Auth');

  const source = await readFile(
    resolve(process.cwd(), '../artifacts/ios-17-home.png'),
  );
  const jpeg = await sharp(source)
    .rotate()
    .resize({width: 1200, height: 1200, fit: 'inside'})
    .jpeg({quality: 84})
    .toBuffer();
  objectKey = `prayer-photos/${groupId}/${dateKey}/${uid}/${runId}.jpg`;
  await uploadBytes(ref(getClientStorage(clientApp), objectKey), jpeg, {
    contentType: 'image/jpeg',
    customMetadata: {source: 'camera-e2e'},
  });
  checkpoint('JPEG uploaded through production Storage rules', `${jpeg.length} bytes`);

  const callable = httpsCallable(
    getFunctions(clientApp, 'europe-west1'),
    'registerPrayerPhoto',
  );
  const response = await callable({
    groupId,
    prayer: 'dhuhr',
    dateKey,
    objectKey,
    idempotencyKey,
  });
  photoId = response.data.photoId;
  assert.ok(photoId);
  checkpoint('registerPrayerPhoto completed', photoId);

  const [photo, checkin] = await Promise.all([
    adminDb.doc(`photos/${photoId}`).get(),
    adminDb.doc(`groups/${groupId}/prayerDays/${dateKey}/checkins/${uid}_dhuhr`).get(),
  ]);
  assert.equal(photo.data()?.objectKey, objectKey);
  assert.equal(photo.data()?.status, 'visible');
  assert.equal(checkin.data()?.status, 'completed_with_photo');
  assert.equal(checkin.data()?.photoId, photoId);
  checkpoint('Firestore photo document verified');
  checkpoint('Firestore completed_with_photo check-in verified');

  const photoQuery = query(
    collection(getClientFirestore(clientApp), 'photos'),
    where('groupId', '==', groupId),
    where('dateKey', '==', dateKey),
    where('prayer', '==', 'dhuhr'),
    where('status', '==', 'visible'),
  );
  const visiblePhotos = await getDocs(photoQuery);
  assert.equal(visiblePhotos.size, 1);
  assert.equal(visiblePhotos.docs[0].id, photoId);
  const downloaded = await getBytes(
    ref(getClientStorage(clientApp), objectKey),
    5 * 1024 * 1024,
  );
  assert.ok(downloaded.byteLength > 0);
  checkpoint('group member photo query returned the new photo');
  checkpoint('group member downloaded the visible photo', `${downloaded.byteLength} bytes`);
  console.log('RESULT LIVE_PHOTO_E2E_OK');
} finally {
  if (clientApp && getClientApps().includes(clientApp)) {
    await deleteClientApp(clientApp).catch(() => {});
  }
  if (objectKey) {
    await bucket.file(objectKey).delete({ignoreNotFound: true}).catch(() => {});
  }
  if (photoId) {
    await adminDb.doc(`photos/${photoId}`).delete().catch(() => {});
  }
  if (uid) {
    await adminDb.doc(`idempotency/${uid}_${idempotencyKey}`).delete().catch(() => {});
    await adminDb.recursiveDelete(adminDb.doc(`groups/${groupId}`)).catch(() => {});
    await adminDb.recursiveDelete(adminDb.doc(`users/${uid}`)).catch(() => {});
    await adminAuth.deleteUser(uid).catch(() => {});
  }
  checkpoint('temporary live test data cleaned');
}
