# Endux TPM ve Kestirimci Bakım Sistemi: Mimari Analiz ve Sistem Kılavuzu

Bu belge, Endux TPM ve Kestirimci Bakım Projesi'nin mevcut mimarisini inceleyerek; sistemin güçlü yanlarını, veritabanı/yazılım düzeyindeki tespit edilen eksikleri ve sistemi bir sonraki seviyeye taşıyacak geliştirme önerilerini içermektedir.

Sistemin kurulum felsefesi yatırımcıyı ve sektör uzmanlarını tatmin edecek seviyede "Zero Trust" (Sıfır Güven) ve "Proaktif Bakım" üzerine kurulmuştur. Otomasyon, İnsan ve Yapay Zeka üçgeni kusursuz planlanmıştır.

Aşağıda bu felsefenin teknik olarak ne durumda olduğu, hangi kısımların askıda/eksik olduğu çıkarılmıştır:

---

## 1. Güvenlik ve Kimlik Doğrulama Mimarisi (Mevcut Durum ve Analiz)

**Mevcut Güçlü Yanlar Sistemin Temelleri:**
- Veritabanınızdaki `kullanici` modelinde dışa kapalı bir sistem dizayn edilmiş. Kayıt formları yok, RBAC (Role Based Access Control) mimarisi için `rol_id` ilişkilendirilmiş.
- "Kantin Senaryosu" tehlikesi `makine` tablonuzdaki `makine_qr String @unique @default(uuid()) @db.Uuid` satırı ile tamamen kalıcı olarak çözülmüş. Tahmin edilemez bir seri ve gereğinde iptal edilip regenerate edilebilecek sağlam bir koruma kalkanı.

**Eksikler ve Geliştirme Önerileri:**
- **Akıllı Kullanıcı Adları (Prefix Factory):** Yöneticinin eklediği kullanıcılara "op_", "tkn_" gibi öneklerin atanması backend servisinde (Controller) "UserService Builder" katmanlı bir mantıkla kesin bir kurala (interceptor) oturtulmalıdır.
- **Tablet Oturumları (Session Management):** Operatörlerin JWT süreleri sınırsız veya çok uzun olmamalıdır. Vardiya süreleri (örn. 8-12 saat) baz alınarak, vardiya bittiğinde tablet otomatik çıkış (Force Logout) yapmalı ve yeni gelen operatör kendi token'ını almalıdır.

---

## 2. Veritabanının Kalbi: JSONB Esnekliği (Kritik Bulgular)

**Mevcut Güçlü Yanlar:**
- `makine_ozellikleri` json yapısı ile yüzlerce kolondan, şişmiş tablolardan ve null değerlerden kurtulmuşsunuz. Bu mikroservis ve NoSQL esnekliğini RDBMS içerisine alan muazzam bir karardır.

**⚠️ Acil Tespit Edilen Eksikler (Deficiencies):**
- **Şema Array (Dizi) Hataları:** Mevcut `schema.prisma` dosyanızda çok ciddi bir modelleme hatası var. RDBMS kurallarına ters bir biçimde alanlar array kalmış durumda. Örneğin: 
  - `makine_ozellikleri Json[]` (Json dizisi yerine tekil `Json` olmalı), 
  - `top_cal_sma_saati Decimal[]` (Sayı dizisi olmak yerine tekil `Decimal` olmalı),
  - `seri_no String[]`. 
  *Bu durum veritabanı tutarlılığını bozar ve arama yapmayı / AI modeline veri beslemeyi imkansızlaştırır. Acilen düzeltilmeli.*
- **JSON Validation (Şema Denetimi):** Esneklik kaosa dönüşebilir. "Kesme Hızı" bekleyen bir makineye "Su Basıncı" verisi girilmesini önleyecek ZOD veri doğrulama interfaceleri (daha önceki eforlarınızdaki makine.types.ts vb.) tam devreye alınmalı ve Prisma middleware'i olarak araya konulmalıdır.

---

## 3. Sistemin Çekirdeği: 3 Ayaklı Bakım Döngüsü

