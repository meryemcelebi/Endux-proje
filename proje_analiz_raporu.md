# 📊 Endux TPM Projesi – Kapsamlı Analiz Raporu

> Bu rapor, `proje_konusu_revize.md` dosyasının detaylı incelenmesi ve `endux` klasörünün tamamının taranması sonucu hazırlanmıştır.

---

## 📁 Bölüm 1: Mevcut Proje Yapısı Özeti

İncelenen klasör yapısı:

```
endux/
├── ai-services/          ← Python FastAPI (XGBoost modellerle arıza tahmini)
│   ├── main.py           ← /predict ve /health endpoint'leri
│   ├── xgboost_ariza_modeli.pkl
│   └── xgboost_regresyon_modelleri.pkl
├── node-service/         ← Node.js + Express + Prisma backend
│   ├── prisma/schema.prisma   ← 17 model, 1 enum
│   └── src/
│       ├── controllers/  ← 7 controller (oturum, makine, bakim, checklist, analiz, kullanici, sistem)
│       ├── routes/       ← 7 route dosyası
│       ├── middlewares/  ← 1 dosya (yetki.ts – JWT + RBAC)
│       ├── interfaces/   ← 1 dosya (makine.types.ts)
│       └── utils/        ← hash.ts, jwt.ts, turkceKarakter.ts
├── web-client/           ← React (Vite) frontend
│   └── src/
│       ├── App.jsx       ← 8 route: Login, Dashboard, Checklist, Makineler, Servis…
│       ├── components/   ← MakineEkle.jsx, QRCodeOlustur.jsx
│       └── pages/        ← (boş klasör)
├── db-init/init.sql      ← ~92KB başlangıç SQL seed dosyası
├── docker-compose.yml    ← 4 servis: PostgreSQL, Backend, Frontend, AI
└── proje_konusu_revize.md
```

---

## 🔍 Bölüm 2: Projenin Eksik Yanları Analizi

Aşağıda, `proje_konusu_revize.md`'de tanımlanan hedefler ile mevcut kod tabanı arasındaki farklar (gap analysis) 9 ana kategoride sunulmuştur.

---

### 2.1 🔴 Prisma Şemasındaki Array Hataları (KRİTİK)

`schema.prisma` dosyasında birçok alan, tekil (scalar) olması gerekirken **dizi (array)** olarak tanımlanmış durumda. Bu, veri bütünlüğünü tamamen bozar ve AI'a veri beslemeyi imkânsız kılar.

| Model | Hatalı Alan | Mevcut Tip | Olması Gereken |
|-------|-------------|-----------|----------------|
| `makine` | `seri_no` | `String[]` | `String` |
| `makine` | `top_cal_sma_saati` | `Decimal[]` | `Decimal` |
| `makine` | `makine_ozellikleri` | `Json[]` | `Json` |
| `firma` | `firma_adi` | `String[]` | `String` |
| `firma` | `vergi_no` | `String[]` | `String` |
| `firma` | `sektor` | `String[]` | `String` |
| `firma` | `abonelik_tipi` | `String[]` | `String` |
| `firma` | `aktif_mi` | `Boolean[]` | `Boolean` |
| `servis_firma` | `firma_adi` | `String[]` | `String` |
| `servis_firma` | `telefon` | `Int[]` | `String` (telefon numara formatı) |
| `servis_firma` | `email` | `String[]` | `String` |
| `servis_firma` | `adres` | `String[]` | `String` |
| `bakim_kaydi` | `bakim_turu` | `String[]` | `String` |
| `bakim_kaydi` | `bakim_tarihi` | `DateTime[]` | `DateTime` |
| `bakim_kaydi` | `bakim_maliyet` | `Decimal[]` | `Decimal` |
| `ariza_kaydi` | `baslangic_zamani` | `DateTime[]` | `DateTime` |
| `ariza_kaydi` | `bitis_zamani` | `DateTime[]` | `DateTime` |
| `ariza_kaydi` | `durus_suresi` | `Decimal[]` | `Decimal` |
| `kontrol_sablonu` | `sablon_adi` | `String[]` | `String` |
| `kontrol_maddesi` | `madde_adi`, `teknik_parametre`, `veri_tipi`, `birim` | Hepsi `String[]` | Tekil `String` |
| `risk_skoru` | `risk_skoru` | `Decimal[]` | `Decimal` |
| `ai_model_log` | `model_versiyon`, `kullanilan_veri_sayisi`, `tahmin_risk` | Hepsi dizi | Tekil değerler |

