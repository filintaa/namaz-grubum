# Yayın kabul ve cihaz test raporu — 6 Kasım 2026

> **7 Kasım 2026 güncellemesi — bu bölüm aşağıdaki önceki durum notlarının yerine geçer.**
>
> - Yayın sürümü `1.0.1 (13)` olarak üretildi.
> - Flutter analizinde 0 bulgu var; Flutter testleri **37/37**, Firebase güvenlik testleri **21/21** geçti; Functions `npm audit` sonucu **0 açık**.
> - Onboarding daha kısa, açık ve erişilebilir üç adıma dönüştürüldü; geri gezinme, 1/3 ilerleme göstergesi, inline ad/şehir doğrulaması ve daha sade izin anlatımı eklendi.
> - iPhone SE büyük yazı ve iPad yerleşim regresyon testleri geçti.
> - Üretimde Namaz Grubum içerikleri temizlendi: kullanıcı profili **0**, grup ve alt kayıtları **0**, hız-sınırı kaydı **0**, yönetici hatırlatması **0**, kullanıcı fotoğrafı **0**. Ortak Firebase projesindeki 19 anonim Authentication kimliği diğer uygulamayı etkilememek için korundu; sunucu profili bulunmadığında yerel onboarding işareti artık geçersiz sayılıyor ve kullanıcı temiz onboarding'e yönleniyor.
> - Firebase App Check iOS yapılandırması API üzerinden doğrulandı: App Attest ve DeviceCheck kayıtları mevcut.
> - İlk `1.0.1 (12)` yüklemesi Apple `90101` cihaz ailesi hatasıyla reddedildi. Önceki sürümle uyumluluk korunarak `TARGETED_DEVICE_FAMILY = 1,2` yapıldı ve build 13 üretildi.
> - `1.0.1 (13)` archive/IPA imza ve bütünlük kontrolleri geçti; IPA içindeki `UIDeviceFamily` değeri `[1, 2]`. Xcode Organizer yüklemeyi **App upload complete / Uploaded to Apple** olarak doğruladı.
> - App Store Connect'te yeni sürüm oluşturma ve incelemeye gönderme, **Apple Developer Program License Agreement Updated** uyarısı nedeniyle bloke. Apple, mevcut uygulamaları güncellemek için Account Holder'ın güncel sözleşmeyi kabul etmesini zorunlu tutuyor. Bu hukuki kabul kullanıcı tarafından yapılmalı.

## Yönetici özeti

**Karar: TestFlight yüklemesi için teknik paket hazır; yayın kabulü henüz koşullu.**

Önceki rapordaki 1–4 numaralı işler uygulandı. Flutter ve Functions testleri geçiyor, Functions üretim bağımlılıklarında bilinen açık kalmadı, temiz iOS simülatör açılışında önceki Firestore `permission-denied` olayı tekrarlanmadı ve demo akışı artık onboarding/profil/grup/vakit durumunu tutarlı biçimde taşıyor.

Fiziksel iPhone'a imzalı debug uygulaması başarıyla kuruldu ve başlatıldı. Release archive ile App Store IPA da başarıyla üretildi ve yerel bütünlük/imza kontrollerini geçti. Buna karşın fiziksel cihaz testi Firebase App Check iOS kaydının eksik olduğunu, cihazda bildirim izninin verilmediğini ve alarm kaydının bu nedenle reddedildiğini gösterdi. TestFlight yükleme arayüzü ayrıca Mac kilitli olduğu için tamamlanamadı.

## Test edilen ortam

- Tarih: 6 Kasım 2026, Europe/Istanbul
- Flutter: 3.44.8 stable
- Dart: 3.12.2
- Simülatör: iPhone 17 Pro, iOS 26.5
- Fiziksel cihaz: iPhone SE, iOS 27.0.1, kablosuz geliştirme
- Uygulama: 1.0.0 (11)
- Bundle ID: `com.namazgrubum.namazGrubum`
- Deployment target: iOS 15.0
- Team: `X9D4X4F752`
- Functions hedefi: Node 22
- Yerel Node: 24.3.0; `EBADENGINE` uyarısı devam ediyor

## 1–4 numaralı düzeltmeler

### 1. Flutter runtime exception'ları

- `Gruplarım` dönüş yenilemesindeki async `setState` callback'i senkron blok olarak düzeltildi.
- Onboarding'in boş ad yolu ilk sayfada inline hata gösteriyor; Cupertino ekranında `ScaffoldMessenger` assertion'ı üretmiyor.
- Her iki yol için regresyon widget testleri eklendi.

### 2. Functions güvenliği

- `firebase-admin`, `firebase-functions`, `sharp`, `@grpc/grpc-js` ve ilgili geçişli bağımlılıklar güvenli sürümlere yükseltildi/sabitlendi.
- `npm audit`: **0 açık**.
- TypeScript build: **geçti**.
- Firestore + Storage emulator güvenlik testleri: **21/21 geçti**.

### 3. Temiz canlı açılış yarışı

- Auth ID token ve App Check token yenilemesi ilk profil okumasından önce çalıştırılıyor.
- İlk `permission-denied` profil okumasında kimlik bilgileri bir kez yenilenip sunucudan kontrollü retry yapılıyor.
- Aynı kullanıcı için tekrarlanan auth callback'i ikinci eşzamanlı kurulum başlatmıyor.
- iPhone 17 Pro simülatör açılışında önceki Firestore `permission-denied` olayı tekrarlanmadı.
- App Check debug token Firebase'de kayıtlı olmadığı için 403 logu alındı; bu hata artık oturum kararını bloke etmiyor.

### 4. Demo durum tutarlılığı

