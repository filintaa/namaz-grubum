# App Store Connect kontrol listesi

Bu belge, Namaz Grubum'un mevcut uygulama kodu ve Firebase kullanımı incelenerek 30 Eylül 2026 tarihinde hazırlanmıştır.

## URL alanları

| App Store Connect alanı | Girilecek URL |
| --- | --- |
| Marketing URL | https://filintaa.github.io/namaz-grubum/ |
| Support URL | https://filintaa.github.io/namaz-grubum/support.html |
| Privacy Policy URL | https://filintaa.github.io/namaz-grubum/privacy.html |
| User Privacy Choices URL | https://filintaa.github.io/namaz-grubum/account-deletion.html |

Ek bağlantılar:

- Kullanım koşulları: https://filintaa.github.io/namaz-grubum/terms.html
- Topluluk kuralları: https://filintaa.github.io/namaz-grubum/community.html

## App Privacy formu

Uygulama veri topladığı için **“Yes, we collect data from this app”** seçilmelidir.

Aşağıdaki liste mevcut uygulama işlevlerine göre hazırlanmış güvenli ve kapsamlı bir beyandır. App Store Connect'te kategori adları İngilizce gösteriliyorsa tabloda yazan adlar kullanılabilir.

| Veri türü | Toplanıyor | Kimlikle bağlantılı | İzleme için kullanılıyor | Amaç |
| --- | --- | --- | --- | --- |
| Contact Info → Name | Evet | Evet | Hayır | App Functionality |
| Contact Info → Email Address | Evet | Evet | Hayır | App Functionality, Account Management |
| Location → Precise Location | Evet | Evet | Hayır | App Functionality |
| Location → Coarse Location | Evet | Evet | Hayır | App Functionality |
| User Content → Photos or Videos | Evet | Evet | Hayır | App Functionality |
| User Content → Other User Content | Evet | Evet | Hayır | App Functionality |
| Identifiers → User ID | Evet | Evet | Hayır | App Functionality, Account Management |
| Identifiers → Device ID | Evet | Evet | Hayır | App Functionality; Analytics yalnızca kullanıcı izin verirse |
| Sensitive Info | Evet | Evet | Hayır | App Functionality |
| Usage Data → Product Interaction | İsteğe bağlı tanılama açıksa | Hayır | Hayır | Analytics |
| Diagnostics → Crash Data | İsteğe bağlı tanılama açıksa | Hayır | Hayır | Analytics, App Functionality |
| Diagnostics → Other Diagnostic Data | İsteğe bağlı tanılama açıksa | Hayır | Hayır | Analytics, App Functionality |

### Bu seçimlerin uygulamadaki karşılıkları

- **Name ve Email Address:** görünen ad ve kalıcı hesap e-posta adresi.
- **Precise/Coarse Location:** namaz vakti ve saat dilimi hesaplaması için koordinatlar, şehir, ülke ve saat dilimi.
- **Photos or Videos:** isteğe bağlı grup logosu ve doğrulama fotoğrafları. Doğrulama fotoğrafları normal işleyişte 12 saat içinde silinir.
- **Other User Content:** grup adı, grup içeriği ve rapor açıklamaları gibi kullanıcı tarafından girilen içerik.
- **User ID:** Firebase kullanıcı kimliği ve hesaba bağlı kayıtlar.
- **Device ID:** bildirim cihaz belirteci ve Firebase kurulum tanımlayıcıları.
- **Sensitive Info:** mezhep tercihi, cinsiyet tercihi ve ibadet/check-in bilgileri.
- **Product Interaction ve Diagnostics:** kullanıcı tanılama izni verdiğinde Firebase Analytics ve Crashlytics.

## Diğer yanıtlar

- **Tracking:** Hayır. Uygulama verileri üçüncü taraf uygulama veya sitelerde reklam amaçlı takip için kullanılmıyor.
- **Advertising:** Hayır. Uygulamada reklam veya üçüncü taraf reklam ağı bulunmuyor.
- **Account deletion:** Uygulama içinde Profil → Hesap → Hesabımı Sil akışı var. Web üzerinden açıklama ve destek yolu hesap silme sayfasında yer alıyor.
- **Privacy choices:** Kullanıcı tanılama paylaşımını uygulama ayarlarından değiştirebilir; hesap ve ilişkili veri silme seçenekleri sunulur.
- **Third-party partners:** Firebase Authentication, Firestore, Storage, Cloud Functions, Cloud Messaging, App Check; kullanıcı izin verirse Analytics ve Crashlytics.

## Yayın öncesi kısa kontrol

1. URL alanlarına yukarıdaki canlı bağlantıları ekleyin.
2. App Privacy cevaplarını App Store Connect'te **Publish** ile yayımlayın.
3. Yeni sürümde veri toplama veya SDK kullanımı değiştiyse tabloyu ve gizlilik politikasını güncelleyin.
4. Destek e-postasının `muhammetcalis@gmail.com` olarak çalıştığını doğrulayın.

App Store Connect'teki son beyan, yüklenen build'in gerçek davranışıyla aynı olmalıdır.