**Etki:** Controller'larda `.map(Number)`, `Array.isArray()` gibi workaround'lar zaten mevcut — bu, şema hatasının belirtisi.

---

### 2.2 🟠 Lokasyon Modeli Yetersiz

Mevcut `lokasyon` tablosu şöyle tanımlı:
```
lokasyon_id, makine_id (FK), fabrika_alani[], kat[], x_koor[], y_koor[], guncelleme_tarihi
```

**Sorunlar:**
- `fabrika_alani` ve `kat` dizi olarak tanımlı — tekil olmalı
- Lokasyon, proje dokümanında bağımsız bir **obje** olarak tutulması isteniyor, ancak mevcut yapı makineye bağlı pasif bir kayıt
- Lokasyona ait ad, açıklama, kapasite gibi meta-veriler yok
- Yöneticinin "lokasyon üzerinden makinelere tıklayarak detay görmesi" için lokasyon bazlı makine listeleme endpoint'i yok

---

### 2.3 🟠 Servis Firması Yapısı Eksik

Mevcut `servis_firma` tablosu:
```
servis_firma_id, firma_adi[], telefon[], email[], adres[], aktiflik
```

**Sorunlar:**
- Array hataları (yukarıda belirtildi)
- **Yetkili kişi bilgisi yok** — Dışarıdan gelen servis firma **sorumlusu** (isim, unvan, telefon) tutulmuyor
- **Puanlama alanı yok** — Proje dokümanında "dış servis firmaları puanlanır" deniyor ama şemada `puan` veya `rating` alanı yok
- **Uzmanlık alanı yok** — Hangi tip bakımlarda uzman olduğu belirtilmiyor
- Servis firmasına özel CRUD endpoint'i yok (controller yok)

---

### 2.4 🟠 Tedarikçi Puanlama Sistemi Yok

Mevcut `tedarikci` tablosu:
```
tedarikci_id, firma_adi, telefon, email, adres, aktiflik
```

**Sorunlar:**
- `puan` / `guvenilirlik_skoru` alanı yok
- "Aynı tedarikçiden gelen bir parça 3 kez arızalanırsa uyarı verilir" iş kuralı için hiçbir mekanizma yok:
  - Parça arıza sayacı yok
  - Otomatik uyarı/alert sistemi yok
  - `parca_degisim` tablosundan geriye dönük analiz yapan servis yok
- Tedarikçi CRUD endpoint'i yok

---

### 2.5 🔴 Garanti Yönetimi Tamamen Eksik

Proje dokümanında açıkça belirtiliyor:
> "Yeni makineler garanti kapsamında sisteme tanımlanır. Garanti süresi yıl bazlı tutulur. Garanti kapsamındaki makinelerin bakımları yalnızca servis firması tarafından yapılır."

**Mevcut durumda:**
- `makine` tablosunda `garanti_bitis_tarihi` veya `garanti_suresi_yil` alanı **yok**
- Garanti durumuna göre bakım kısıtlaması (sadece servis firması yapabilir) logic'i **yok**
- Frontend'de garanti rozeti/badge **yok**
- Garanti bitiş uyarısı **yok**

---

### 2.6 🟡 Backend – AI Entegrasyonu Kopuk

- AI servisi (`FastAPI /predict`) çalışıyor ve `makine_id` + `form_id` dönüyor
- **AMA** Node.js backend'inde AI servisini çağıran bir endpoint veya servis **yok**
  - `axios` bağımlılığı kurulu ama hiçbir controller'da kullanılmıyor
  - `ai_ariza_tespit` ve `ai_model_log` tablolarına veri yazan hiçbir fonksiyon yok