### Ayak 1: Otonom Bakım (Operatör)
- **Mevcut Durum:** Veritabanında `kontrol_sablonu`, `kontrol_maddesi` ve `gunluk_kontrol_formu` tabloları tam da tarif ettiğiniz gibi kurulmuş. Sabit formlardan çıkılmış, şablona (Template) dayalı dinamik bir yapıya geçilmiş durumda.
- **Geliştirme Önerisi:** Operatörlerin gireceği verilerin (Örn: Isı değeri 85 C, Titreşim 4) ileride Yapay Zeka (AI) tarafından tüketilebilmesi için string array'lerden ziyade "Key-Value" veya net Numeric bir yapıda depolanması gerekir. Ayrıca tableti kullanan operatör fabrikanın kör bir noktasındaysa interneti kopabilir, uygulamanın Frontend/PWA tarafında "Offline Mode" özelliği olmalıdır.

### Ayak 2: Planlı / Periyodik Bakım (Backend'in Kronometresi)
- **Mevcut Durum:** Veritabanınızda `makine_kullanim` ve `top_calısma_saati` mevcut, ancak burada en büyük risk pasif bir dinlemede olmak.
- **Acil İhtiyaç (Eksik):** Backend sisteminin sadece istek atıldığında çalışan pasif bir yapıdan öte aktif bir "Cron/Worker" mekanizmasına geçmesi şarttır. Arka planda Node.js (Örn: node-cron, BullMQ vb. ile) şu görevi yapan bir 'Maintenance Engine' koşmalıdır:
  - Her gece saat 01:00'da tüm makinelerin JSONB verisinin içindeki "planlı bakım" katsayısı ile saati kontrol et.
  - Sınırı aşan (10.000 saatte 9800'e gelmiş) varsa Alert Middleware üzerinden Push Notification / Socket.io ile yöneticiye anons et.

### Ayak 3: Kestirimci Bakım (Yapay Zeka - AI)
- **Mevcut Durum:** AI'ın tahminde bulunduğu ve bunun loglandığı muhteşem bir yapı (`ai_ariza_tespit`, `ai_model_log`) halihazırda var. Kestirimci (Predictive) felsefenin omurgası kurulmuş.
- **Mimarideki En Önemli Eksik (Entegrasyon):** İlker’in Scikit-Learn (Python) modeli ile Node.js backend'inin nasıl konuşacağı belirsiz. Bunun için şu kurgulanmalıdır:
  1. *İletişim:* Node.js ile Python modeli, Kafka, RabbitMQ veya HTTP/REST (FastAPI) üzerinden konuşmalıdır.
  2. *Feedback Loop (Öğrenme Döngüsü):* Kantindeki bir teknisyenin kapattığı `ariza_kaydi` ve girdiği iş bitimi (`bakim_kaydi`), node.js tarafından yakalanıp Webhook vasıtasıyla "Hey AI, tahmin ettiğin arıza gerçekten gerçekleşti / gerçekleşmedi" şeklinde Python servisine (Training set için True Class Labeling) yollanmalıdır. Bu sürekli öğrenmeyi (Continuous Learning) sağlar.

---

## Sonuç ve Sonraki Geliştirme Eylemleri (Roadmap)

Eğer projeyi yatırımcıya / jüriye sunacaksanız arka planda sisteminizin şu üç unsuru eksiksiz barındırdığını kanıtlamalısınız:

1. **Prisma Şemasının İyileştirilmesi:** Öncelikle hatalı "Array" alanlarının standart veri tiplerine çekilerek veritabanının atomik (1. Normal Form) hale getirilmesi.
2. **Kuyruk / Event Mimarisi Kurulması:** AI'a veri yollamak ve bakım zamanı gelmiş makineleri tetiklemek için Sisteme **RabbitMQ** veya **Redis BullMQ** eklenmesi.
3. **Audit Log:** Sisteme "System Logger" eklenerek kimin hangi "akıllı kullanıcı adını" ne zaman değiştirdiği veya hangi QR kodunu regenerate ettiği Blockchain felsefesiyle bir 'action history' dahilinde tutulmalıdır.

Sisteminizin kurgusu kağıt üzerinde kusursuz bir TPM dijitalizasyonu vizyonudur. Geriye en temel Backend asenkron mimarilerini projenin kalbine yerleştirmek kalmıştır.
