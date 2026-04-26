# Hemen Uygulanacak View-Endpoint Yol Haritası

Bu doküman, sistemin mevcut akışına göre kısa vadede en mantıklı şekilde devreye alınabilecek `view` yapılarını ve bunlar için açılması gereken endpoint'leri içerir.

Buradaki seçimleri yaparken şu mantığı kullandım:

- mevcut backend akışını bozmamak
- mümkün olduğunca mevcut route yapısına uymak
- riskli SQL tanımlarını ilk etapta kullanmamak
- hızlı değer üreten ekranları öncelemek

## Kısa Karar

Hemen uygulanmasını önerdiğim 3 parça:

1. `view_makineler` -> mevcut `GET /api/makineler`
2. `view_dashboard_kritik_uyarilar` -> yeni `GET /api/dashboard/kritik-uyarilar`
3. `v_parca_detay_listesi` -> yeni `GET /api/parcalar/detay`

Şimdilik beklemesini önerdiklerim:

- `view_dashboard_masraf_analizi`
- `view_dashboard_bakim_bekleyenler`
- `view_dashboard_makine_masraf_detayli`
- `view_teknisyen_bakim_ozeti`

Sebep:

- Bu ikinci grupta join koşulları ve alan adları açısından doğrulama ihtiyacı daha yüksek görünüyor.

---

## 1. `view_makineler` -> `GET /api/makineler`

### Neden bu iyi bir başlangıç?

Zaten sistemde bu endpoint var:

- `node-service/src/routes/makineRoutes.ts`
- `GET /api/makineler`

Şu an bu endpoint Prisma `include` ile makine, firma, tür ve özellikleri getiriyor. `view_makineler` bu işi daha sade hale getirir.

### Kullanılacak view

```sql
public.view_makineler
```

### Kullanılacak endpoint

```text
GET /api/makineler
```

### Yapılacak değişiklik

Sadece `tumMakineBilgileriGetir` fonksiyonunu view üzerinden çalıştır.

### Kod

`node-service/src/controllers/makineKontrol.ts` içindeki `tumMakineBilgileriGetir` fonksiyonunu şu mantıkta düzenleyebilirsin:

```ts
export async function tumMakineBilgileriGetir(req: Request, res: Response) {
    try {
        const makineler = await prisma.$queryRaw<any[]>`
            SELECT * FROM public.view_makineler
        `;

        res.status(200).json({
            success: true,
            message: "Tüm makineler başarıyla getirildi.",
            data: makineler
        });
    } catch (error) {
        console.error("Tüm makine bilgileri getirme hatası:", error);
        res.status(500).json({
            success: false,
            message: "Tüm makine bilgileri getirilirken bir hata oluştu."
        });
    }
}
```

### Avantajı

- listeleme sorgusu sadeleşir
- join mantığı view içine taşınır
- yönetici liste ekranı için daha temiz veri döner

### Dikkat

Bu view alan adlarını alias ile döndürüyor. Örneğin:

- `Makine Adı`
- `QR Kod`
- `Seri No`

Frontend tarafı şu an `makine_adi`, `makine_qr` gibi alan bekliyorsa iki seçenek var:

1. SQL view alias'larını backend dostu hale getir
2. Backend içinde response map et

Örnek map:

```ts
const data = makineler.map((m) => ({
    makine_adi: m["Makine Adı"],
    makine_qr: m["QR Kod"],
    seri_no: m["Seri No"],
    aktiflik_durumu: m["Aktiflik"],
    firma_adi: m["Müşteri / Sahip Firma"],
    makine_turu: m["Makine Türü"],
    risk_katsayisi: Number(m["Risk Katsayısı"] ?? 0),
    satin_alma_maliyeti: Number(m["Maliyet"] ?? 0),
    garanti_suresi: m["Garanti Süresi"],
    teknik_ozellikler: m["Teknik Özellikler (JSON)"],
}));
```

### Sonuç

Bu parça ilk gün uygulanabilir.

---

## 2. `view_dashboard_kritik_uyarilar` -> `GET /api/dashboard/kritik-uyarilar`

### Neden bu iyi bir başlangıç?

Bu view, sistemde dağınık halde bulunan kritik sinyalleri tek yerde topluyor:

- yüksek riskli makineler
- AI tahminleri
- kapanmamış arıza kayıtları

Bu yüzden ana dashboard için en hızlı değer üreten endpoint budur.