- **Feedback Loop yok:** Teknisyenin kapattığı arıza kaydı AI'a geri bildirim olarak iletilmiyor

---

### 2.7 🟡 Cron/Worker Mekanizması Yok

Proje dokümanında periyodik bakım planlarından bahsediliyor, ancak:
- `node-cron`, `BullMQ` veya benzeri bir kuyruk/zamanlayıcı kütüphanesi **kurulu değil**
- Arka planda çalışma saatlerini kontrol edip bakım uyarısı oluşturan bir mekanizma yok
- Tüm sistem tamamen **pasif** (sadece HTTP request ile tetikleniyor)

---

### 2.8 🟡 Frontend Eksikleri

| Beklenen Ekran | Mevcut Durum |
|----------------|-------------|
| Lokasyon haritası / görsel layout | ❌ Yok |
| Tedarikçi yönetim ekranı | ❌ Yok |
| Servis firma yönetim ekranı | ❌ Yok |
| Puanlama (yıldız) bileşeni | ❌ Yok |
| Garanti durumu rozeti | ❌ Yok |
| Maliyet analizi dashboard (Kırmızı/Sarı/Yeşil) | ❌ Backend var ama frontend karşılığı yok |
| Risk haritası | ❌ Yok |
| AI tahmin sonuçları ekranı | ❌ Yok |
| Offline Mode (PWA) | ❌ Yok |
| `pages/` klasörü | Boş |

---

### 2.9 🟡 Test & Dokümantasyon

- Hiçbir **unit test** veya **integration test** dosyası yok
- Swagger/OpenAPI spec yok
- ER diyagramı yok
- `analizKontrol.ts`'de JSON key'lerinde `succes` yazım hatası var (`success` olmalı)

---

## ✅ Bölüm 3: Beş Sorunun Cevapları

---

### Soru 1: Lokasyon sistemde obje olarak tutulacaktır. Bu yapı nasıl modellenmelidir?

Mevcut yapıda lokasyon makineye bire-bir bağlı pasif bir kayıt olarak tanımlı. Bunun yerine lokasyon, **bağımsız bir varlık (entity)** olarak tanımlanmalı ve makineler lokasyona bağlanmalıdır.

**Önerilen Prisma Modeli:**

```prisma
model lokasyon {
  lokasyon_id       Int       @id @default(autoincrement())
  lokasyon_adi      String    @db.VarChar(100)      // "A Üretim Hattı", "B Montaj Alanı"
  fabrika_alani     String    @db.VarChar(100)      // "Ana Fabrika", "Depo-2"
  kat               String?   @db.VarChar(20)       // "Zemin Kat", "1. Kat"
  aciklama          String?                          // Serbest metin açıklama
  x_koordinat       Decimal?  @db.Decimal(10, 6)    // Opsiyonel harita koordinatı
  y_koordinat       Decimal?  @db.Decimal(10, 6)
  aktif_mi          Boolean   @default(true)
  olusturma_tarihi  DateTime  @default(now())
  guncelleme_tarihi DateTime  @updatedAt

  // İlişki: bir lokasyonda birden fazla makine olabilir
  makineler         makine[]
}

// makine tablosunda:
model makine {
  // ... mevcut alanlar ...
  lokasyon_id       Int?
  lokasyon          lokasyon?  @relation(fields: [lokasyon_id], references: [lokasyon_id])
}
```

**Gerekçe:**
- Lokasyon artık bağımsız bir obje → Yönetici "Lokasyonlar" sayfasından tüm alanları görebilir
- Bir lokasyona tıklandığında o lokasyondaki tüm makineler listelenir (`makine` tablosunda `lokasyon_id` FK)
- Gelecekte fabrika haritası çizildiğinde `x_koordinat` ve `y_koordinat` ile makine pin'leri konumlandırılabilir

