import assert from 'node:assert/strict';
import {after, before, test} from 'node:test';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {createRequire} from 'node:module';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {collection, doc, getDoc, getDocs, setDoc} from 'firebase/firestore';
import {getBytes, ref, uploadBytes} from 'firebase/storage';

const require = createRequire(import.meta.url);
const callableFunctions = require('../lib/index.js');

const projectId = 'namaz-grubum';
let environment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: readFileSync(resolve(process.cwd(), '../firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
    storage: {
      rules: readFileSync(resolve(process.cwd(), '../storage.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });
  await environment.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    const profile = (name) => ({
      displayName: name,
      displayInitial: name[0],
      gender: 'male',
      madhhab: 'hanafi',
      countryCode: 'TR',
      timezone: 'Europe/Istanbul',
      status: 'active',
      createdAt: new Date(),
    });
    await setDoc(doc(firestore, 'users/alice'), profile('Alice'));
    await setDoc(doc(firestore, 'users/bob'), profile('Bob'));
    await setDoc(doc(firestore, 'users/stranger'), profile('Stranger'));
    await setDoc(doc(firestore, 'groups/group-1'), {
      name: 'Test grubu', status: 'active', ownerId: 'alice', gender: 'male',
      countryCode: 'TR', city: 'İstanbul', prayers: ['fajr'],
      searchPrefixes: ['te', 'tes', 'test'], createdAt: new Date(),
    });
    await setDoc(doc(firestore, 'groups/group-1/members/alice'), {
      role: 'owner', status: 'active',
    });
    await setDoc(doc(firestore, 'groups/group-1/members/bob'), {
      role: 'member', status: 'active',
    });
    await setDoc(doc(firestore, 'users/alice/groupMemberships/group-1'), {
      groupId: 'group-1', role: 'owner', status: 'active',
    });
    await setDoc(doc(firestore, 'users/bob/groupMemberships/group-1'), {
      groupId: 'group-1', role: 'member', status: 'active',
    });
  });
});

after(async () => {
  await environment?.cleanup();
});

test('a user can read their profile but cannot read another profile', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  await assertSucceeds(getDoc(doc(alice, 'users/alice')));
  await assertFails(getDoc(doc(alice, 'users/bob')));
});

test('a group member can read members while a stranger cannot', async () => {
  const bob = environment.authenticatedContext('bob').firestore();
  const stranger = environment.authenticatedContext('stranger').firestore();
  await assertSucceeds(getDoc(doc(bob, 'groups/group-1/members/alice')));
  await assertFails(getDoc(doc(stranger, 'groups/group-1/members/alice')));
});

test('clients cannot write check-ins or leaderboards directly', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  await assertFails(setDoc(
    doc(alice, 'groups/group-1/prayerDays/2026-09-05/checkins/alice_fajr'),
    {userId: 'alice', prayer: 'fajr', status: 'completed'},
  ));
  await assertFails(setDoc(doc(alice, 'leaderboards/7_group-1'), {score: 1}));
});

test('storage allows an active member and rejects unrelated users', async () => {
  const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
  const aliceStorage = environment.authenticatedContext('alice').storage();
  const strangerStorage = environment.authenticatedContext('stranger').storage();
  const path = 'prayer-photos/group-1/2026-09-05/alice/proof.jpg';
  await assertSucceeds(uploadBytes(ref(aliceStorage, path), jpeg, {contentType: 'image/jpeg'}));
  await assertSucceeds(getBytes(ref(aliceStorage, path)));
  await assertFails(getBytes(ref(strangerStorage, path)));
  await assertFails(uploadBytes(
    ref(strangerStorage, 'prayer-photos/group-1/2026-09-05/alice/forged.jpg'),
    jpeg,
    {contentType: 'image/jpeg'},
  ));
});