- Onboarding adı, şehir, mezhep ve bildirim tercihi `SharedPreferences` tabanlı tek demo oturumunda saklanıyor.
- Ana ekran ve profil aynı adı/tercihleri gösteriyor; profil değişiklikleri aynı oturuma yazılıyor.
- Demo grup oluşturma gerçek repository state'ine ekleniyor; keşif, `Gruplarım`, detay ve sahip üye listesinde bulunuyor.
- Sabit “Öğle + 1 saat 17 dakika” kaldırıldı. İstanbul, Ankara, Bursa, İzmir ve Konya için gerçek Adhan/Diyanet uyumlu yerel hesap kullanılıyor; diğer şehirler güvenli biçimde İstanbul koordinatına düşüyor.
- Demo oturumu ve oluşturulan grup kalıcılığı için testler eklendi.

## Otomatik doğrulama sonuçları

| Kontrol | Sonuç |
|---|---:|
| `flutter analyze` | Geçti, 0 bulgu |
| Flutter testleri | 35/35 geçti |
| Functions `npm ci` | Geçti; yalnız Node 22/24 engine uyarısı |
| Functions TypeScript build | Geçti |
| Firestore + Storage güvenlik testleri | 21/21 geçti |
| `npm audit` | 0 açık |
| iOS simülatör debug build | Geçti |
| Fiziksel iPhone debug imza/kurulum/açılış | Geçti |
| Release archive | Geçti |
| App Store IPA export | Geçti |
| Archive codesign doğrulaması | Geçti |
| IPA ZIP bütünlüğü | Geçti |
| TestFlight yükleme | Tamamlanmadı; Mac kilitli |

## 5. Fiziksel iPhone kabul testi

### Geçen adımlar

- Apple Development otomatik imzalama
- Kablosuz cihaza kurulum
- Uygulama başlatma
- Dart VM/runtime bağlantısı
- Firebase başlatma sırasında uygulamanın çökmemesi
- App Check hatasına rağmen oturum bootstrap'ının kontrollü ilerlemesi

### Başarısız veya tamamlanamayan adımlar

- **App Check:** Firebase yanıtı iOS uygulamasının App Check'e kayıtlı olmadığını bildirdi (`FAILED_PRECONDITION: App not registered`). Debug token da kayıtlı değil.
- **Alarm:** Bildirim kaynağı yetkilendirilmediği için yerel alarm kaydı `UNErrorDomain 2003` ile reddedildi.
- **APNs teslimi, alarm sesi, sessiz mod/Odak, kamera çekimi, fotoğraf yükleme ve background/resume UI kabulü:** Fiziksel telefon ekranına uzaktan etkileşim yüzeyi bulunmadığı için uçtan uca çalıştırılamadı. Bunlar “geçti” olarak işaretlenmedi.

App Check sağlayıcısı Firebase Console'da iOS uygulaması için etkinleştirilmeli. Debug cihaz testi gerekiyorsa yalnız test süresince debug token kaydedilmeli ve sonra silinmeli. Ardından cihazda bildirim/kamera izinleri verilerek bu bölüm tekrarlanmalı.

## 6. Release archive ve TestFlight

### Üretilen çıktılar

- Archive: `build/ios/archive/Runner.xcarchive` — yaklaşık 521,8 MB
- IPA: `build/ios/ipa/Namaz Grubum.ipa` — yaklaşık 53,1 MB
- Flutter App Settings Validation: geçti
- Distribution certificate: Apple Distribution, geçerlilik 9 Eylül 2027
- IPA mimarisi: arm64
- dSYM/symbol paketleri IPA içinde mevcut
- `codesign --verify --deep --strict`: geçti
- `unzip -t`: hata yok

TestFlight yüklemesi başlatılmadan önce Xcode arayüzü açıldı; ancak Mac kilitli olduğu için App Store Connect oturumu ve yükleme adımları tamamlanamadı. Ayrıca App Check kaydı düzeltilmeden TestFlight backend smoke testi güvenilir biçimde geçemez.

## Ek build notları

- Disk 176 MB boş alana kadar dolduğu için ilk Xcode derlemesi `No space left on device` ile kesildi. Yalnız yeniden üretilebilir Flutter/Xcode build önbellekleri temizlendi; kaynak veya kullanıcı verisi silinmedi.
- Apple Silicon üzerinde CocoaPods'un gereksiz `x86_64` simülatör derlemesini önlemek için Podfile'a host mimarisine koşullu exclusion eklendi. Intel geliştirici makineleri etkilenmiyor.
- Firebase iOS SDK, CocoaPods dağıtımının Ekim 2026 sonrasında yeni sürüm almayacağını bildiriyor. Swift Package Manager geçişi ayrı bakım işi olarak planlanmalı.
- Proje yolundaki boşluk nedeniyle `pod install`, Crashlytics proje yolunu bir uyarıda yanlış kısalttı. Release archive başarıyla üretildi ve semboller pakette mevcut; yine de ilk TestFlight yüklemesinden sonra Crashlytics dSYM görünürlüğü ayrıca kontrol edilmeli.

## Kapanış koşulları

Yayın kabulünü tamamen kapatmak için:

1. Firebase App Check'te iOS uygulamasını App Attest + DeviceCheck fallback ile kaydet.
2. Fiziksel cihazda bildirim ve kamera izinlerini ver; APNs, sesli alarm, sessiz mod/Odak, fotoğraf yükleme ve background/resume akışlarını yeniden çalıştır.
3. Mac'i açıp Xcode/App Store Connect üzerinden build 11'i TestFlight'a yükle.
4. Processing tamamlanınca TestFlight'tan temiz kurulum yap; onboarding, backend erişimi, grup listesi/oluşturma, bildirim token kaydı ve Crashlytics dSYM durumunu smoke test et.
