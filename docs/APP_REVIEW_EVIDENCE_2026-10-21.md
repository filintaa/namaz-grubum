# Namaz Grubum — inceleme yanıtının kanıtları

21 Ekim 2026 tarihinde App Store Connect API ve yerel proje kayıtlarından doğrulandı. Bu dosya geliştirici için kanıt dizinidir; kaynak yollarının kendisi Apple'ın erişebileceği bir ek değildir.

## Gönderim durumu

- App ID: `6810047270`; bundle ID: `com.namazgrubum.namazGrubum`.
- App Store 1.0: `REJECTED`, ilişkili build: `8`.
- Build 9 ve 10: `VALID`. TestFlight'a yükleme, reddedilen sürümün build ilişkisini değiştirmedi.
- Bu hazırlık sırasında yeni gönderim, build değişikliği veya Apple'a mesaj gönderimi yapılmadı.

## Ürün sahibi beyanı

Kullanıcı 21 Ekim'de fikrin kendisine ait olduğunu, müşteri/ortak için yapılmadığını ve uygulamayı AI desteğiyle kendisinin geliştirdiğini belirtti. Diğer uygulamaların kodlarının ayrı yazıldığını, tasarımlarının farklı olduğunu söyledi. UI kit kullanıp kullanmadığını tam hatırlamıyor; bu yüzden tasarım kaynağı ve lisans konusunda kesin olmayan bir beyan eklenmedi.

Kolay Namaz: namaza başlamayan veya bırakmış kişiye bir vakitle başlama, bireysel destek ve İslami mentör görüşmesi.

Namaz Grubum: zaten namaz kılan arkadaşların sabah ve diğer vakitlerde grup içinde birbirini desteklemesi ve katılımı takip etmesi.

## API'de görülen beta geri bildirimleri

17 screenshot kaydı; 0 crash geri bildirim kaydı. İkinci sayı crash yaşanmadığının kanıtı değildir. TestFlight hesap sorgusu toplam üç kayıt döndürüyor: iki `INSTALLED`, bir `INVITED`. Yüklü hesaplar geliştirici Muhammet Çalış ve ek test kullanıcısı Emre Özdemir'e ait. Davet durumundaki üçüncü kayıt aynı geliştirici adına; test etmiş kişi olarak sayılmadı.

Geliştirici hesabının cihazı `iPhone12_8` (iPhone SE 2. nesil), ek test kullanıcısının cihazı `iPhone15_3` (iPhone 14 Pro Max). İki hesabın da güncel cihaz kaydı `1.0.0 (10)` gösteriyor. Screenshot geri bildirimlerinin 14'ü geliştirici hesabından, 3'ü ek test kullanıcısından. Bu nedenle doğrulanmış kapsam: geliştirici dahil iki yüklü tester hesabı, geliştirici dışında bir ek tester. Oturum sayısı/süresi ölçülmedi.

Ek test kullanıcısının üç yorumu: “Kendi grubumu şikayet et var”, “Kalktım butonuna basınca mesaj tepki kısa oluyor”, “Katıl diyince”. API test kullanıcıları `GET /betaTesters?filter[apps]=6810047270&limit=200` üzerinden ve `Test` grubunun üye listesi üzerinden kontrol edildi. Davet sayısı ile kurulum sayısı ayrıldı.

| UTC tarih | Build | Kayıttaki geri bildirim |
| --- | --- | --- |
| 2026-10-02 05:15 | 9 | Uygulama çok yavaş açılıyor |
| 2026-10-01 14:04 | 8 | Splashscrendeki Logo’yu değişimeyi unutmuşsun |
| 2026-09-15 10:04 | 4 | Katilma isteği gönderdim ama yine böyle gözüküyor |
| 2026-09-14 04:25 | 4 | Biten namazlar pasif gözüksün. Vakiti girmeyen namazlarda onaylanmasın |
| 2026-09-14 04:24 | 4 | Sabah namazini kalktım dedim fakat gözüküyor yine |
| 2026-09-14 04:23 | 4 | İlk açılışta çok yavaş açılıyor |
| 2026-09-12 07:23 | 4 | Katilma isteği gönderilince grip sahibine bildirimi gitsin |
| 2026-09-11 12:56 | 4 | Kıldım dedikten sonra eğer foto onayı istiyorsa direk foto ekranı gelsin |
| 2026-09-10 14:52 | 3 | İsim kısmı bozuk düzelt |
| 2026-09-10 14:50 | 3 | Açılışta yavaş yükleniyor |
| 2026-09-10 05:50 | 3 | WhatsApp Dan namaz daveti gelince böyle hata veriyor |
| 2026-09-10 05:50 | 3 | Her acilista bu ekran geliyor |
| 2026-09-10 05:40 | 3 | Katilim isteği gönderdim fakat böyle gözüküyor |
| 2026-09-10 05:40 | 3 | Bu popup da tasarıma uygun olsun |
| 2026-09-10 05:36 | 3 | Kendi grubumu şikayet et var |
| 2026-09-10 05:36 | 3 | Kalktım butonuna basınca mesaj tepki kısa oluyor |
| 2026-09-10 05:34 | 3 | Katıl diyince |

