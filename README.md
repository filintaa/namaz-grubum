# Namaz Grubum

Namaz için sosyal sorumluluk ve devamlılık uygulamasının iOS/Android temel altyapısı.

Bu depo `namaz-grubum` Firebase projesine bağlı çalışır bir ürün iskeleti, platforma uyarlanan arayüz, örnek veri katmanı ve güvenli backend başlangıcı içerir. Firebase gerektiğinde `USE_FIREBASE=false` ile kapatılarak uygulama demo modunda çalıştırılabilir.

## Neler hazır?

- iOS'ta Cupertino, Android'de Material 3 uygulama kabuğu
- Feature-based Flutter mimarisi
- Riverpod bağımlılık enjeksiyonu ve GoRouter navigasyonu
- Kullanıcıya özel kalıcı onboarding/auth gate: isim, cinsiyet, mezhep, şehir, KVKK/rıza ve izin tercihleri
- Ana sayfa: sunucuda hesaplanan sıradaki namaz ve geri sayım, sayfalı sunucu araması, grup oluşturma ve keşif
- Grup ekranı: beş vakit seçimi, katılım özeti, Kalktım, Kıldım, Kaza, Uyandır, fotoğraf ve gerçek zamanlı üye durumları
- Grup bazlı 7/30 günlük sıralama ve kişisel devamlılık profili
- Loading, empty ve error durumları; temel erişilebilirlik etiketleri
- Firebase Auth/Firestore/Messaging/Functions bağımlılıkları
- Firestore güvenlik kuralları ve indeksler
- Kimlik ve üyelik doğrulamalı Cloud Functions: grup oluşturma, check-in, Uyandır, yönetici hatırlatması, uzaklaştırma/engelleme, moderasyon, namaz takvimi ve fotoğraf silme
- Türkçe/İngilizce ARB altyapısı, büyük yazı desteği ve uygulama içi KVKK/koşullar/topluluk metinleri
- Android alarm, bildirim, kamera, konum ve app-link manifest altyapısı
- iOS kamera, konum ve özel URL scheme izinleri

## Çalıştırma

Gereksinimler: Flutter 3.44 veya üzeri, Dart 3.12 veya üzeri, Xcode 26 veya güncel Android Studio.

```bash
flutter pub get
flutter run
```

Firebase varsayılan olarak açıktır. Yerel arayüz geliştirmesinde sahte ama gerçekçi verileri kullanmak için:

```bash
flutter run --dart-define=USE_FIREBASE=false
```

Test ve statik analiz:

```bash
flutter test
flutter analyze
cd functions
npm ci
npm run build
npm audit --omit=dev
```

## Firebase bağlantısı

Firebase projesi ve iki native uygulama kaydı oluşturulmuştur. iOS bundle ID `com.namazgrubum.namazGrubum`, Android application ID `com.namazgrubum.namaz_grubum` ve varsayılan CLI projesi `namaz-grubum` olarak yapılandırılmıştır.

Native Firebase ayarlarını yeniden üretmek gerekirse:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Kural, Storage ve fonksiyonları yayınlamak için:

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

Uygulama açılışta anonim oturum oluşturur. Onboarding ve açık rıza kullanıcı bazında kalıcı tutulur. Tamamlanırken koordinat/şehir tercihinden sekiz günlük güvenilir namaz penceresi üretilir, alarm planlanır ve FCM token'ı `registerDevice` callable fonksiyonu üzerinden yalnızca aktif hesaba bağlanır. Repository provider, Firebase başlatılmışsa Firestore/Functions adapter'ını; değilse demo adapter'ını otomatik seçer.

## Dizinler

```text
lib/
  app/                  uygulama kökü ve navigasyon
  core/
    data/               repository sözleşmesi ve demo veri
    domain/             platformdan bağımsız modeller
    services/           alarm, vakit, fotoğraf, analitik sınırları
    platform/           iOS/Android ayrımı
    theme/              ortak görsel tokenlar
    widgets/            adaptif temel bileşenler
  features/
    onboarding/
    home/
    groups/
    rankings/
    profile/
functions/              güvenilir sunucu işlemleri
docs/                   kararlar, veri ve yayın kontrol listeleri
```

## Ürün sınırları

Kişisel leaderboard, sohbet, DM, Kur'an okuyucu, kıble, AI dini yorum, rozet/coin sistemi ve galeriden doğrulama fotoğrafı MVP'ye dahil değildir. Fotoğraf bucket'ı public olmamalı; istemciye kalıcı public URL verilmemelidir.

Detaylı kararlar için [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) ve [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) dosyalarına bakın.
