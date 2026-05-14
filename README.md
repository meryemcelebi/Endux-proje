# Maintify — Yapay Zeka Destekli Toplam Verimlilik Bakımı (TPM) Yönetim Sistemi

📎 **GitHub Deposu:** [github.com/meryemcelebi/Endux-proje](https://github.com/meryemcelebi/Endux-proje)


## Proje Hakkında

**Maintify**, endüstriyel tesislerdeki makinelerin bakım süreçlerini uçtan uca yönetmek amacıyla geliştirilmiş bir web tabanlı uygulamadır. Toplam Verimlilik Bakımı (TPM) felsefesini temel alarak, makine arızalarının önceden tahmin edilmesini, bakım maliyetlerinin analiz edilmesini ve genel ekipman verimliliğinin (OEE) ölçülmesini sağlar.

Sistem, **XGBoost** tabanlı makine öğrenmesi modelleri ile operatörlerin günlük kontrol formlarından elde edilen verileri analiz eder; risk skoru hesaplayarak olası arızaları proaktif biçimde tespit eder ve bakım planlamasını optimize eder.

Veritabanı altyapısı **Supabase** bulut platformu üzerinde barındırılmaktadır.

---

## Teknoloji Yığını

| Katman | Teknoloji | Açıklama |
|---|---|---|
| **Frontend** | React 18, Vite 7, Recharts | Tek sayfa uygulaması (SPA), grafikler ve veri görselleştirme |
| **Backend** | Node.js, Express 4 | RESTful API sunucusu |
| **Veritabanı** | PostgreSQL 16, Supabase | İlişkisel veritabanı yönetim sistemi ve bulut altyapısı |
| **ORM** | Prisma 7 | Tip güvenli veritabanı erişim katmanı |
| **Yapay Zeka** | Python 3, FastAPI, XGBoost, scikit-learn | Risk tahmini ve arıza tespiti modelleri |
| **Kimlik Doğrulama** | JWT (JSON Web Token) | Rol tabanlı erişim kontrolü (RBAC) |

---

## Sistem Mimarisi

```
┌──────────────────┐       ┌──────────────────┐       ┌──────────────────┐
│                  │       │                  │       │                  │
│   React Client   │──────▶│  Node.js / API   │──────▶│   PostgreSQL     │
│   (Vite:5173)    │  HTTP │  (Express:3000)  │Prisma │   (Supabase)     │
│                  │◀──────│                  │◀──────│                  │
└──────────────────┘       └────────┬─────────┘       └──────────────────┘
                                    │
                                    │ HTTP
                                    ▼
                           ┌──────────────────┐
                           │   AI Servisi      │
                           │  (FastAPI:8000)   │
                           │  XGBoost Modeli   │
                           └──────────────────┘
```

---

## Modüller ve Özellikler

### 1. Makine Yönetimi
- Makine ekleme, güncelleme ve durum takibi
- QR kod tabanlı makine kimlik doğrulama
- Teknik özellik yönetimi (kapasite, güç tüketimi, RPM vb.)
- Lokasyon ve kat bazlı fabrika haritası

### 2. Bakım Yönetimi
- Bakım kaydı oluşturma (koruyucu, düzeltici, acil)
- Servis firma atama
- Bakım onay akışı (Bekleyen → Onaylandı → Tamamlandı)
- QR okutarak sahada bakım tamamlama
- Parça değişim kaydı ve stok güncelleme

### 3. Günlük Kontrol (Checklist)
- Makine türüne özel dinamik kontrol şablonları
- Operatör tarafından günlük form doldurma
- AI modülüne otomatik veri aktarımı ve risk analizi

### 4. Yapay Zeka Modülü
- XGBoost tabanlı arıza risk tahmini
- Makine türüne özel eğitilmiş modeller (CNC, Enjeksiyon, Pres)
- Gerçek zamanlı risk skoru hesaplama
- Otonom model yeniden eğitim mekanizması

### 5. OEE (Genel Ekipman Verimliliği)
- Kullanılabilirlik, performans ve kalite oranı hesaplama
- Makine bazlı ve fabrika geneli OEE raporları
- Vardiya bazlı üretim ve duruş kaydı takibi
- Haftalık OEE trend analizi

### 6. Maliyet Analizi
- Makine bazlı toplam bakım maliyeti hesaplama
- Duruş maliyeti analizi (makine türüne göre saatlik maliyet)
- Parça ve servis maliyet dağılımı
- Dashboard üzerinden finansal özet görselleştirme

### 7. Tedarik Zinciri
- Tedarikçi ve servis firma yönetimi
- Satın alma kayıtları ve stok takibi
- Firma puanlama ve güvenilirlik skoru
- Parça kategorizasyonu

### 8. Kullanıcı ve Yetkilendirme
- Rol tabanlı erişim (Yönetici, Teknisyen, Operatör)
- JWT ile güvenli kimlik doğrulama
- Servis teknisyeni PIN girişi (QR + telefon)

---

## Kurulum Adımları

### Ön Gereksinimler

- [Node.js](https://nodejs.org/) (v18 veya üzeri)

- [Python 3.10+](https://www.python.org/) (AI servisi için)
- [Git](https://git-scm.com/)

### 1. Depoyu Klonlayınız

```bash
git clone https://github.com/meryemcelebi/Endux-proje.git
cd Endux-proje
```

### 2. Ortam Değişkenlerini Yapılandırınız

Kök dizindeki `.env.example` dosyasını `.env` olarak kopyalayınız ve gerekli bilgileri doldurunuz:

```bash
cp .env.example .env
```

### 4. Backend Bağımlılıklarını Yükleyiniz

```bash
cd node-service
npm install
npx prisma generate
npm run dev
```

### 5. Frontend Bağımlılıklarını Yükleyiniz

```bash
cd web-client
npm install
npm run dev
```

### 6. AI Servisini Başlatınız (İsteğe Bağlı)

```bash
cd ai-services
pip install -r requirements.txt
uvicorn api:app --host 0.0.0.0 --port 8000
```

## Ortam Değişkenleri

| Değişken | Açıklama | Örnek Değer |
|---|---|---|
| `DATABASE_URL` | Supabase PostgreSQL bağlantı URL'si (pooler) | `postgresql://postgres.[ref]:pass@...pooler.supabase.com:6543/postgres` |
| `DIRECT_URL` | Supabase doğrudan bağlantı URL'si | `postgresql://postgres.[ref]:pass@...pooler.supabase.com:5432/postgres` |
| `SUPABASE_URL` | Supabase proje URL'si | `https://xxxxx.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase anonim API anahtarı | `eyJhbGci...` |
| `JWT_SECRET` | Token imzalama anahtarı | `endux_jwt` |
| `JWT_EXPIRES_IN` | Token geçerlilik süresi | `7d` |
| `AI_SERVICE_URL` | AI servis adresi | `http://localhost:8000` |
| `PORT` | Backend sunucu portu | `3000` |

---

## Proje Dizin Yapısı

```
Endux-proje/
├── node-service/                # Backend API
│   ├── src/
│   │   ├── controllers/         # İş mantığı katmanı (14 kontrolcü)
│   │   ├── routes/              # API rota tanımları
│   │   ├── middlewares/         # Kimlik doğrulama ve yetkilendirme
│   │   ├── services/            # Harici servis entegrasyonları
│   │   ├── config/              # Yapılandırma dosyaları
│   │   ├── app.ts               # Express uygulama yapılandırması
│   │   └── index.ts             # Sunucu giriş noktası
│   └── prisma/
│       ├── schema.prisma        # Veritabanı şema tanımı (35+ model)
│       └── seed.ts              # Başlangıç verileri
│
├── web-client/                  # Frontend SPA
│   ├── src/
│   │   ├── services/api.js      # Merkezi API iletişim katmanı
│   │   ├── Dashboard.jsx        # Ana kontrol paneli
│   │   ├── Makineler.jsx        # Makine listesi ve yönetimi
│   │   ├── MakineDetay.jsx      # Makine detay ve risk analizi
│   │   ├── Bakim.jsx            # Bakım kayıt modülü
│   │   ├── Checklist.jsx        # Günlük kontrol formu
│   │   ├── SatinAlma.jsx        # Satın alma ve stok yönetimi
│   │   ├── TedarikciListesi.jsx # Firma ve tedarikçi yönetimi
│   │   ├── ServisMerkezi.jsx    # QR bazlı servis teknisyen paneli
│   │   └── SistemAyarlari.jsx   # Vardiya ve maliyet ayarları
│   └── vite.config.js           # Vite yapılandırması ve proxy ayarları
│
├── ai-services/                 # Yapay Zeka Servisi
│   ├── api.py                   # FastAPI uç noktaları
│   ├── database.py              # Veritabanı bağlantısı
│   ├── models/                  # Eğitilmiş XGBoost modelleri
│   └── requirements.txt         # Python bağımlılıkları
│
├── db-init/
│   └── init.sql                 # Veritabanı başlangıç şeması ve tetikleyiciler
│
└── .env.example                 # Ortam değişkenleri şablonu
```

---

## API Endpoint Tablosu

| Metot | Endpoint | Açıklama |
|---|---|---|
| `POST` | `/api/auth/login` | Kullanıcı girişi |
| `POST` | `/api/auth/servis-giris` | Servis teknisyeni PIN girişi |
| `GET` | `/api/makineler` | Tüm makineleri listeleme |
| `GET` | `/api/makineler/:id` | Makine detay bilgisi |
| `POST` | `/api/makineler` | Yeni makine ekleme |
| `PATCH` | `/api/makineler/:id/durum` | Makine durum güncelleme |
| `GET` | `/api/makineler/qr/:qr_uuid` | QR ile makine sorgulama |
| `GET` | `/api/bakimlar/:makine_id` | Makine bakım geçmişi |
| `POST` | `/api/bakimlar` | Yeni bakım kaydı oluşturma |
| `PATCH` | `/api/bakimlar/:id/onayla` | Bakım onaylama |
| `POST` | `/api/bakimlar/qr-tamamla` | QR ile bakım tamamlama |
| `POST` | `/api/bakimlar/acil-bildir` | Acil bakım bildirimi |
| `GET` | `/api/bakimlar/onay-bekleyenler` | Onay bekleyen bakımlar |
| `GET` | `/api/bakimlar/teknik-servis` | Teknik servis görev listesi |
| `GET` | `/api/checklist/sablon/:id` | Kontrol şablonu sorgulama |
| `POST` | `/api/checklist/form` | Günlük kontrol formu gönderme |
| `GET` | `/api/oee/toplu` | Fabrika geneli OEE raporu |
| `GET` | `/api/oee/:id` | Makine bazlı OEE detayı |
| `GET` | `/api/dashboard/ozet` | Dashboard özet verileri |
| `GET/POST` | `/api/satin-alma` | Satın alma işlemleri |
| `GET` | `/api/satin-alma/stok` | Stok durumu sorgulama |
| `GET/POST` | `/api/tedarikciler` | Tedarikçi yönetimi |
| `GET/POST` | `/api/servis-firmalari` | Servis firma yönetimi |
| `POST` | `/api/servis-puan` | Servis firma puanlama |
| `POST` | `/api/tedarikci-puan` | Tedarikçi puanlama |
| `GET/POST` | `/api/kullanicilar` | Kullanıcı yönetimi |
| `GET` | `/api/sistem/firmalar` | Sistem firma listesi |
| `GET` | `/api/sistem/roller` | Rol listesi |
| `GET` | `/api/sistem/makine-turleri` | Makine türleri listesi |
| `GET/POST` | `/api/sistem/vardiya-saatleri` | Vardiya saatleri yönetimi |

---

## Veritabanı Şeması

Sistem, **35'ten fazla tablo** içeren ilişkisel bir veritabanı yapısı üzerine kuruludur. Temel tablolar şunlardır:

| Tablo | Açıklama |
|---|---|
| `makine` | Makine envanteri, seri no, garanti ve QR bilgileri |
| `makine_turu` | Makine türleri, risk katsayısı ve periyodik bakım saati |
| `makine_ozellikleri` | Teknik özellikler (JSON formatında) |
| `bakim_kaydi` | Bakım işlem kayıtları, maliyet ve durum takibi |
| `bakim_turu` | Bakım türleri (koruyucu, düzeltici, acil) |
| `gunluk_kontrol_formu` | Operatör günlük kontrol formları |
| `kontrol_sablonu` | Makine türüne özel kontrol şablonları |
| `kontrol_maddesi` | Şablon kontrol maddeleri ve teknik parametreler |
| `risk_skoru` | Makine risk değerlendirme sonuçları |
| `ai_ariza_tespit` | AI arıza tahmin sonuçları |
| `ariza_kaydi` | Arıza kayıtları ve tetikleyici form bağlantıları |
| `oee_raporlari` | OEE skor geçmişi (kullanılabilirlik, performans, kalite) |
| `uretim_kaydi` | Vardiya bazlı üretim verileri |
| `durus_kaydi` | Makine duruş süreleri ve nedenleri |
| `parca` | Yedek parça envanteri ve stok seviyeleri |
| `parca_degisim` | Bakımda değişen parça kayıtları |
| `servis_firma` | Dış servis firma bilgileri |
| `tedarikci` | Tedarikçi bilgileri ve güvenilirlik skoru |
| `kullanici` | Sistem kullanıcıları ve roller |

---

## Teslim Öncesi Kontrol Listesi

### Veritabanı Doğrulaması
- [x] Supabase üzerindeki tüm tabloların ve ilişkilerin çalıştığı doğrulanmıştır
- [x] Veritabanı tetikleyicileri (triggers) ve görünümleri (views) senkronize edilmiştir
- [x] `init.sql` dosyası ile sıfırdan veritabanı oluşturulabilirliği test edilmiştir
- [x] Prisma şeması ile veritabanı arasında tutarlılık sağlanmıştır

### Modül Testleri
- [x] Makine CRUD işlemleri (ekleme, listeleme, detay, durum güncelleme) test edilmiştir
- [x] QR kod üretimi ve okutma akışı doğrulanmıştır
- [x] Bakım kaydı oluşturma ve onay akışı (Bekleyen → Onaylandı → Tamamlandı) test edilmiştir
- [x] Günlük kontrol formu doldurma ve AI risk analizi entegrasyonu doğrulanmıştır
- [x] OEE hesaplama algoritması (kullanılabilirlik × performans × kalite) test edilmiştir
- [x] Satın alma ve stok güncelleme işlemleri doğrulanmıştır
- [x] Tedarikçi ve servis firma puanlama sistemi test edilmiştir
- [x] Kullanıcı kimlik doğrulama ve rol tabanlı erişim kontrolü test edilmiştir
- [x] Servis teknisyeni PIN girişi ve QR bazlı bakım tamamlama akışı doğrulanmıştır
- [x] Dashboard maliyet analizi ve grafik görselleştirmeleri test edilmiştir

### Sistem Bütünlüğü
- [x] Kiralama modülü tamamen kaldırılmış, sistem TPM/OEE odaklı hale getirilmiştir
- [x] Frontend-Backend API entegrasyon testleri tamamlanmıştır
- [x] Supabase bulut veritabanına başarılı geçiş yapılmıştır
- [x] Hata yönetimi ve kullanıcıya anlamlı hata mesajları döndürülmesi test edilmiştir

---

## Geliştirme Ekibi

| İsim | Rol |
|---|---|
| **Meryem Çelebi** | Backend Geliştiricisi |
| **İlker Şen** | AI Geliştiricisi |
| **Hüsniye Gül Ödük** |Frontend Geliştirici |
| **Canan Kılıç** |Veritabanı Geliştirici |

---

*Bu proje, 12 haftalık bir geliştirme süreci sonucunda bitirme projesi kapsamında hazırlanmıştır.*
