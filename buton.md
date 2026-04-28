Sen "Endux Kestirimci Bakım (TPM)" projesinde çalışan Kıdemli bir Backend Geliştiricisisin. Node.js, TypeScript ve Prisma ORM kullanıyoruz.

Frontend ekibimiz "Bakım Yönetim Merkezi" ekranını tamamladı. Bu ekranda durumları "Onay Bekliyor" olan arıza/bakım kayıtları listeleniyor. Yönetici bu talepleri inceleyip "Onayla" veya "Yok Say" butonlarına basacak. Onaylanan işler "Teknik Servis İş Listesi" ekranına düşecek, yok sayılanlar ise arşivlenecek.

Senden bu iş akışını yönetecek 2 adet Controller fonksiyonu ve bunların Router (api.js / routes) tanımlarını yazmanı istiyorum. Lütfen projendeki mevcut arıza/bakım şemanı baz alarak şu mantığı kurgula:

[1. KONTROLÖR 1: bakimlariOnayla (Approve Maintenance)]
- Frontend'den onaylanması istenen kayıtların ID'lerini bir dizi (array) olarak alsın: `req.body.bakim_idler` (Örn: [12, 15, 18]).
- Prisma kullanarak bu ID'lere sahip kayıtların durumunu (status/durum kolonunu) "Teknik Serviste" (veya sisteminizdeki ilgili aktif duruma) çeksin.
- Bu işlem sayesinde, Teknik Servis ekranı sadece durumu "Teknik Serviste" olan kayıtları fetch ettiğinde bu işler o listeye otomatik düşmüş olacaktır.

[2. KONTROLÖR 2: bakimiYokSay (Ignore/Reject Maintenance)]
- Frontend'den reddedilecek kaydın ID'sini alsın. (Çoklu da olabilir, tekli de).
- Prisma kullanarak bu kaydın durumunu "İptal Edildi" veya "Reddedildi" olarak güncellesin. (Böylece ne onay bekleyenlerde ne de teknik servis listesinde görünmesin).

[3. ENDPOINT BAĞLANTILARI (Routes)]
- Yazdığın bu iki fonksiyonu Express Router'a bağla.
- RESTful standartlarına uygun olarak `PUT /api/bakim/onayla` ve `PUT /api/bakim/yoksay` şeklinde rotalar oluştur.

Lütfen fonksiyonları hata yönetimi (try-catch) ile modüler bir şekilde TypeScript kullanarak yaz ve Prisma'nın `updateMany` (çoklu güncelleme) özelliğini kullanarak veritabanı performansını optimize et.