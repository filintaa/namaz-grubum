# iOS Simulator test raporu — 4 Kasım 2026

## Sonuç

**Karar: Koşullu başarısız / yayın adayı olarak önerilmiyor.**

Uygulama iPhone 17 Pro / iOS 26.5 simülatöründe hem demo repository hem de canlı Firebase yapılandırmasıyla derlendi ve açıldı. Ana kullanıcı akışları çalışıyor; statik analiz, Flutter testleri, Firebase güvenlik testleri ve native XCTest hedefi geçti. Buna karşın iki kullanıcı akışında yakalanmamış Flutter exception'ı ve Functions üretim bağımlılıklarında kritik/yüksek güvenlik bildirimleri var. Bunlar giderilmeden yeni TestFlight/App Store build'i önerilmez.

## Test edilen sürüm ve ortam

- Kaynak commit: `df903576758118e2b6da2a6558548a1ec350ed96`
- Commit tarihi: 3 Kasım 2026 06:20 (+03:00)
- Uygulama sürümü: `1.0.0+10`
- Çalışma ağacı: test başlangıcında temiz
- Flutter: `3.44.8` stable
- Dart: `3.12.2`
- Xcode/iOS SDK: iOS Simulator 26.5
- Simülatör: iPhone 17 Pro, iOS 26.5
- Functions hedef runtime'ı: Node 22
- Test makinesindeki Node: `24.3.0` (engine uyumsuzluğu uyarısı verdi)
- Test tarihi/saat dilimi: 4 Kasım 2026, Europe/Istanbul

## Otomatik kontroller

| Kontrol | Sonuç | Not |
|---|---:|---|
| `flutter analyze` | Geçti | Hata/uyarı yok |
| `flutter test --reporter expanded` | Geçti | 31/31 test |
| Functions TypeScript build | Geçti | `tsc` başarılı |
| Firestore + Storage emulator güvenlik testleri | Geçti | 21/21 test |
| Native iOS XCTest | Geçti | 1/1; yalnızca boş şablon `testExample` |
| iOS debug build, demo mod | Geçti | İlk build 696,6 saniye |
| iOS debug build, canlı Firebase | Geçti | Cache sonrası 47,6 saniye |
| `npm audit --omit=dev` | Başarısız | 10 açık: 1 kritik, 4 yüksek, 5 orta |

Bağımlılık çözümlemesi ayrıca mevcut sürüm kısıtlarıyla uyumsuz 94 daha yeni paket bulunduğunu bildirdi. Bu tek başına hata sayılmadı; toplu major yükseltme yerine güvenlik açığı taşıyan doğrudan ve geçişli bağımlılıklar önceliklendirilmeli.

## Simülatörde doğrulanan akışlar

### Demo modu (`USE_FIREBASE=false`)

- Temiz kurulum ve onboarding üç adımı açıldı.
- Ad, cinsiyet, mezhep ve şehir alanları görüntülendi.
- Açık rıza verilmeden “Başla” ilerlemedi.
- Bildirim ve konum tercihleri kapatılabildi.
- Ana sayfa, önerilen gruplar ve alt navigasyon açıldı.
- `Gruplarım` listesi ve grup detayı açıldı.
- `Kalktım` durumu `Kıldım` durumuna geçirildi; katılım sayısı ve üye durumu güncellendi.
- Grup oluşturma formu açıldı ve demo create çağrısı tamamlandı.
- Sıralamada 7 gün / 30 gün seçimi çalıştı.
- Profil ve ayar anahtarları açıldı.

### Canlı Firebase yapılandırması

- Temiz kurulumda anonim oturum/onboarding ekranı açıldı.
- Bildirim ve konum kapalı tercihleriyle onboarding tamamlandı.
- Girilen görünen ad ana ekranda gösterildi.
- Sunucu takviminden sıradaki namaz ve geri sayım görüntülendi.
- Üyeliği olmayan yeni kullanıcı için boş `Gruplarım` durumu doğru görüntülendi.
- Grup oluşturma formu açıldı ve boş ad doğrulaması denendi.
- Canlı ortamda kalıcı bir grup oluşturulmadı. Temiz onboarding testi anonim bir Firebase Auth kullanıcısı ve ona bağlı test profilini oluşturdu; kullanıcı görünen adı simülatör klavye eşlemesi nedeniyle `Hdmh` olarak kaydedildi.

