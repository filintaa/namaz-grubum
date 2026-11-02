# TestFlight geri bildirim incelemesi — 10 Eylül 2026

Kaynak: App Store Connect, TestFlight Screenshot Feedback, `1.0.0 (3)`.

## Genel durum

- Crash Feedback: kayıt yok.
- Screenshot Feedback: 9 kayıt.
- Cihazlar: iPhone SE (2. nesil) ve iPhone 14 Pro Max, iOS 26.6.1.
- Kullanıcının talebi gereği bu çalışma sonunda yeni build alınmadı ve yükleme yapılmadı.

## Düzeltilen geri bildirimler

1. **“İsim kısmı bozuk düzelt”**
   - Grup adı ile yönetici rozeti aynı dar satırda birbirini eziyordu.
   - Başlık iki satırlı, ellipsis korumalı hale getirildi; rol rozeti ayrı satıra taşındı.

2. **“Açılışta yavaş yükleniyor”**
   - Oturum yönlendirmesi namaz senkronizasyonu, alarm, push ve offline kuyruk işlemlerini bekliyordu.
   - Oturum durumu belirlendikten hemen sonra arayüz açılıyor; ağ tabanlı servisler arka planda hazırlanıyor.
   - İlk davet-linki okuması da ilk ekranı bloke etmeyecek şekilde arka plana taşındı.

3. **“Her açılışta bu ekran geliyor”**
   - Onboarding tamamlanma kaydı, konum/bildirim/alarm izinlerinden sonra yazılıyordu.
   - Tamamlanma artık profil kaydından hemen sonra, yavaş veya kesintiye uğrayabilen izin işlemlerinden önce saklanıyor.

4. **“Katılım isteği gönderdim fakat böyle gözüküyor”**
   - Onay bekleyen isteğin butonu yeniden “Katılım isteği gönder” durumuna dönüyordu.
   - Buton artık “Katılım isteği gönderildi” metniyle pasif kalıyor.

5. **“Bu popup da tasarıma uygun olsun”**
   - Grup aksiyonlarındaki varsayılan iOS uyarı popup'ı kaldırıldı.
   - Marka renkleri ve yuvarlak köşeli, alt navigasyonun üzerinde duran 3 saniyelik bildirim kullanılıyor.

6. **“Kendi grubumu şikayet et var”**
   - Grup sahibi ve yöneticiler için grup şikâyet menüsü gizlendi.
   - Başka üyeleri şikâyet/engelleme davranışı değişmedi.

7. **“Kalktım butonuna basınca mesaj tepki kısa oluyor”**
   - Başarılı işlem sonrası açık metinli geri bildirim eklendi: “Kalktın olarak işaretlendi.”
   - Görünme süresi 3 saniye olarak sabitlendi.

8. **“Katıl diyince” / `Katılınıyor…` durumunda kalma**
   - Katılma isteğine 15 saniyelik timeout eklendi.
   - Başarı, onay bekleme ve hata durumlarının her biri butonu belirli bir son duruma getiriyor.

## İncelenen ancak kod hatası doğrulanmayan kayıt

### “WhatsApp'tan namaz daveti gelince Page Not Found”

- Güncel paylaşım adresi `https://namaz-grubum.web.app/g/<groupId>` biçiminde.
- Firebase Hosting yönlendirmesi `/g/** -> /invite.html` mevcut.
- Canlı URL 10 Eylül 2026 kontrolünde HTTP 200 döndürdü.
- iOS URL scheme (`namazgrubum`) ve associated domains tanımları mevcut.
- Kayıttaki 404 güncel ortamda yeniden üretilemedi. Bir sonraki tester sürümünde aynı davet linkinin WhatsApp iç tarayıcısı ve Safari üzerinden tekrar denenmesi gerekiyor. Tekrar oluşursa geri bildirim paketindeki tam URL ile hosting logu eşleştirilmeli.

## Doğrulama

- `flutter analyze`: temiz.
- `flutter test`: 12/12 geçti.
- Yeni IPA/archive/build oluşturulmadı.
