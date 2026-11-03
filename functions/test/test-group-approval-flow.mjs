import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { createGroup, joinGroup, resolveJoinRequest } = require('../lib/index.js');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

const db = getFirestore();

const timestamp = Date.now();
const ownerId = `test_owner_${timestamp}`;
const member1Id = `test_member1_${timestamp}`;
const member2Id = `test_member2_${timestamp}`;
const strangerId = `test_stranger_${timestamp}`;

let createdGroupId = null;

async function setupTestUsers() {
  console.log('1. Test kullanıcıları oluşturuluyor...');
  const createProfile = (name) => ({
    displayName: name,
    displayInitial: name[0],
    gender: 'male',
    madhhab: 'hanafi',
    countryCode: 'TR',
    city: 'İstanbul',
    timezone: 'Europe/Istanbul',
    status: 'active',
    activeGroupCount: 0,
    createdAt: Timestamp.now(),
  });

  await Promise.all([
    db.doc(`users/${ownerId}`).set(createProfile('Test Kurucu')),
    db.doc(`users/${member1Id}`).set(createProfile('Test Üye 1 (Ahmet)')),
    db.doc(`users/${member2Id}`).set(createProfile('Test Üye 2 (Mehmet)')),
    db.doc(`users/${strangerId}`).set(createProfile('Test Yabancı')),
  ]);
  console.log('   ✓ 4 test kullanıcısı hazırlandı.');
}

async function testCreateGroup() {
  console.log('2. Grup oluşturma testi (joinApprovalRequired: true)...');
  const result = await createGroup.run({
    auth: { uid: ownerId },
    data: {
      name: `Test Namaz Grubu ${timestamp}`,
      countryCode: 'TR',
      city: 'İstanbul',
      prayers: ['fajr', 'asr'],
      verificationType: 'button',
      joinApprovalRequired: true,
      logoEmoji: '🕌',
      idempotencyKey: `create_${timestamp}`,
    },
  });

  assert.ok(result?.groupId, 'Grup ID dönmedi.');
  createdGroupId = result.groupId;
  console.log(`   ✓ Grup başarıyla oluşturuldu! GroupId: ${createdGroupId}`);

  // Doğrulama
  const groupDoc = await db.doc(`groups/${createdGroupId}`).get();
  assert.ok(groupDoc.exists, 'Grup Firestore belgesi bulunamadı.');
  const groupData = groupDoc.data();
  assert.equal(groupData.ownerId, ownerId, 'Owner ID uyuşmuyor.');
  assert.equal(groupData.memberCount, 1, 'Üye sayısı 1 olmalı.');
  assert.equal(groupData.activeMemberCount, 1, 'Aktif üye sayısı 1 olmalı.');
  assert.equal(groupData.joinApprovalRequired, true, 'Onay zorunlu olmalı.');
  assert.equal(groupData.status, 'active', 'Grup durumu active olmalı.');

  const ownerMember = await db.doc(`groups/${createdGroupId}/members/${ownerId}`).get();
  assert.ok(ownerMember.exists, 'Kurucu üye belgesi bulunamadı.');
  assert.equal(ownerMember.data().role, 'owner', 'Kurucu rolü owner olmalı.');
  assert.equal(ownerMember.data().status, 'active', 'Kurucu durumu active olmalı.');

  const ownerMembership = await db.doc(`users/${ownerId}/groupMemberships/${createdGroupId}`).get();
  assert.ok(ownerMembership.exists, 'Kurucu groupMemberships belgesi bulunamadı.');

  const ownerUser = await db.doc(`users/${ownerId}`).get();
  assert.equal(ownerUser.data().activeGroupCount, 1, 'Kurucunun aktif grup sayısı 1 olmalı.');

  console.log('   ✓ Grup belgesi, kurucu rolü ve üyelik sayaçları doğrulandı.');
}

async function testJoinRequests() {
  console.log('3. İki farklı kullanıcıdan katılım istekleri gönderiliyor...');

  // Üye 1 katılım isteği
  const result1 = await joinGroup.run({
    auth: { uid: member1Id },
    data: {
      groupId: createdGroupId,
      idempotencyKey: `join_1_${timestamp}`,
    },
  });
  assert.equal(result1.approved, false, 'Onay gerektiren grupta direkt onaylanmamalı.');
  assert.equal(result1.pending, true, 'İstek pending olmalı.');

  // Üye 2 katılım isteği
  const result2 = await joinGroup.run({
    auth: { uid: member2Id },
    data: {
      groupId: createdGroupId,
      idempotencyKey: `join_2_${timestamp}`,
    },
  });
  assert.equal(result2.approved, false, 'Onay gerektiren grupta direkt onaylanmamalı.');
  assert.equal(result2.pending, true, 'İstek pending olmalı.');

  // Firestore istek kontrolü
  const req1 = await db.doc(`groups/${createdGroupId}/joinRequests/${member1Id}`).get();
  assert.ok(req1.exists, 'Üye 1 istek belgesi oluşmadı.');
  assert.equal(req1.data().status, 'pending');

  const req2 = await db.doc(`groups/${createdGroupId}/joinRequests/${member2Id}`).get();
  assert.ok(req2.exists, 'Üye 2 istek belgesi oluşmadı.');
  assert.equal(req2.data().status, 'pending');

  // Henüz üye olmamalılar
  const groupDoc = await db.doc(`groups/${createdGroupId}`).get();
  assert.equal(groupDoc.data().memberCount, 1, 'Onay öncesi üye sayısı değişmemeli.');

  console.log('   ✓ 2 kullanıcının katılım isteği "pending" olarak kuyruğa alındı.');
}

