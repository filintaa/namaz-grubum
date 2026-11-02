# Mimari kararlar

## 1. Mobil teknoloji

Flutter seçildi. Ürün mantığı ve veri erişimi paylaşılır; görsel kabuk aynılaştırılmaz:

- iOS: `CupertinoApp`, `CupertinoPageScaffold`, `CupertinoNavigationBar`, `CupertinoTabBar`, Cupertino alan ve butonları.
- Android: `MaterialApp`, Material 3 `Scaffold`, `AppBar`, `NavigationBar`, Material alan ve butonları.
- Ortak: renk/boşluk tokenları, domain modelleri, repository ve servis sözleşmeleri.

Bu ayrım, iki tamamen ayrı kod tabanının bakım maliyetini oluşturmadan platform beklentilerini korur. Alarm güvenilirliği yetersiz kalırsa `AlarmService` arayüzünün altında Swift/Kotlin implementation eklenebilir; UI veya domain katmanı değişmez.

## 2. Katmanlar

```text
Presentation -> application state -> repository/service interfaces
                                      |-> demo adapters
                                      |-> Firebase adapters
```

UI doğrudan Firebase çağırmaz. Kritik durumlar istemcide hesaplanıp yazılmaz. Streak, leaderboard, rate-limit, rapor sayısı ve fotoğraf görünürlüğü güvenilir backend tarafından yönetilir.

## 3. Çevrimdışı davranış

- Namaz vakitleri cihazda önceden tutulur.
- Birkaç günlük local alarm planlanır; uygulama açıldığında ve timezone/konum değiştiğinde yeniden planlanır.
- FCM yalnızca Uyandır, yönetici hatırlatması ve grup olayları içindir.
- Check-in optimistic olabilir ancak sunucu cevabı nihai kaynaktır.
- Bekleyen istekler idempotency key ile tekrar denenir.

## 4. Zaman modeli

- Veritabanındaki timestamp alanları UTC'dir.
- Her kullanıcıda IANA timezone adı saklanır.
- Sunucu, kullanıcı başına `users/{uid}/prayerDays/{YYYY-MM-DD}` altında güvenilir pencere üretir.
- Sabah penceresi Fajr başlangıcından sunrise'a kadardır.
- Normal tamamlama pencere içinde, kaza tamamlama pencere sonrasında kabul edilir.
- Seyahat algılandığında eski alarmlar iptal edilmeden yenileri planlanmaz.

## 5. Firestore okuma maliyeti

- Keşfet ekranı sayfalı grup sorgusu kullanır.
- Yalnızca açık aktif grup ekranı realtime dinlenir.
- `groups/{groupId}/dailyStats/{dateKey}` ile sayım tek dokümandan okunur.
- Leaderboard gecelik hesaplanır; mobil istemci canlı toplama yapmaz.
- Üye listesi sayfalanır; her üye için ek sorgu yapılmaz.

## 6. Güvenlik sınırı

Firestore kuralları istemcinin kritik koleksiyonlara yazmasını engeller. Aşağıdaki işlemler callable function üzerinden gerçekleşir:

- namaz durumu kaydı
- üyelik/onay ve yönetici değişiklikleri
- Uyandır ve toplu hatırlatma
- rapor sayısı ve otomatik gizleme
- streak, daily stats ve leaderboard
- fotoğraf yükleme bileti ve silme
- hesap silme orkestrasyonu

Callable işlemler Firebase Authentication, aktif kullanıcı ve grup üyeliği kontrolleriyle korunur. App Check, mağaza imzaları yapılandırıldıktan sonra yeniden zorunlu hale getirilecektir. Firebase Admin SDK istemci tarafından erişilemez.

## 7. Fotoğraf akışı

1. Uygulama yalnızca dahili kameradan görüntü alır.
2. Uzun kenar 640–800 px olacak şekilde sıkıştırır; 50–150 KB hedefler.
3. Backend üyeliği ve grubun `photo` doğrulama tipini kontrol eder.
4. Private Firebase Storage object key `prayer-photos/{group}/{date}/{user}/{photo}.jpg` biçimindedir.
5. Firestore yalnızca metadata/object key tutar.
6. Görüntüleme Firebase Storage kurallarıyla yalnızca aktif grup üyelerine açılır.
7. Her 30 dakikada çalışan idempotent görev 12 saati geçen objeyi siler, metadata durumunu `deleted` yapar.

Ekran görüntüsünün teknik olarak engellenemediği kullanıcıya yüklemeden önce açıkça söylenmelidir.

## 8. Tasarım tezi

Arayüz sakin, güven veren ve görevi hızlı bitirmeye odaklıdır. Kırık beyaz yüzey, kömür rengi metin ve tek zümrüt vurgu kullanılır. Dini klişeler, altın süsleme, kişisel rekabet ve rozet kalabalığı kullanılmaz. Başarı ekran süresi değil, kullanıcının doğru eylemi tamamlayıp çıkmasıdır.
