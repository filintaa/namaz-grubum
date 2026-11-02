# TestFlight geri bildirim incelemesi — 1 Ekim 2026

Kaynak: App Store Connect, TestFlight Screenshot Feedback. İnceleme sırasında toplam 16 ekran görüntülü geri bildirim ve 0 crash geri bildirimi vardı.

## Yeni kayıt

- `1.0.0 (8)`, 1 Ekim 2026: “Splashscreen'deki logoyu değiştirmeyi unutmuşsun.”
- Eski yeşil/cami launch görseli, güncel sarılan iki kişi marka işaretiyle değiştirildi.
- Logonun kare arka planı kaldırıldı; launch ekranı uygulamanın `warmWhite` rengiyle eşleştirildi.
- iOS asset adı `LaunchLogo` olarak yenilendi. Böylece eski launch varlığının işletim sistemi önbelleğinden tekrar gösterilme riski azaltıldı.
- Şeffaf 1x/2x/3x varlıklar `assets/branding/launch_logo_master.png` kaynağından üretilebilir hale getirildi.

## 10 Eylül raporundan sonra gelen diğer kayıtların denetimi

1. **“Kıldım dedikten sonra eğer foto onayı istiyorsa direkt foto ekranı gelsin”**
   - Mevcut akış ve widget testi bunu doğruluyor: fotoğraflı grupta `Kıldım` doğrudan kamera ekranını açıyor ve buton check-in çağrısı yapmıyor.

2. **“Katılma isteği gönderilince grup sahibine bildirimi gitsin”**
   - Eksik olduğu doğrulandı ve tamamlandı.
   - Yeni bekleyen istekte grubun aktif sahip ve yöneticilerine push bildirimi gönderiliyor.
   - Aynı idempotent isteğin yeniden denenmesi ikinci bir bildirim üretmiyor.

3. **“İlk açılışta çok yavaş açılıyor”**
   - Mevcut oturum akışı yönlendirme kararından sonra ağ tabanlı servisleri arka planda hazırlıyor; ilk ekran bu servisleri beklemiyor.

4. **“Biten namazlar pasif gözüksün. Vakti girmeyen namazlarda onaylanmasın”**
   - Sunucu sınırı zaten vardı; arayüz davranışı eksikti ve tamamlandı.
   - Gelecek vakitte `Kalktım`/`Kıldım` gösterilmiyor, “Vakit henüz girmedi” pasif durumu gösteriliyor.
   - Biten vakit gri/pasif gösteriliyor ve yalnızca kaza tamamlama sunuluyor.
   - Vakit verisi henüz yoksa normal onay düğmeleri kapalı kalıyor.

5. **“Sabah namazını kalktım dedim fakat gözüküyor yine”**
   - Mevcut iyimser durum güncellemesi ve Firestore check-in okuması `Kalktım` sonrası durumu `Kalktı` olarak koruyor.

6. **“Katılma isteği gönderdim ama yine böyle gözüküyor”**
   - Önceki çözüm yalnızca açık ekranın yerel durumunu koruyordu; yeniden açılışta kayboluyordu.
   - Grup ekranı artık kullanıcının Firestore'daki bekleyen isteğini okuyor ve yeniden açıldığında da pasif “Katılım isteği gönderildi” durumunu gösteriyor.

## Doğrulama

- `flutter analyze`: temiz.
- `flutter test`: 31/31 geçti.
- `functions/npm run build`: TypeScript derlemesi başarılı.
- Launch assetleri: 168/336/504 px, gerçek alfa kanallı PNG.
- Storyboard XML, asset JSON, Python üretim aracı sözdizimi: geçerli.

## Yayınlama notu

- Güncellenen `joinGroup` fonksiyonu 2 Ekim 2026 tarihinde `europe-west1` bölgesine başarıyla deploy edildi.
- `1.0.0 (9)` release archive ve IPA oluşturuldu; Apple doğrulaması hatasız geçti.
- Build 9, TestFlight'a başarıyla yüklendi. Delivery UUID: `5a1f2985-1d4b-476b-b670-152585662bfa`.
- Apple işleme durumu `VALID`; build, bütün build'lere erişimi olan dahili `Test` grubunda görünür durumda.
