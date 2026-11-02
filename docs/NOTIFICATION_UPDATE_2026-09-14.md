# Namaz bildirimleri — 14 Eylül 2026

## Yapılan değişiklikler

- Onboarding bildirim anahtarı artık gerçek tercih olarak kaydedilir. Açık tercih tek başına izin verilmiş sayılmaz.
- “Bildirimlere izin ver” düğmesi sistem iznini giriş tamamlanmadan ister. Kullanıcı düğmeye basmadan Başla'yı seçerse, açık bildirim tercihi için izin yine onboarding sırasında sorulur.
- Gerçek izin sonucu ekranda gösterilir. Reddeden kullanıcı onboarding'e devam edebilir; Ayarlar yolu açıklanır.
- Mevcut hesap girişinde de izin kontrolü yapılır; daha önce kaydedilmiş bildirim kapatma tercihi otomatik olarak açılmaz.
- Her namaz için aday plan: -10 dakika, vakit başlangıcı, +5 dakika, sabah +10/+20 dakika (diğerleri +15/+30), bitişten 10 dakika önce. Çakışan saatler tekilleştirilir; bitiş anında/sonrasında bildirim yoktur.
- Son 10 dakika uyarısı kısa vakitlerde diğer takip uyarılarıyla birleşebilir. Geçmiş saatler planlanmaz.
- Sunucunun ürettiği 8 günlük ana vakit alarmları korunur. Kalan kuyruk alanı en yakın takip uyarılarına ayrılır. Azami 60 bekleyen namaz bildirimi; erteleme/grup için boşluk bırakılır. Her gün bütün takip adaylarının kuyrukta bulunması garanti edilmez.
- Yatsının gece yarısından sonraki son uyarısı ve ertelemesi orijinal namaz gününü/deadline'ını korur.
- Başarılı normal/fotoğraflı check-in ve başarıyla senkronize edilmiş çevrimdışı tamamlamalar, aynı cihazdaki ilgili namaz/tarih alarmlarını ve ertelemeyi iptal eder. Tamamlama bilgisi kullanıcı bazında yerelde saklanır; yeniden planlama bunu atlar.
- Bildirim tercihi kapatıldığında yerel namaz alarmları da durur. Eski teslim edilmiş uyarıdan erteleme, kapalı tercih veya yerelde bilinen tamamlanma için yeniden alarm oluşturmaz.
- iOS yerel uyarılarında ses/banner/list açık; Release entitlement'ta Time Sensitive Notifications eklendi.
- wakeMember/sendAdminReminder APNs payload'ına varsayılan ses ve time-sensitive eklendi. Android ses açık. İki platform için 15 dakikalık push teslim süresi; eski hatırlatmalar uzun süre sonra teslim edilmez.
- wakeMember sunucuda tamamlanmış check-in hedefini de kontrol eder; tamamlayan kişiye yeni uyandırma isteği göndermez ve throttle kotasını tüketmez.

## Sınırlar / yayınlama

- Kullanıcının iOS bildirim, ses, Odak ve zaman-duyarlı bildirim tercihleri aşılmaz. Sessiz modda zorunlu çalma veya kesin uyandırma garantisi yoktur.
- Vakit verisi eksikse uydurma saatten alarm üretilmez. Sekiz gün sonrasında vakit/plan yenilemek için uygulamanın açılması gerekir.
- Başka cihazdaki tamamlamanın bu cihazdaki alarmı anında iptal etmesi bu değişikliğin kapsamında değildir.
- Bu değişiklik için yeni iOS build'i ve Firebase deployment yapılmadı. Canlı wakeMember/sendAdminReminder ses değişikliği ancak ilgili iki fonksiyon dağıtıldıktan sonra geçerli olur.
- Sonraki Release imzalama işleminde Time Sensitive yetkisinin provisioning profile ile uyumu kontrol edilmeli.
- Fiziksel iPhone SE'de izin kabul/red, kilitli ekran sesi, Odak, erteleme, normal/fotoğraflı tamamlama sonrası iptal ve foreground/background grup push testi hâlâ yapılmalı. Otomatik testler gerçek APNs teslimatının yerine geçmez.

## Doğrulama

- Son kaynak hâliyle `flutter test --no-pub --reporter expanded`: 28/28 başarılı.
- `flutter analyze --no-pub`: sorun yok.
- `functions/npm run build`: TypeScript derlemesi başarılı. Yeni backend davranışı gerçek callable/push teslimatıyla test edilmedi.
- `plutil -lint`: Release entitlements ve Xcode proje dosyası geçerli.
- Yerel bildirim platform testleri: seçili namaz/tarih iptali, erteleme iptali, geçersiz erteleme sınırı, geçerli erteleme payload'ı, iOS ses/category ayarları.
- Planlayıcı testleri: kısa/bozuk vakit, tekilleştirme, yatsı gece tarihi, 60 bildirim üst sınırı, ileriki gün ana alarmlarının korunması.
- Widget testleri: izin kabul/red sonuçları, gerçek opt-out, iPhone SE büyük yazı uyumu ve fotoğraflı Kıldım akışı.
