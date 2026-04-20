# Makine Dijital İkiz ve TPM Veri Modeli Tasarımı

Mevcut basit özellik listesinin yerini alacak, sanayi tesislerindeki makinelerin dijital ikizini (Digital Twin) oluşturmaya uygun, kapsamlı veri modeli ve arayüz tasarımı aşağıda sunulmuştur.

## 1. JSON Objesi Yapısı (`teknik_ozellikler` sütunu için)
Eğer bu detaylı verileri Prisma'da tek bir `Json` sütunu içerisinde (örneğin `makine_ozellikleri` tablosundaki `teknik_ozellikler` alanında) esnek olarak tutmak isterseniz, ideal JSON veri yapısı şu şekildedir:

```json
{
  "kimlikBilgileri": {
    "makineModel": "CNC-X500 Serisi",
    "uretici": "Hassas Makine San. A.Ş.",
    "uretimYili": 2023
  },
  "teknikSpesifikasyonlar": {
    "gucTuketimi_kW": 45.5,
    "calismaGerilimi_V": 380,
    "kapasite_BirimSaat": 120,
    "agirlik_kg": 4500,
    "boyutlar_mm": {
      "en": 2500,
      "boy": 4000,
      "yukseklik": 2200
    }
  },
  "operasyonelDurum": {
    "kritiklikSeviyesi": "A", 
    "departmanHatti": "Talaşlı İmalat - Hat 2"
  },
  "dokumantasyon": {
    "kilavuzLinkleri": [
      {
        "baslik": "Kullanım Kılavuzu",
        "url": "https://endux.com/docs/cnc-x500-kullanim.pdf"
      },
      {
        "baslik": "Bakım Prosedürü",
        "url": "https://endux.com/docs/cnc-x500-bakim.pdf"
      }
    ],
    "isoStandartlari": ["ISO 9001", "ISO 45001"]
  }
}
```
*(Not: `Makine ID`, `Seri No`, `Garanti Bitiş Süresi`, `Son Periyodik Bakım` ve `Toplam Çalışma Saati` gibi sık filtrelenen ilişkisel veriler halihazırda `makine` veya `bakim_kaydi` tablolarınızda standart sütunlar olarak bulunduğu için JSON içine tekrar eklenmemiştir.)*

---

## 2. Prisma Schema Formatı (Gelişmiş Yapı)
Eğer JSON yerine, her bir alanın kesin sınırlarının çizildiği tam ilişkisel bir yapı kurmak isterseniz, `makine_ozellikleri` tablosunu aşağıdaki gibi güncelleyebilirsiniz:

```prisma
model makine_ozellikleri {
  ozellik_id                Int       @id @default(autoincrement())
  makine_id                 Int       @unique
  
  // Kimlik Bilgileri
  makine_model              String?   @db.VarChar(100)
  uretici                   String?   @db.VarChar(150)
  uretim_yili               Int?

  // Teknik Spesifikasyonlar
  guc_tuketimi_kw           Decimal?  @db.Decimal(6, 2)
  calisma_gerilimi_v        Int?
  kapasite_birim_saat       Int?
  agirlik_kg                Decimal?  @db.Decimal(8, 2)
  boyut_en_mm               Int?
  boyut_boy_mm              Int?
  boyut_yukseklik_mm        Int?

  // Operasyonel Durum
  kritiklik_seviyesi        String?   @db.VarChar(5) // A, B, C vb.
  departman_hatti           String?   @db.VarChar(150)
  
  // Dokümantasyon (Esnek listeler için Json kullanılabilir)
  dokumantasyon_linkleri    Json?     // [{ baslik: "...", url: "..." }]
  iso_standartlari          Json?     // ["ISO 9001", "ISO 14001"]

  guncelleme_tarihi         DateTime? @default(now()) @db.Timestamp(6)
  
  makine                    makine    @relation(fields: [makine_id], references: [makine_id], onDelete: Cascade, onUpdate: NoAction, map: "fk_makine")
}
```

---

## 3. React Arayüzü İçin 'Teknik Kart' Tasarım Önerileri

Bu detaylı verileri kullanıcılara sunarken sıkıcı tablolar yerine "Profesyonel Teknik Kart (Digital Twin Card)" tasarımı kullanmanız Endux'un kalitesini artıracaktır.

### Tasarım İlkeleri ve Düzen:

1. **Card Tabanlı Izgara (Grid) Sistemi:**
   - Kartı mantıksal bölümlere ayırın: `Kimlik`, `Teknik`, `Operasyon` ve `Dokümanlar`.
   - CSS Grid (örneğin `grid-template-columns: repeat(2, 1fr)`) kullanarak 2 sütunlu bir okuma düzeni oluşturun.

2. **İkonografi ve Renk Kodlaması:**
   - **Güç/Elektrik** bilgileri için `⚡ (Zıplayan Elektrik)` veya sarı renkli `Lucide/Heroicons` ikonları.
   - **Kritiklik Seviyesi (A/B/C)** için renkli rozetler (Badges): 
     - Seviye A: Kırmızı arka plan (`#ffebee`), koyu kırmızı metin (En kritik).
     - Seviye B: Turuncu arka plan.
     - Seviye C: Yeşil arka plan.
   - **Boyut/Ağırlık** için `📏 (Cetvel)` veya `⚖️ (Terazi)` ikonları.

3. **Görsel Hiyerarşi (Typography):**
   - Etiketler (Örn: "Çalışma Gerilimi"): Açık gri/soluk renk (`#7f8c8d`), küçük font (`12px`).
   - Değerler (Örn: "380 V"): Koyu lacivert/siyah renk (`#2c3e50`), kalın font (`15px`, `fontWeight: 600`).
   - Veri birimlerini (kW, mm, kg) değerin hemen yanında biraz daha soluk bir renkle göstererek (Örn: `45.5` <span style="color:#aaa">kW</span>) okunabilirliği artırın.

4. **Dokümanlar Bölümü (Aksiyon Alanı):**
   - PDF kılavuzlarını alt alta sıralı, solunda `📄 (PDF İkonu)` bulunan tıklanabilir hap butonlar (pill buttons) şeklinde tasarlayın. Üzerine gelince (hover) rengi hafifçe değişmeli.

5. **Gelişmiş Hover (Üzerine Gelme) Efektleri:**
   - Kartın geneline çok hafif bir `box-shadow: 0 4px 6px rgba(0,0,0,0.05)` verin. Fare ile üzerine gelindiğinde `transform: translateY(-2px)` ve gölgenin hafifçe artması ile "canlı" hissi uyandırın.
   - Değerlerin etrafına çok ince bir sınır (border) çizmek yerine arkalarına çok açık bir gri (`#f8f9fa`) fon rengi atayarak modern bir "Kutu (Container)" görünümü yakalayın.
