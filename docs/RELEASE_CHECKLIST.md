# Üretim kontrol listesi

## Hesaplar ve ürün kararları

- [x] Firebase proje kimliği (`namaz-grubum`) ve Blaze faturalandırma hesabı seçildi
- [x] Firebase Storage bucket `europe-west1` bölgesinde oluşturuldu
- [x] iOS bundle ID ve Android application ID kesinleştirildi
- [ ] iOS 15 minimum sürüm desteği ürün hedefiyle onaylandı
- [ ] App Store / Play Store ekipleri ve signing anahtarları tanımlandı
- [x] Namaz vakti motoru bağlandı: Türkiye için Adhan/Diyanet yaklaşımı, diğer bölgeler için Moonsighting Committee; Hanefi/Şafii ikindi ayrımı
- [ ] Deep-link domain'i ve mağaza URL'leri onaylandı
- [x] KVKK aydınlatma metni, kullanım koşulları ve topluluk kuralları hazırlandı
- [ ] Hukuk uzmanı veri sorumlusu kimliği, yurtdışı aktarım mekanizması ve özel nitelikli veri şartlarını son kez inceledi
- [ ] Moderasyon yanıt/itiraz SLA'sı ürün sahibi tarafından onaylandı

## Firebase

- [x] `flutterfire configure` çalıştırıldı
- [x] Anonymous Authentication etkinleştirildi
- [x] FCM token kayıt ve yenileme akışı callable function üzerinden bağlandı
- [x] Email/password auth etkinleştirildi; anonim hesap yükseltme ve şifre sıfırlama bağlandı
- [ ] Mağaza imzalarıyla App Check zorunlu hale getirildi (istemci Play Integrity/App Attest ile hazır, enforcement mağaza sürümünden sonra)
- [x] Firestore ve Storage rules emulator testleri yazıldı
- [x] TTL policy `expiresAt` alanları için etkinleştirildi (`idempotency`, `wakeNudges`, `photos`)
- [x] Mevcut Functions için uygulama secret'ı gerekmediği doğrulandı
- [ ] FCM APNs anahtarı yüklendi
- [x] Aylık 100 TRY bütçe ve yüzde 50/90/100 uyarıları doğrulandı
- [x] Functions 5xx ve zamanlanmış görev hata politikaları e-posta kanalına bağlandı

## Alarmlar

- [ ] iOS fiziksel cihazda uygulama kapalı/yeniden başlatılmışken test edildi
- [ ] Android 13+ bildirim izni test edildi
- [ ] Android exact alarm izni ve üretici pil optimizasyonları test edildi
- [x] Saat dilimi ve DST koordinattan sunucu tarafında üretiliyor; 8 günlük takvim yenileniyor
- [ ] Seyahat ve saat dilimi değişimi fiziksel cihazda test edildi
- [x] Alarm eylemleri Kalktım/Ertele için native bildirim kodu bağlı

## Fotoğraf ve güvenlik

- [x] Firebase Storage varsayılan olarak public erişime kapalı
- [x] Upload MIME, boyut ve JPEG decode kontrolü server-side
- [ ] 12 saat silme görevi staging verisiyle doğrulandı
- [x] Storage erişiminde grup üyeliği her istekte doğrulanıyor
- [ ] Otomatik gizleme: en az 3 farklı kullanıcı ve en az yüzde 5 eşiği test edildi
- [x] Hesap silme profil/üyelik/fotoğrafı temizliyor ve tarihsel check-in kimliğini anonimleştiriyor

## Mağaza öncesi

- [ ] FlutterFire paketlerinin Built-in Kotlin geçişi kontrol edildi
- [ ] VoiceOver ve TalkBack akışları tamamlandı
- [ ] Dynamic Type / büyük yazı taşmaları giderildi
- [ ] Koyu mod tüm ekranlarda tamamlandı
- [ ] Türkçe metinler son okuma gördü
- [x] Türkçe/İngilizce ARB yerelleştirme altyapısı etkin; alt navigasyon çevrildi
- [x] Crashlytics ve Analytics varsayılan kapalı, Profil ekranında ayrı rızaya bağlı
- [x] Check-in işlemleri düşük ağda 7 günlük kullanıcı-bazlı kuyruğa alınıyor; idempotency koruması etkin
- [ ] 5/50/1000 üyeli grup performansı ölçüldü

## Tamamlanan ürün akışları

- [x] Gerçek kullanıcı üyeliklerinden Gruplarım ekranı
- [x] Günlük 7/30 gün istatistik ve grup sıralaması üretimi
- [x] Grup sahipliği devri ve sahibi olan hesap için güvenli silme engeli
- [x] Yönetici atama/kaldırma, üye çıkarma ve grup arşivleme
- [x] Kaza namazı kaydı ve tekrar kayıt koruması
- [x] Paylaşılabilir Firebase Hosting davet sayfası ve uygulama deep-link yakalama
- [x] Rızaya bağlı Crashlytics ve Analytics istemci entegrasyonu
- [x] Kullanıcıya özel onboarding/auth gate ve hesap değişiminde alarm/FCM yeniden kurulumu
- [x] Beş vakit seçilebilir grup katılımı, kaza, fotoğraf ve yönetici hatırlatması
- [x] Engelleme, 1/7/30 günlük uzaklaştırma, 7 günlük yeniden katılım bekleme ve hız sınırları
- [x] Yetkili claim korumalı moderasyon kuyruğu, hedef doğrulama ve karar bildirimi
- [x] Server-side arama önekleri, cursor sayfalama ve gerçek zamanlı grup güncellemeleri
- [x] Koordinat/saat dilimi/DST/mezhep bazlı 8 günlük güvenilir namaz pencereleri