## Bulgular

### P1 — `Gruplarım` yenilemesi yakalanmamış Flutter exception'ı üretiyor

**Yeniden üretim:** Demo modunda `Gruplarım` → bir grup → geri dön veya grup oluşturma formunu tamamlayıp listeye dön.

**Gözlenen:**

```text
Unhandled Exception: setState() callback argument returned a Future.
_MyGroupsScreenState._refresh
lib/features/groups/presentation/my_groups_screen.dart:33
```

`setState(() => _groups = next)` içindeki assignment ifadesi `Future<List<GroupSummary>>` döndürüyor. `setState` callback'i senkron ve `void` olmalı. Ekran çoğu durumda çizilmeye devam etse de bu gerçek bir yakalanmamış runtime hatasıdır ve Crashlytics/günlük gürültüsü üretir.

**Öneri:** Atamayı blok callback'e çevirin (`setState(() { _groups = next; });`) ve grup detayından dönüş ile create sonrası yenilemeyi kapsayan widget testi ekleyin.

### P1 — Onboarding'de boş ad doğrulaması Snackbar assertion'ı üretiyor

**Yeniden üretim:** Ad alanını boş bırak → iki kez “Devam Et” → açık rızayı etkinleştir → “Başla”.

**Gözlenen:** İlk sayfaya dönülüyor, ardından Snackbar gösterilmeye çalışılırken:

```text
Unhandled Exception: ScaffoldMessenger.showSnackBar was called,
but there are currently no descendant Scaffolds to present to.
lib/features/onboarding/presentation/onboarding_screen.dart:92
```

Ekran Cupertino tabanlı olduğu için mevcut context altında Snackbar sunacak bir `Scaffold` yok. Kullanıcı doğrulama mesajını göremiyor; debug çalıştırmada exception oluşuyor.

**Öneri:** İlk sayfadan ilerlemeden adı doğrulayın ve platforma uygun bir inline hata/Cupertino dialog kullanın; mevcut Snackbar gerekiyorsa doğru `ScaffoldMessenger`/`Scaffold` kapsamı sağlayın. Bu yolu doğrudan widget testiyle kapsayın.

### P1 — Functions üretim bağımlılıklarında 1 kritik ve 4 yüksek açık

`npm audit --omit=dev` sonucu:

- Kritik: `proxy-addr` — IP spoofing bildirimi.
- Yüksek: `@grpc/grpc-js`, `body-parser`, `brace-expansion`, `sharp <0.35.5`.
- Orta: `glob`, `minimatch`, `qs` ve bunlara bağlı zincirler.

Toplam sonuç 10 üretim açığıdır: 1 kritik, 4 yüksek, 5 orta. `npm audit fix` uygulanabilir düzeltmeler bulunduğunu bildirdi. Özellikle doğrudan bağımlılık olan `sharp` güvenli sürüme yükseltilmeli; geçişli bağımlılıklar güncellenip Functions build, emulator testleri ve fotoğraf uçtan uca testi yeniden çalıştırılmalı.

### P2 — Temiz canlı açılışta geçici Firestore `permission-denied`

Canlı Firebase ile ilk temiz açılışta `AppSessionController._configureUser` içindeki kullanıcı belgesi okuması bir kez `cloud_firestore/permission-denied` üretti ve Crashlytics tarafından kaydedildi. Uygulama onboarding'i göstermeye devam etti ve onboarding tamamlandığında ana ekrana başarıyla geçti.

Bu nedenle akış tamamen bloklanmıyor; ancak auth/App Check/ilk profil oluşturma sıralamasında yarış olabileceğini ve gerçek bir hata olayının gereksiz yere Crashlytics'e gönderildiğini gösteriyor.

**Öneri:** Auth token/App Check hazırlığı ile ilk profil read/create sırasını inceleyin; beklenen ilk-açılış durumunu kontrollü retry veya açık hata durumuyla ele alın. Temiz kurulum integration testi ekleyin.

### P2 — Demo repository create sonucunu listeye yansıtmıyor

