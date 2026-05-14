# Maintify: Akıllı Endüstriyel Bakım ve Varlık Yönetim Sistemi
## Kapsamlı Teknik Mimari ve Uygulama Dokümantasyonu (v3.0)

Bu doküman, **Maintify** platformunun tüm katmanlarını, kullanılan programlama dillerini, yazılım metodolojilerini, veritabanı tasarım stratejilerini ve kullanıcı deneyimi mühendisliğini detaylandırmaktadır.

---

## 1. Teknoloji Ekosistemi (Technology Stack)

Sistem, modern web standartlarına uygun olarak ayrık bir mimari (Decoupled Architecture) üzerine inşa edilmiştir.

### **1.1. Frontend: Reaktif ve Dinamik Kullanıcı Arayüzü**
- **Dil:** JavaScript (ES6+ standartları).
- **Kütüphane/Framework:** **React 18**. Sanal DOM (Virtual DOM) yapısı sayesinde yüksek performanslı UI güncellemeleri sağlanır.
- **Derleme Aracı:** **Vite**. Hot Module Replacement (HMR) özelliği ile geliştirme hızı maksimize edilmiştir.
- **Veri Görselleştirme:** **Recharts**. SVG tabanlı reaktif grafikler ile bakım maliyetleri ve makine performansları analiz edilir.
- **İkonografi:** **Lucide React**. Modern, hafif ve özelleştirilebilir vektörel ikon seti.
- **Tasarım Dili:** **Vanilla CSS3**. Modern CSS özellikleri (Flexbox, Grid, CSS Variables, Backdrop-filter, Keyframes) kullanılarak premium bir estetik oluşturulmuştur.
- **Mobil Strateji:** **PWA (Progressive Web App)**. Web uygulamasının çevrimdışı çalışma (Service Workers), ana ekrana ekleme (Manifest) ve uygulama benzeri bir deneyim sunması sağlanmıştır.

### **1.2. Backend: Ölçeklenebilir ve Güvenli Servis Katmanı**
- **Dil:** **TypeScript**. Statik tipleme sayesinde büyük kod bloklarında hata payı minimize edilmiştir.
- **Çalışma Ortamı:** **Node.js**. Olay döngüsü (Event Loop) mimarisi ile eşzamanlı istekler verimli şekilde işlenir.
- **Framework:** **Express.js**. Middleware mimarisi ile API yönetimi, hata yakalama ve güvenlik katmanları yapılandırılmıştır.
- **ORM (Object-Relational Mapping):** **Prisma**. SQL sorgularını tip güvenli hale getirerek veritabanı yönetimini otomatikleştirir.
- **Güvenlik:** JWT tabanlı kimlik doğrulama ve veri şifreleme süreçleri.

### **1.3. Veritabanı ve Depolama Katmanı**
- **Motor:** **PostgreSQL**. Endüstriyel veriler için yüksek tutarlılık (ACID uyumluluğu) sunan ilişkisel veritabanı.
- **Veri Tipi Çeşitliliği:** JSONB (Esnek makine özellikleri için), Decimal (Hassas maliyet hesapları için) ve Timestamptz (Zaman dilimi duyarlı kayıtlar için).

---

## 2. Derinlemesine Modül Analizi ve Uygulanan Yöntemler

### **2.1. Akıllı Bakım Yönetimi (`Bakim.jsx`)**
Bu modül, tesisin operasyonel sürekliliğini sağlayan "komuta merkezi"dir.

- **Yöntem - Dinamik Takvim Matrisi:** JavaScript'te `new Date(y, m, 0).getDate()` fonksiyonu ile ayın gün sayısı dinamik olarak bulunur. `getDay()` ile haftanın başlangıç günü saptanarak 7 sütunluk bir `Grid` yapısı oluşturulur. Boş günler `null` ile doldurulur.
- **Yöntem - Modüler Bakım Takibi:** Makine çalışma saati üzerinden periyodik bakım hesabı:
  `kalan_saat = periyodik_limit - (toplam_saat % periyodik_limit)`. 
  Bu matematiksel model, her bakım sonrası sayacın manuel sıfırlanmasına gerek kalmadan döngüsel olarak çalışmasını sağlar.
- **UI Tekniği - No-Scroll Dashboard:** Veri yoğunluğunu yönetmek için `padding` ve `font-size` değerleri `rem` ve `px` bazlı mikro-ayarlara tabi tutulmuştur. Amaç, tüm kritik verilerin (Sayaçlar, Takvim, Maliyetler) dikey kaydırma çubuğu olmadan tek bir "Dashboard" ekranına sığdırılmasıdır.

