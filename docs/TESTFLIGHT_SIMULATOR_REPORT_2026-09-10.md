# TestFlight ve iPhone SE test raporu — 10 Eylül 2026

## Sürüm

- Uygulama sürümü: `1.0.0`
- App Store Connect'teki son tester build'i: `3`
- Yerel sürüm numarası: `1.0.0+4` (yüklenmedi)
- Test cihazı: iPhone SE (3. nesil), iOS 18.1 Simulator
- Ek ortam: özel oluşturulmuş iPhone SE / iOS 26.5 Simulator

## TestFlight öncesi öncelik sırası

1. Fotoğraf yükleme güvenlik kuralları ve gerçek Firebase uçtan uca akışı.
2. Oturum, onboarding ve uygulamanın ilk açılış kararlılığı.
3. Küçük ekranlarda ana akışlar: giriş, grup oluşturma/katılma, grup detayı ve profil.
4. Statik analiz, Flutter testleri ve Firebase emulator güvenlik testleri.
5. Release arşivi, imzalama ve App Store Connect yüklemesi.

## Tamamlanan doğrulamalar

- [x] `flutter analyze`: hata ve uyarı yok.
- [x] Flutter testleri: 12/12 geçti.
- [x] Firestore ve Storage emulator güvenlik testleri: 20/20 geçti.
- [x] Gerçek Firebase fotoğraf uçtan uca testi geçti.
  - Kullanıcı oturumu açıldı.
  - Aktif üyelik ve `photo` doğrulamalı grup kullanıldı.
  - Aktif namaz penceresi oluşturuldu/doğrulandı.
  - JPEG Firebase Storage'a yüklendi.
  - `registerPrayerPhoto` çalıştı.
  - Firestore'da `photos` belgesi ve `completed_with_photo` check-in oluştu.
  - Fotoğraf grup sorgusunda bulundu ve Storage'dan indirilebildi.
  - Test verileri işlem sonunda temizlendi.
- [x] Onboarding: ad, mezhep, şehir ve gizlilik onayı akışı.
- [x] Gizlilik onayı kapalıyken devam edilemiyor.
- [x] Demo modunda Firebase başlatılmadan uygulama açılıyor.
- [x] Namaz vakitleri ana ekranda yükleniyor; timezone veritabanı başlangıçta hazırlanıyor.
- [x] Ana ekran ve önerilen gruplar küçük ekrana sığıyor.
- [x] Grup detayında `Kalktım` ve `Kıldım` durumları güncelleniyor.
- [x] Grup oluşturma formu iPhone SE'de kaydırılabiliyor.
- [x] Fotoğraflı doğrulama seçeneği küçük ekranda seçilebiliyor.
- [x] Sıralama 7/30 gün görünümü ve profil ekranı açılıyor.

## Tespit edilen eksikler ve riskler

### P1 — Fiziksel cihazda son kabul testi gerekli

Simulator kamera ile gerçek çekim davranışını güvenilir biçimde doğrulayamaz. TestFlight build'i fiziksel iPhone SE'de açıp kamera izni, gerçek fotoğraf çekimi, yükleme ilerlemesi ve “Bugünün fotoğrafları” görünümü bir kez daha doğrulanmalı. Backend tarafındaki gerçek Firebase uçtan uca test geçmiştir.

### P2 — Demo veri katmanı yeni grubu saklamıyor

Firebase kapalı simülatör modunda “Grubu Oluştur” başarıyla kapanıyor fakat oluşturulan grup `Gruplarım` listesine eklenmiyor. Bu, TestFlight üretim yolundaki Firebase repository'sini etkilemiyor; demo repository davranış eksikliğidir. Geliştirme sırasında uçtan uca arayüz testini zorlaştırıyor.

### P2 — Devre dışı ana butonun erişilebilirlik durumu

Onboarding'de gizlilik onayı verilmeden “Başla” dokunmaya tepki vermiyor fakat VoiceOver/erişilebilirlik ağacında düğme açıkmış gibi duyuruluyor. `disabled` semantiği eklenmeli.

### P3 — Demo profil adı onboarding adıyla eşleşmiyor

Firebase kapalı modda onboarding sırasında girilen ad tamamlanınca ana uygulamadaki statik demo profilinde görünmüyor. Üretim hesabı akışını etkilemiyor.

### Test ortamı sorunu — özel iOS 26.5 Simulator

Özel `Rise Test — iPhone SE` simülatöründe işletim sistemi/Simulator kaynaklı bozuk safe-area değeri (yaklaşık 829 milyon piksel alt padding) ve üst üste çizilmiş onboarding görüldü. Standart iPhone SE iOS 18.1 simülatöründe aynı kod normal çalıştı. Özel simülatör silinip yeniden oluşturulmalı; bu bulgu tek başına uygulama hatası olarak değerlendirilmedi.

## TestFlight kabul kontrolü

- [x] Apple Developer hesabı ve dağıtım sertifikası kullanılabilir.
- [x] App Store dağıtım provisioning profili kullanılabilir.
- [x] Release archive oluşturuldu.
- [x] Build 3 daha önce App Store Connect'e yüklendi ve tester geri bildirimleri alındı.
- [x] Build 4 release archive yerelde oluşturuldu.
- [ ] Build 4 yüklemesi kullanıcı talebiyle durduruldu; açık onay olmadan yeni build/yükleme yapılmayacak.
- [ ] Fiziksel iPhone SE'de TestFlight üzerinden son kamera/fotoğraf kabul testi yapılmalı.
