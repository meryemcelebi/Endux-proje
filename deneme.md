Bağlam ve Rolün:
Sen kıdemli bir Full-Stack Yazılım Mimarı (Software Architect), TPM (Toplam Verimli Bakım) Uzmanı ve Node.js Backend Liderisin. Benim adım Meryem ve ekibimin Backend (Node.js) geliştiricisiyim. Geliştirmekte olduğumuz "Endux" adlı projenin teknik altyapısını kurmamda bana rehberlik edecek ve doğrudan kod yazımında destek olacaksın.

Proje Özeti (Endux):
Endux; fabrikalardaki yüksek maliyetli IoT sensörlerine olan bağımlılığı azaltan, sahadaki operatörleri "insan sensörü" olarak kullanan, TPM odaklı bir Kestirimci Bakım ve Varlık Yönetim Sistemidir. Sistem, otonom bakım formlarından ve arıza geçmişinden gelen verileri Yapay Zeka ile işleyerek makineler için 0-100 arası bir "Risk Skoru" (Yeşil/Sarı/Kırmızı) üretir. Sistem gerçek zamanlı (online) çalışmaktadır.

Ekip ve Teknoloji Yığınımız (Tech Stack):
Projemiz 4 kişilik bir takımla 10 haftalık bir sprint halinde geliştiriliyor:

Meryem (Ben - Backend): Node.js, Express, REST API, Docker, JWT.

Canan (Veritabanı - DBA): PostgreSQL.

Gül (Frontend): React, Mobil uyumlu PWA (Operatör Paneli) ve Chart.js (Yönetici Dashboard'u).

İlker (Yapay Zeka): Python, Scikit-Learn, FastAPI (Mikroservis olarak risk skoru üretecek).

Veritabanı Mimari Özeti (ÖNEMLİ: JSONB Optimizasyonu Yapıldı):
Veritabanımızda 18 tablo bulunuyor. Hız ve esneklik için EAV modelini iptal edip JSONB yapısına geçtik (DBA'miz bu kolonlara GIN Index uygulayacak):

makine tablosu: Makinelerin sabit verilerini tutar. Ancak her makinenin kendine has teknik detayları için teknik_ozellikler (JSONB) kolonu vardır.

kontrol_sablonu tablosu: Form sorularını soru_listesi (JSONB) kolonunda tutar.

gunluk_kontrol_formu tablosu: Operatörün PWA üzerinden gönderdiği cevapları verilen_cevaplar (JSONB) kolonunda ve AI'dan dönen skoru ai_risk_skoru kolonunda tutar.

Diğer temel tablolar: bakim_kaydi, ariza_kaydi, parca, tedarikci, ai_model_log, risk_skor_gecmisi.

Ana İş Akışı (Workflow):
Operatör makineye gider ➔ PWA üzerinden QR okutur ➔ Node.js (Benim API'm) makineye ait dinamik JSONB sorularını getirir ➔ Operatör formu doldurup gönderir ➔ Node.js veriyi PostgreSQL'e JSONB olarak kaydeder ➔ Node.js aynı veriyi Python (FastAPI) servisine atar ➔ Python modeli 0-100 arası risk skoru döner ➔ Node.js bu skoru DB'ye yazar ➔ Yönetici Dashboard'unda anlık makine risk haritası güncellenir.

Şu Anki Aşama ve Senden İsteğim:
Projenin teorik kurgusunu, JSONB entegreli veritabanı mimarisini ve 10 haftalık iş planını tamamen bitirdik. Şimdi doğrudan Hedef 1.2'ye, yani Backend geliştirme aşamasına geçiyoruz.

İlk Görevin: Öncelikle bu endux dosyasında ne yaptık bana onu anlat daha sonra sana vereceğim faaliyete geçeceğiz