### **2.2. Varlık ve Enformasyon Yönetimi (`Makineler.jsx`)**
Fabrikadaki tüm fiziksel varlıkların dijital kimliklerini yönetir.

- **Yöntem - QR Tabanlı Varlık Tanımlama:** `qrcode.react` kütüphanesi kullanılarak her makine için benzersiz bir `URL` üretilir. Bu URL, makinenin fiziksel üzerine yapıştırılan QR kod ile eşleşir. Taratıldığında `/checklist-giris/:qrId` rotasına yönlendirerek operatöre doğrudan ilgili formu açar.
- **Yöntem - Çoklu Kayıt İşleme:** Kullanıcı seri numaralarını virgülle ayırdığında, frontend tarafında `split(',').map(s => s.trim())` yöntemiyle diziye dönüştürülür ve bir `for...of` döngüsü içinde API'ye seri istekler gönderilerek toplu makine ekleme simüle edilir.

### **2.3. Dijital İkiz (Digital Twin) ve Haritalama (`Dashboard.jsx`)**
Fiziksel fabrikanın dijital izdüşümüdür.

- **Yöntem - Koordinat Eşleştirme:** Fabrika kat planı (PNG/SVG) bir `container` olarak tanımlanır. Makineler, veritabanındaki `x_koor` ve `y_koor` değerlerine göre `top` ve `left` yüzdelik (%) değerleri kullanılarak haritaya yerleştirilir. Bu sayede ekran çözünürlüğü değişse bile makinelerin harita üzerindeki göreceli konumları sabit kalır.
- **Yöntem - Anlık Durum Görselleştirme:** Makine ikonları, API'den gelen `aktiflik_durumu` bilgisine göre anlık renk değiştirir (Yeşil: Çalışıyor, Turuncu: Bakımda, Kırmızı: Arızalı).

### **2.4. AI Destekli Risk Analizi (`MakineDetay.jsx`)**
Veriye dayalı tahminleme katmanıdır.

- **Algoritmik Yaklaşım:** `risk_skoru` sadece bir sayı değil; son 3 günlük checklist cevapları, makinenin yaşı ve arıza sıklığının ağırlıklı ortalamasıdır. 
  - `Eğer (Yağ Sızıntısı == EVET) => Risk +30`
  - `Eğer (Garanti Süresi < 1 Ay) => Risk +10`
- **Uygulama:** Bu mantık backend tarafında (`bakimKontrol.ts`) hesaplanır ve frontend tarafında `keyframe` animasyonları (Yanıp sönen uyarı ışıkları) ile görselleştirilir.

---

## 3. Yazılım Mühendisliği Prensipleri ve Standartlar

### **3.1. API İletişim Standartları (`api.js`)**
- **Fetch API Wrapper:** Tüm istekler merkezi bir `api` objesi üzerinden yönetilir. Hata yakalama (Error Handling) ve `localStorage` üzerinden kullanıcı yetki kontrolü (Authorization) burada yapılır.
- **RESTful Design:** Kaynaklara erişim standart metodlarla (GET, POST, PUT, DELETE) sağlanır.

### **3.2. Stil ve Estetik Mühendisliği (`index.css`)**
- **Glassmorphism:** `backdrop-filter: blur(10px)` ve `rgba` renkler kullanılarak modern, derinlik algısı olan bir tasarım oluşturulmuştur.
- **Renk Teorisi:** Projede `#1a1a2e` (Gece Mavisi), `#e94560` (Vurgu Kırmızısı) ve `#2ecc71` (Güven Yeşili) gibi kontrastı yüksek, endüstriyel ciddiyete uygun bir palet seçilmiştir.

### **3.3. Güvenlik ve Kararlılık**
- **Input Sanitization:** Makine isimleri ve diğer girişler regex (`/[^A-Z...]/g`) ile temizlenerek SQL Injection ve XSS saldırılarına karşı önlem alınmıştır.
- **Responsive Design:** `@media` sorguları ile sistemin hem 27 inç endüstriyel monitörlerde hem de 6 inç teknisyen tabletlerinde kusursuz çalışması sağlanmıştır.

---

## 4. Gelecek ve Ölçeklenebilirlik
Maintify mimarisi, gelecekte eklenecek olan **IoT Sensör Verileri** entegrasyonu için hazırdır. Mevcut `JSONB` özellik alanı sayesinde, yeni sensör tipleri (Sıcaklık, Titreşim vb.) veritabanı şemasını değiştirmeden sisteme dahil edilebilir.

---
> **Dokümantasyon Sürümü:** 3.0 (Kapsamlı Mimari Rapor)
> **Hazırlayan:** Antigravity AI
> **Tarih:** 13 Mayıs 2026