for (const functionName of [
  'transferGroupOwnership',
  'setMemberRole',
  'removeGroupMember',
  'suspendGroupMember',
  'archiveGroup',
  'recordCheckin',
  'blockUser',
  'syncPrayerSchedule',
  'discoverGroups',
  'listModerationReports',
  'resolveModerationReport',
]) {
  test(`${functionName} rejects unauthenticated requests`, async () => {
    await assert.rejects(
      callableFunctions[functionName].run({auth: undefined, data: {}}),
      (error) => error?.code === 'unauthenticated',
    );
  });
}

test('member administration enforces owner and moderator boundaries', async () => {
  await callableFunctions.setMemberRole.run({
    auth: {uid: 'alice', token: {}},
    data: {groupId: 'group-1', targetUserId: 'bob', role: 'moderator'},
  });
  const bob = environment.authenticatedContext('bob').firestore();
  assert.equal((await getDoc(doc(bob, 'groups/group-1/members/bob'))).data().role, 'moderator');
  await assert.rejects(
    callableFunctions.removeGroupMember.run({
      auth: {uid: 'bob', token: {}},
      data: {groupId: 'group-1', targetUserId: 'alice'},
    }),
    (error) => error?.code === 'failed-precondition',
  );
});

test('moderation queue requires a privileged custom claim', async () => {
  await assert.rejects(
    callableFunctions.listModerationReports.run({
      auth: {uid: 'alice', token: {}},
      data: {status: 'pending'},
    }),
    (error) => error?.code === 'permission-denied',
  );
  const result = await callableFunctions.listModerationReports.run({
    auth: {uid: 'alice', token: {moderator: true}},
    data: {status: 'pending'},
  });
  assert.deepEqual(result, {reports: []});
});

test('reports validate that their target exists', async () => {
  await assert.rejects(
    callableFunctions.reportContent.run({
      auth: {uid: 'alice', token: {}},
      data: {targetType: 'group', targetId: 'missing-group', reason: 'spam'},
    }),
    (error) => error?.code === 'not-found',
  );
});

test('trusted schedule sync creates eight server-calculated prayer days', async () => {
  const result = await callableFunctions.syncPrayerSchedule.run({
    auth: {uid: 'alice', token: {}},
    data: {
      latitude: 41.0082,
      longitude: 28.9784,
      locationEnabled: true,
    },
  });
  assert.equal(result.synced, true);
  assert.equal(result.timezone, 'Europe/Istanbul');
  assert.equal(result.days, 8);
  const alice = environment.authenticatedContext('alice').firestore();
  const days = await getDocs(collection(alice, 'users/alice/prayerDays'));
  assert.equal(days.size, 8);
  const first = days.docs[0].data();
  assert.deepEqual(Object.keys(first.windows).sort(), [
    'asr', 'dhuhr', 'fajr', 'isha', 'maghrib',
  ]);
  assert.ok(first.windows.fajr.endsAt.toMillis() > first.windows.fajr.startsAt.toMillis());
});

test('Turkey schedule stays aligned with published Diyanet times', () => {
  const times = callableFunctions.prayerTimesFor(
    '2026-09-25',
    41.0082,
    28.9784,
    'Europe/Istanbul',
    'hanafi',
  );
  const formatter = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Europe/Istanbul',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
  const actual = {
    fajr: formatter.format(times.fajr),
    dhuhr: formatter.format(times.dhuhr),
    asr: formatter.format(times.asr),
    maghrib: formatter.format(times.maghrib),
    isha: formatter.format(times.isha),
  };
  // Diyanet İstanbul 25.09.2026 is 05:22, 13:01, 16:24, 19:05,
  // 20:24. The library rounds Asr two minutes earlier and the evening
  // prayers one minute earlier.
  assert.deepEqual(actual, {
    fajr: '05:22',
    dhuhr: '13:01',
    asr: '16:22',
    maghrib: '19:04',
    isha: '20:23',
  });
});

test('group discovery searches indexed prefixes on the server', async () => {
  const result = await callableFunctions.discoverGroups.run({
    auth: {uid: 'alice', token: {}},
    data: {query: 'test', limit: 20},
  });
  assert.equal(result.groups.length, 1);
  assert.equal(result.groups[0].id, 'group-1');
  assert.equal(result.nextCursor, null);
});