Demo modunda grup oluşturma çağrısı başarılı görünerek forma geri dönüyor; `Gruplarım` hâlâ “3 aktif grup” gösteriyor ve yeni grup listede yok. Bu canlı Firebase repository yolunu doğrudan etkilemez, fakat simülatör/yerel kabul testini yanıltır.

### P2 — Demo kullanıcı tercihleri ve profil birbirinden kopuk

- Onboarding'de girilen ad yerine ana sayfa/profilde sabit `Muhammet A.` gösteriliyor.
- Onboarding'de bildirim kapatıldığı hâlde profil ayarı açık görünüyor.
- Demo ana sayfadaki “sıradaki namaz” gerçek vakit yerine sabit `Öğle + 1 saat 17 dakika` kurgusu kullanıyor; gece testinde “Sıradaki · Öğle” gösterildi.

Bu tutarsızlıklar üretim Firebase yolunda gözlenmedi, fakat demo modunu ürün davranışını temsil etmekten uzaklaştırıyor.

### P2 — Native iOS test hedefinde gerçek kapsam yok

`RunnerTests.swift` yalnızca boş `testExample()` içeriyor. Hedef ve uygulama test konfigürasyonu derlenip geçti, ancak AppDelegate, notification/deep-link yönlendirmesi veya native izin davranışını doğrulamıyor.

### P3 — iOS pod deployment target ve build uyarıları

XCTest build'i sırasında bazı pod hedefleri iOS 9/10/11 deployment target kullandığı için Xcode 26.5 uyarıları verdi. `geocoding_ios` PrivacyInfo dosyası için build rule uyarısı ve gRPC/abseil için her build'de çalışan script uyarıları da mevcut. Build başarılı; bunlar doğrudan işlev hatası değil, fakat ilk build süresini ve gelecekteki Xcode uyumluluk riskini artırıyor.

### Ortam notu — Node sürümü

Functions `nodejs22` hedefliyor; test makinesi Node 24.3.0 kullandığı için `npm` `EBADENGINE` uyarısı verdi. Testler geçti, ancak CI ve yerel doğrulama production runtime ile aynı Node 22 sürümünde tekrarlanmalı.

## Yayın öncesi önerilen sıra

1. İki yakalanmamış Flutter exception'ını düzeltin ve regresyon testlerini ekleyin.
2. Functions güvenlik açıklarını giderin; build + 21 emulator testi + fotoğraf E2E testini yeniden çalıştırın.
3. Temiz canlı açılıştaki Firestore permission yarışını araştırın ve integration test ekleyin.
4. Demo repository state'ini onboarding/profil/grup oluşturma arasında tutarlı hâle getirin.
5. Fiziksel iPhone'da bildirim, alarm sesi, kamera, fotoğraf yükleme ve background/resume kabul testi yapın. Bunlar simülatörle tam doğrulanamaz.
6. Son olarak release archive ve TestFlight smoke testi çalıştırın.

## Kanıtlar

- `artifacts/simulator-test-2026-11-04/01-launch.png` — temiz demo onboarding
- `artifacts/simulator-test-2026-11-04/02-home.png` — demo ana sayfa
- `artifacts/simulator-test-2026-11-04/03-group-completed.png` — grup detayı, tamamlanmış Sabah durumu
- `artifacts/simulator-test-2026-11-04/04-live-firebase-home.png` — canlı Firebase onboarding sonrası ana sayfa
- Native XCTest sonucu: `Test-Runner-2026.11.04_22-12-47-+0300.xcresult` (`TEST SUCCEEDED`)

## Test sınırları

- Kamera ile gerçek çekim, APNs teslimi, sesli alarm, sessiz mod/Odak etkileşimi ve background davranışı fiziksel cihaz gerektirir.
- Canlı Firebase ortamında kalıcı grup/fotoğraf oluşturulmadı. Ancak temiz onboarding akışının doğal sonucu olarak anonim Auth kullanıcısı ve kullanıcı profili oluşturuldu; test sonrası otomatik silme akışı bulunmadığından bu kayıt ortamda kalmış olabilir.
- Android emulator bu turda kapsam dışıydı; kullanıcı isteği iOS simülatörü üzerinde yürütüldü.