async function testUnauthorizedApprovalFails() {
  console.log('4. Yetkisiz kullanıcının isteği onaylama denemesi test ediliyor...');
  let failed = false;
  try {
    await resolveJoinRequest.run({
      auth: { uid: strangerId },
      data: {
        groupId: createdGroupId,
        targetUserId: member1Id,
        approve: true,
      },
    });
  } catch (err) {
    failed = true;
    assert.equal(err.code, 'permission-denied', 'Hata kodu permission-denied olmalı.');
  }
  assert.ok(failed, 'Yetkisiz kullanıcı onay verememeliydi.');
  console.log('   ✓ Yetkisiz kullanıcı isteği onaylayamadı (güvenlik doğrulandı).');
}

async function testOwnerApprovesMembers() {
  console.log('5. Grup kurucusu gelen katılım isteklerini onaylıyor...');

  // Üye 1 onayı
  const approval1 = await resolveJoinRequest.run({
    auth: { uid: ownerId },
    data: {
      groupId: createdGroupId,
      targetUserId: member1Id,
      approve: true,
    },
  });
  assert.equal(approval1.approved, true, 'Üye 1 onaylanamadı.');

  // Üye 2 onayı
  const approval2 = await resolveJoinRequest.run({
    auth: { uid: ownerId },
    data: {
      groupId: createdGroupId,
      targetUserId: member2Id,
      approve: true,
    },
  });
  assert.equal(approval2.approved, true, 'Üye 2 onaylanamadı.');

  console.log('   ✓ Kurucu iki üyeyi de başarıyla onayladı.');

  // Firestore nihai durum kontrolleri
  console.log('6. Nihai veritabanı durumları doğrulanıyor...');
  const finalGroup = await db.doc(`groups/${createdGroupId}`).get();
  assert.equal(finalGroup.data().memberCount, 3, 'Grup üye sayısı 3 olmalı.');
  assert.equal(finalGroup.data().activeMemberCount, 3, 'Grup aktif üye sayısı 3 olmalı.');

  const m1 = await db.doc(`groups/${createdGroupId}/members/${member1Id}`).get();
  assert.ok(m1.exists);
  assert.equal(m1.data().role, 'member');
  assert.equal(m1.data().status, 'active');

  const m2 = await db.doc(`groups/${createdGroupId}/members/${member2Id}`).get();
  assert.ok(m2.exists);
  assert.equal(m2.data().role, 'member');
  assert.equal(m2.data().status, 'active');

  const memDoc1 = await db.doc(`users/${member1Id}/groupMemberships/${createdGroupId}`).get();
  assert.ok(memDoc1.exists);
  assert.equal(memDoc1.data().status, 'active');

  const userDoc1 = await db.doc(`users/${member1Id}`).get();
  assert.equal(userDoc1.data().activeGroupCount, 1);

  const reqDoc1 = await db.doc(`groups/${createdGroupId}/joinRequests/${member1Id}`).get();
  assert.equal(reqDoc1.data().status, 'approved');

  console.log('   ✓ Grup üye sayısı: 3/3');
  console.log('   ✓ Üyelerin rolleri ve dökümanları: active/member');
  console.log('   ✓ Katılım istekleri durumu: approved');
}

async function cleanup() {
  console.log('7. Test verileri temizleniyor...');
  if (createdGroupId) {
    const members = await db.collection(`groups/${createdGroupId}/members`).get();
    for (const d of members.docs) await d.ref.delete();

    const joinRequests = await db.collection(`groups/${createdGroupId}/joinRequests`).get();
    for (const d of joinRequests.docs) await d.ref.delete();

    await db.doc(`groups/${createdGroupId}`).delete();
  }

  for (const uid of [ownerId, member1Id, member2Id, strangerId]) {
    const mems = await db.collection(`users/${uid}/groupMemberships`).get();
    for (const d of mems.docs) await d.ref.delete();
    await db.doc(`users/${uid}`).delete();
    await db.doc(`rateLimits/${uid}_join_group`).delete().catch(() => {});
  }
  console.log('   ✓ Tüm test dökümanları temizlendi, canlı ortam temiz bırakıldı.');
}

async function main() {
  console.log('====================================================');
  console.log('GRUP KURMA, KATILMA VE ONAY MEKANİZMASI E2E TESTİ');
  console.log('====================================================\n');
  try {
    await setupTestUsers();
    await testCreateGroup();
    await testJoinRequests();
    await testUnauthorizedApprovalFails();
    await testOwnerApprovesMembers();
    console.log('\n>>> SONUÇ: TÜM TESTLER BAŞARIYLA GEÇTİ! <<<');
  } finally {
    await cleanup();
  }
}

main().catch((err) => {
  console.error('\n❌ TEST BAŞARISIZ:', err);
  process.exit(1);
});