### Kullanılacak view

```sql
public.view_dashboard_kritik_uyarilar
```

### Kullanılacak endpoint

```text
GET /api/dashboard/kritik-uyarilar
```

### Önerilen yetki

```text
YONETICI, TEKNISYEN
```

### Eklenecek controller

Yeni dosya:

```text
node-service/src/controllers/dashboardKontrol.ts
```

Dosya içeriği:

```ts
import { Request, Response } from "express";
import prisma from "../config/prisma";

export async function kritikUyarilariGetir(req: Request, res: Response): Promise<void> {
    try {
        const rows = await prisma.$queryRaw<any[]>`
            SELECT * FROM public.view_dashboard_kritik_uyarilar
        `;

        const data = rows.map((row) => ({
            makine_id: row.makine_id,
            makine_ad: row.makine_ad,
            uyari_tipi: row.uyari_tipi,
            deger: row.deger,
            mesaj: row.mesaj,
            tarih: row.tarih,
            oncelik_sirasi: Number(row.oncelik_sirasi ?? 0),
        }));

        res.status(200).json({
            success: true,
            message: `${data.length} adet kritik uyarı getirildi.`,
            data,
        });
    } catch (error) {
        console.error("Kritik uyarılar getirme hatası:", error);
        res.status(500).json({
            success: false,
            message: "Kritik uyarılar getirilirken bir hata oluştu.",
        });
    }
}
```

### Eklenecek route

Yeni dosya:

```text
node-service/src/routes/dashboardRoutes.ts
```

Dosya içeriği:

```ts
import { Router } from "express";
import { kritikUyarilariGetir } from "../controllers/dashboardKontrol";
import { oturumKontrol, rolKontrol } from "../middlewares/yetki";

const router = Router();

router.get(
    "/kritik-uyarilar",
    oturumKontrol,
    rolKontrol("YONETICI", "TEKNISYEN"),
    kritikUyarilariGetir
);

export default router;
```

### Route index kaydı

`node-service/src/routes/index.ts` içine şunu ekle:

```ts
import dashboardRoutes from "./dashboardRoutes";
```

ve aşağıdaki satırı route listesine ekle:

```ts
router.use("/dashboard", dashboardRoutes);
```

### Sonuç endpoint

```text
GET /api/dashboard/kritik-uyarilar
```

### Sonuç

Bu parça da ilk gün uygulanabilir.

---

## 3. `v_parca_detay_listesi` -> `GET /api/parcalar/detay`

### Neden bu iyi bir başlangıç?

Bu view çok düzenli bir rapor veriyor:

- parça
- kategori
- tedarikçi
- iletişim

Şu anda projede parça detay ekranı için hazır bir endpoint görünmüyor. Bu yüzden yeni bir okuma endpoint'i olarak eklenmesi mantıklı.

### Kullanılacak view

```sql
public.v_parca_detay_listesi
```

### Kullanılacak endpoint

```text
GET /api/parcalar/detay
```

### Önerilen yetki

```text
YONETICI, TEKNISYEN
```

### Eklenecek controller

Yeni dosya:

```text
node-service/src/controllers/parcaKontrol.ts
```

Dosya içeriği:

```ts
import { Request, Response } from "express";
import prisma from "../config/prisma";

export async function parcaDetayListesiGetir(req: Request, res: Response): Promise<void> {
    try {
        const rows = await prisma.$queryRaw<any[]>`
            SELECT * FROM public.v_parca_detay_listesi
        `;

        const data = rows.map((row) => ({
            parca_id: row.parca_id,
            parca_adi: row["PARÇA ADI"],
            tahmini_omur_saati: Number(row["PARCANIN TAHMİNİ ÖMRÜ"] ?? 0),
            parca_maliyeti: Number(row["PARCA MALİYETİ"] ?? 0),
            tedarik_gun_suresi: Number(row["PARCA TEDARİK SÜRESİ"] ?? 0),
            kategori_adi: row["PARCA KATEGORİ ADI"],
            tedarikci_firma: row["TEDARİKCİ FİRMA"],
            tedarikci_yetkili: row["TEDARİKCİ FİRMA YETKİLİSİ"],
            vergi_no: row["TEDARİKCİ FİRMA VERGİ NO"],
            aktiflik: row["AKTİFLİK"],
            telefon: row["FİRMA TELEFON"],
            mail: row["FİRMA MAİL"],
            il_ilce: row["İL/İLCE"],
            acik_adres: row["AÇIK ADRES"],
        }));

        res.status(200).json({
            success: true,
            message: `${data.length} adet parça detayı getirildi.`,
            data,
        });
    } catch (error) {
        console.error("Parça detay listesi hatası:", error);
        res.status(500).json({
            success: false,
            message: "Parça detay listesi getirilirken bir hata oluştu.",
        });
    }
}
```