**Gerekli API Endpoint'leri:**
- `GET /api/lokasyonlar` → Tüm lokasyonları listele
- `GET /api/lokasyonlar/:id` → Bir lokasyonun detayı + makineleri
- `POST /api/lokasyonlar` → Yeni lokasyon oluştur (Yönetici)
- `PUT /api/lokasyonlar/:id` → Lokasyon güncelle
- `DELETE /api/lokasyonlar/:id` → Lokasyon sil (soft-delete)

---

### Soru 2: Dışarıdan gelen servis firma sorumlusu sistemde nasıl tutulmalıdır?

Mevcut `servis_firma` tablosu sadece firma bilgilerini tutuyor. Firmaya bağlı **sorumlu kişi** bilgisi eksik. İki yaklaşım mümkün:

**Önerilen Model (Ayrı Tablo – Daha Esnek):**

```prisma
model servis_firma {
  servis_firma_id   Int                @id @default(autoincrement())
  firma_adi         String             @db.VarChar(100)
  telefon           String             @db.VarChar(20)
  email             String?            @db.VarChar(100)
  adres             String             @db.VarChar(200)
  uzmanlik_alani    String?            @db.VarChar(150)    // "CNC Bakım", "Hidrolik Sistemler"
  aktiflik          Boolean            @default(true)
  ortalama_puan     Decimal?           @db.Decimal(3, 2)   // 0.00 – 5.00

  // İlişkiler
  sorumlular        servis_sorumlusu[]
  bakim_kaydi       bakim_kaydi[]
  puanlar           servis_puan[]
}

model servis_sorumlusu {
  sorumlu_id        Int            @id @default(autoincrement())
  servis_firma_id   Int
  ad                String         @db.VarChar(50)
  soyad             String         @db.VarChar(50)
  unvan             String?        @db.VarChar(50)       // "Baş Teknisyen", "Saha Mühendisi"
  telefon           String         @db.VarChar(20)
  email             String?        @db.VarChar(100)
  aktif_mi          Boolean        @default(true)

  servis_firma      servis_firma   @relation(fields: [servis_firma_id], references: [servis_firma_id])
}
```