Düzeltme ve doğrulama kayıtları: `TESTFLIGHT_FEEDBACK_2026-09-10.md`, `TESTFLIGHT_FEEDBACK_2026-10-01.md`, `TESTFLIGHT_FEEDBACK_2026-10-20.md`. Eski build 8'in tam kaynak snapshot'ı karşılaştırılmadığı için her güncel özelliğin build 8'de bulunduğu iddia edilmedi.

## İşlevin kod karşılıkları

- `functions/src/index.ts`: `createGroup`, `joinGroup`, `resolveJoinRequest`, `recordCheckin`, `wakeMember`, `sendAdminReminder`, `registerPrayerPhoto`, `deleteExpiredPhotos`.
- `lib/features/groups/presentation/`: grup oluşturma, grup ayrıntısı, üyeler, istekler, fotoğraf ve grup ayarları ekranları.
- `lib/core/services/invite_service.dart`: uygulama/grup davet bağlantıları.
- `test/widget_test.dart`: fotoğraflı grupta kamera akışı, gelecek vakitte işlem engeli, kaza ayrımı, kalıcı bekleyen istek ve dar ekran testleri.
- `docs/REALISTIC_FIVE_USER_TEST_REPORT_2026-09-10.md`: backend senaryoları sentetik test hesaplarıyla yapıldı; beş bağımsız insan beta test kullanıcısı olarak sunulamaz.

## Mevcut ekran görselleri

`artifacts/guncel-uygulama-ekranlari/` içindeki `02-grup-detayi.png`, `03-grup-uyeleri.png`, `04-gruplarim.png` ve `06-katilim-istekleri.png` grup işlevlerini gösteriyor. Klasörün README'sine göre bunlar simülatörde örnek verilerle alınmış görüntülerdir. Canlı müşteri kullanımı veya build 8'e ait birebir görüntü kanıtı olarak etiketlenmemelidir. Gerekirse açıklamasıyla görsel destek olarak eklenebilir.

## Açık kalan doğrulamalar

1. Beta katılımı ve yorumların kaynağı API'den doğrulandı: geliştirici dahil iki yüklü tester hesabı, geliştirici dışında bir ek tester. Üçüncü hesap yalnız davetli. 14 geliştirici, 3 ek tester screenshot bildirimi var. Büyük bir bağımsız beta grubu iddia edilmedi.
2. Freud UI Kit: tema yorumu ve `artifacts/freud-redesign/` tasarım referansını destekliyor; hazır ticari uygulama kodu veya bir lisans belgesi tespit edilmiş değil. Kullanıcı lisans ve kullanım kapsamını hatırlamadığı için tüm tasarımın sıfırdan/orijinal olduğu ya da ticari kitin kesin kullanılmadığı iddia edilmedi.
3. Diğer uygulamalarla ayrı kod beyanı kullanıcıdan alındı. Diğer tüm kaynak depolarının dosya bazlı karşılaştırması yapılmadı; bu beyan bağımsız bir binary benzerlik analizi olarak sunulamaz.

## Apple'a gerçekten eklenecek kanıtların sunumu

- Birbirinden farklı grup ekranlarını göstermek için yukarıdaki dört PNG, örnek veri ve simülatör açıklamasıyla kullanılabilir.
- TestFlight yorumlarının tarih/build görünen ekran görüntüleri, yorumu ve ilgili düzeltmeyi eşleştiren kısa bir açıklamayla daha doğrudan destek sağlar. Bunlar bu çalışmada yakalanmadı; eklenmiş gibi yazılmamalıdır.
- İki cihazlı canlı kayıt hazırlanırsa grup oluşturma/davet/katılım onayı/üye durumları gösterilebilir. Böyle bir video bu çalışmada oluşturulmadı; mevcutmuş gibi atıf yapılmamalıdır.
- Kaynak kod, kullanıcı e-postaları, API anahtarları veya hassas kullanıcı fotoğrafları otomatik olarak paylaşılmamalıdır. API özeti kişisel e-posta ve geçici imzalı fotoğraf URL'leri içermiyor.