### Eklenecek route

Yeni dosya:

```text
node-service/src/routes/parcaRoutes.ts
```

Dosya içeriği:

```ts
import { Router } from "express";
import { parcaDetayListesiGetir } from "../controllers/parcaKontrol";
import { oturumKontrol, rolKontrol } from "../middlewares/yetki";

const router = Router();

router.get(
    "/detay",
    oturumKontrol,
    rolKontrol("YONETICI", "TEKNISYEN"),
    parcaDetayListesiGetir
);

export default router;
```

### Route index kaydı

`node-service/src/routes/index.ts` içine şunu ekle:

```ts
import parcaRoutes from "./parcaRoutes";
```

ve route listesine şu satırı ekle:

```ts
router.use("/parcalar", parcaRoutes);
```

### Sonuç endpoint

```text
GET /api/parcalar/detay
```

### Sonuç

Bu parça da hızlı uygulanabilir.

---

## Şimdilik Bekletilecek View'lar

Bu view'lar mantıklı ama ilk sprintte doğrudan bağlamanı önermem.

### `view_dashboard_masraf_analizi`

Sebep:

- join doğrulaması gerekiyor
- yanlış eşleşme ihtimali var

Ne zaman alınmalı:

- SQL çıktısı test edilince

Önerilen endpoint:

```text
GET /api/dashboard/masraf-analizi
```

### `view_dashboard_bakim_bekleyenler`

Sebep:

- arıza ve tür join koşulları gözden geçirilmeli

Önerilen endpoint:

```text
GET /api/dashboard/bakim-bekleyenler
```

### `view_dashboard_makine_masraf_detayli`

Sebep:

- bakım türü ve parça join tarafı doğrulanmalı

Önerilen endpoint:

```text
GET /api/dashboard/makine-masraf-detay
```

### `view_teknisyen_bakim_ozeti`

Sebep:

- join alanlarını doğrulamadan üretime almak riskli

Önerilen endpoint:

```text
GET /api/gorevler/teknisyen-ozet
```

---

## Uygulama Sırası

Benim önerdiğim gerçek uygulama sırası:

1. `view_makineler` ile mevcut `GET /api/makineler` endpoint'ini sadeleştir
2. `dashboardRoutes.ts` ve `dashboardKontrol.ts` ekle
3. `GET /api/dashboard/kritik-uyarilar` endpoint'ini aç
4. `parcaRoutes.ts` ve `parcaKontrol.ts` ekle
5. `GET /api/parcalar/detay` endpoint'ini aç

---

## Hızlı Kontrol Listesi

Uygularken şu sırayı kullan:

1. Önce SQL view'ı veritabanında test et
2. Sonra controller yaz
3. Route dosyasını ekle
4. `routes/index.ts` içine kaydet
5. Postman ile endpoint'i çağır
6. Frontend'in beklediği alan adlarını kontrol et

Kontrol sorguları:

```sql
SELECT * FROM public.view_makineler LIMIT 5;
SELECT * FROM public.view_dashboard_kritik_uyarilar LIMIT 5;
SELECT * FROM public.v_parca_detay_listesi LIMIT 5;
```

---

## Son Tavsiye

Eğer tek bir yerden başlaman gerekiyorsa sıra şu olsun:

1. `view_dashboard_kritik_uyarilar`
2. `view_makineler`
3. `v_parca_detay_listesi`

Sebep:

- dashboard değeri hemen görünür
- makine listesi mevcut akışa direkt oturur
- parça detayı yeni ama temiz bir rapor endpoint'i sağlar

Bir sonraki adımda istersen bunun devamı olarak sana doğrudan kopyalanabilir gerçek dosya içerikleriyle:

- `dashboardKontrol.ts`
- `dashboardRoutes.ts`
- `parcaKontrol.ts`
- `parcaRoutes.ts`
- `routes/index.ts` güncellemesi

tek tek hazır hale de çıkarabilirim.