**Gerekçe:**
- Bir servis firmasının birden fazla sorumlusu olabilir (firma A'dan Ahmet Usta gelir, bazen Veli Usta gelir)
- Bakım kaydında hangi sorumlunun geldiği de izlenebilir
- Sorumlu kişi, sisteme login olmaz (kullanıcı değildir) — sadece iletişim ve kayıt amacıyla tutulur
- `unvan` alanı ile teknisyen/mühendis ayrımı yapılabilir

---

### Soru 3: Servis ve tedarikçiler için puanlama sistemi nasıl kurgulanmalıdır?

Her iki varlık için de **ortak bir puanlama yapısı** tasarlanabilir. Polimorfik (entity_type) yaklaşım yerine, her biri için ayrı puanlama tablosu daha netir:

**Önerilen Model:**

```prisma
model servis_puan {
  puan_id           Int            @id @default(autoincrement())
  servis_firma_id   Int
  puanlayan_id      Int            // Puanı veren kullanıcı (yönetici/teknisyen)
  puan              Int            // 1-5 arası (CHECK constraint ile)
  yorum             String?
  tarih             DateTime       @default(now())

  servis_firma      servis_firma   @relation(fields: [servis_firma_id], references: [servis_firma_id])
  puanlayan         kullanici      @relation(fields: [puanlayan_id], references: [kullanici_id])
}

model tedarikci_puan {
  puan_id           Int            @id @default(autoincrement())
  tedarikci_id      Int
  puanlayan_id      Int
  puan              Int            // 1-5 arası
  yorum             String?
  tarih             DateTime       @default(now())

  tedarikci         tedarikci      @relation(fields: [tedarikci_id], references: [tedarikci_id])
  puanlayan         kullanici      @relation(fields: [puanlayan_id], references: [kullanici_id])
}
```

**Puanlama İş Akışı:**
1. Her bakım kaydı kapandığında, yönetici veya teknisyen servis firmasını 1-5 arası puanlar
2. Her parça değişimi sonrası tedarikçi puanlanır
3. Backend'de `ortalama_puan` her yeni giriş sonrası otomatik hesaplanır:
   ```typescript
   // Ortalama puanı güncelle
   const ortPuan = await prisma.servis_puan.aggregate({
     where: { servis_firma_id: firmaId },
     _avg: { puan: true }
   });
   await prisma.servis_firma.update({
     where: { servis_firma_id: firmaId },
     data: { ortalama_puan: ortPuan._avg.puan }
   });
   ```
4. **Tedarikçi alarm kuralı:** "Aynı tedarikçiden gelen parça 3 kez arızalanırsa uyarı" mantığı:
   ```typescript
   const arizaSayisi = await prisma.parca_degisim.count({
     where: {
       tedarikci_id: tedarikciId,
       parca_id: parcaId,
       bakim_kaydi: { ariza_kaydi: { isNot: null } }
     }
   });
   if (arizaSayisi >= 3) {
     // Uyarı oluştur / bildirim gönder
   }
   ```

---

### Soru 4: Tedarikçi yapısı sistemde nasıl modellenmelidir?

Mevcut `tedarikci` tablosu temel düzeyde doğru ama puanlama, kategori ve iletişim detayları eksik.

**Önerilen Genişletilmiş Model:**

```prisma
model tedarikci {
  tedarikci_id          Int               @id @default(autoincrement())
  firma_adi             String            @db.VarChar(100)
  vergi_no              String?           @db.VarChar(30)
  yetkili_kisi          String?           @db.VarChar(100)   // Ana irtibat kişisi
  telefon               String            @db.VarChar(20)
  email                 String?           @db.VarChar(200)
  adres                 String            @db.VarChar(200)
  il                    String?           @db.VarChar(50)
  kategori              String?           @db.VarChar(100)   // "Yedek Parça", "Sarf Malzeme", "Yağ/Akışkan"
  ortalama_puan         Decimal?          @db.Decimal(3, 2)  // 0.00 – 5.00
  guvenilirlik_skoru    Decimal?          @db.Decimal(5, 2)  // 0 – 100 (otomatik hesaplanır)
  aktiflik              Boolean           @default(true)
  kayit_tarihi          DateTime          @default(now())

  parca_degisim         parca_degisim[]
  puanlar               tedarikci_puan[]
}
```

**Güvenilirlik Skoru Hesaplama Mantığı:**
```
guvenilirlik_skoru = 100 - (toplam_ariza_sayisi / toplam_teslimat_sayisi * 100)
```

| Skor Aralığı | Durum |
|-------------|-------|
| 90 – 100 | 🟢 Güvenilir |
| 70 – 89 | 🟡 Dikkat Edilmeli |
| 0 – 69 | 🔴 Riskli Tedarikçi |

**Gerekli API Endpoint'leri:**
- `GET /api/tedarikciler` → Tüm tedarikçileri listele (puanlarıyla birlikte)
- `GET /api/tedarikciler/:id` → Detay + tedarik ettiği parçalar + arıza geçmişi
- `POST /api/tedarikciler` → Yeni tedarikçi ekle
- `PUT /api/tedarikciler/:id` → Güncelle
- `POST /api/tedarikciler/:id/puanla` → Puanlama yap
- `GET /api/tedarikciler/:id/alarm` → 3+ arıza kontrolü

---

### Soru 5: Garanti kapsamındaki makineler sistemde nasıl ayırt edilmelidir?

**Adım 1 – Şema Değişikliği:**

`makine` tablosuna şu alanlar eklenmeli:

```prisma
model makine {
  // ... mevcut alanlar ...
  garanti_suresi_yil    Int?              // Yıl cinsinden garanti süresi (ör: 2)
  garanti_bitis_tarihi  DateTime?  @db.Date  // satin_alma_tarihi + garanti_suresi_yil
  garanti_servis_firma_id Int?             // Garanti kapsamında yetkili servis firması
  garanti_servis_firma  servis_firma?      @relation(fields: [garanti_servis_firma_id], references: [servis_firma_id])
}
```

**Adım 2 – Backend Kontrolü:**

Makine eklenirken garanti bitiş tarihi otomatik hesaplanmalı:
```typescript
const garantiBitisTarihi = new Date(satin_alma_tarihi);
garantiBitisTarihi.setFullYear(garantiBitisTarihi.getFullYear() + garanti_suresi_yil);
```

Bakım kaydı oluşturulurken garanti kontrolü yapılmalı:
```typescript
export async function bakimKaydiGir(req, res) {
  const makine = await prisma.makine.findUnique({ where: { makine_id } });

  const bugun = new Date();
  const garantiAltinda = makine.garanti_bitis_tarihi && bugun <= makine.garanti_bitis_tarihi;

  if (garantiAltinda) {
    // Sadece yetkili servis firması bakım yapabilir
    if (servis_firma_id !== makine.garanti_servis_firma_id) {
      return res.status(403).json({
        success: false,
        message: "Bu makine garanti kapsamındadır. Bakım yalnızca yetkili servis firması tarafından yapılabilir."
      });
    }
    // İç teknisyen bakım yapamaz
    if (req.user.rol === "TEKNISYEN") {
      return res.status(403).json({
        success: false,
        message: "Garanti kapsamındaki makinelere fabrika içi müdahale izni yoktur."
      });
    }
  }
  // ... normal bakım kaydı akışı devam eder
}
```

**Adım 3 – Frontend Gösterimi:**

```
┌────────────────────────────────────┐
│ 🏭 CNC Torna #3                   │
│ Seri No: SN-2024-0451              │
│                                    │
│ ✅ GARANTİ KAPSAMINDA              │  ← Yeşil badge (garanti_bitis > today)
│ Garanti Bitiş: 15.03.2027          │
│ Yetkili Servis: ABC Teknik Ltd.    │
│                                    │
│ [Bakım Talebi Oluştur]            │  ← Sadece servis firmasını seçebilir
└────────────────────────────────────┘

┌────────────────────────────────────┐
│ 🏭 Kompresör #7                    │
│ Seri No: SN-2021-0098              │
│                                    │
│ ❌ GARANTİ DIŞI                    │  ← Kırmızı badge
│ Garanti Bitiş: 01.01.2024 (Dolmuş)│
│                                    │
│ [Bakım Talebi Oluştur]            │  ← İç teknisyen seçilebilir
└────────────────────────────────────┘
```

---

## 📦 Bölüm 4: Özet ve Öncelikli Aksiyon Planı

| Öncelik | Aksiyon | Zorluk | Etki |
|---------|---------|--------|------|
| 🔴 1 | Prisma şemasındaki tüm `Array` hatalarını tekil tiplere düzelt | Orta | Kritik – tüm sistemin temeli |
| 🔴 2 | `makine` tablosuna garanti alanları ekle + bakım kısıtlama logic'i yaz | Kolay | Yüksek – proje gereksinimi |
| 🟠 3 | `lokasyon` tablosunu bağımsız obje olarak yeniden modelle | Orta | Yüksek – yönetici dashboard |
| 🟠 4 | `servis_firma` + `servis_sorumlusu` modelini genişlet | Kolay | Orta |
| 🟠 5 | `tedarikci` modeline puanlama + güvenilirlik skoru ekle | Orta | Yüksek – iş kuralı gereksinimi |
| 🟡 6 | Node.js → AI servisi HTTP entegrasyonu (`axios` ile `/predict` çağrısı) | Orta | Yüksek – projenin ana değer önerisi |
| 🟡 7 | Cron/Worker mekanizması (periyodik bakım kontrolü + uyarılar) | Orta | Yüksek |
| 🟡 8 | Frontend'e eksik sayfaları ekle (lokasyon, tedarikçi, servis, garanti) | Yüksek | Yüksek |
| ⚪ 9 | Test altyapısı + API dokümantasyonu | Orta | Orta |

---

*Bu rapor, Endux TPM projesinin `proje_konusu_revize.md` dokümanı ve tüm kaynak kodunun detaylı incelenmesi sonucunda hazırlanmıştır.*
*Tarih: 01.04.2026*
