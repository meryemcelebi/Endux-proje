# `init.sql` Backend Kullanım Rehberi

Bu doküman, `C:\Users\User\Desktop\endux\db-init\init.sql` içindeki `procedure`, `function` ve `view` tanımlarının `node-service` tarafında nasıl ve nerede kullanılabileceğini açıklamak için hazırlandı.

## Kısa Özet

- `procedure` yapıları yazma işlemleri için uygundur.
- `view` yapıları listeleme, raporlama ve dashboard endpoint'leri için uygundur.
- Projede şu an aktif olarak procedure kullanan bir örnek zaten var:
  - `node-service/src/controllers/checklistYonetici.ts`
  - `pr_kontrol_kaydet` çağrılıyor.
- Geri kalan procedure ve view'lar için backend tarafında en doğru yaklaşım:
  - Yazma işlemlerinde `prisma.$executeRaw`
  - Okuma işlemlerinde `prisma.$queryRaw`
- Ancak `init.sql` içinde bazı nesneler mevcut Prisma şemasıyla birebir uyuşmuyor. Bu yüzden doğrudan kullanmadan önce test etmek önemli.

## Mevcut Backend Yapısı Açısından Ana Karar

Projede veri erişiminin ana yolu Prisma. Bu yüzden SQL nesnelerini kullanmanın en temiz yolu:

1. `controller` içinde doğrudan uzun raw SQL yazmamak
2. SQL çağrılarını ayrı bir servis katmanına toplamak
3. Controller'da sadece request/response yönetmek

Önerilen yeni klasör:

```text
node-service/src/services/sql/
```

Önerilen dosya yapısı:

```text
node-service/src/services/sql/dashboardSql.ts
node-service/src/services/sql/makineSql.ts
node-service/src/services/sql/bakimSql.ts
node-service/src/services/sql/firmaSql.ts
node-service/src/services/sql/checklistSql.ts
```

Bu yapı sayesinde controller dosyaları temiz kalır ve `CALL ...` ile `SELECT * FROM view...` ifadeleri tek yerde toplanır.

## Backend'de Teknik Olarak Nasıl Kullanılır

### 1. Procedure çağırmak

`procedure` için `CALL` kullanılır. Prisma tarafında:

```ts
await prisma.$executeRaw`
  CALL public.sp_tedarikci_ekle(
    ${firma_adi},
    ${telefon},
    ${mail},
    ${il},
    ${ilce},
    ${acik_adres},
    ${vergi_no},
    ${yetkili_kisi}
  )
`;
```

Kural:

- `INSERT`, `UPDATE`, `DELETE`, `CALL` gibi yazma odaklı işlemlerde `prisma.$executeRaw`
- Parametre geçirirken tagged template kullan
- `unsafe` varyantlarını gereksiz yere kullanma

### 2. View okumak

`view` için normal sorgu yapılır:

```ts
type DashboardMasrafRow = {
  makine_id: number;
  makine_ad: string | null;
  toplam_bakim_maliyeti: unknown;
  toplam_parca_maliyeti: unknown;
  genel_toplam_maliyet: unknown;
};

const rows = await prisma.$queryRaw<DashboardMasrafRow[]>`
  SELECT * FROM public.view_dashboard_masraf_analizi
`;
```

Kural:

- Rapor, özet, dashboard, listeler için `prisma.$queryRaw`
- Dönüş tipini TypeScript tarafında tanımla
- Dönen numeric alanları gerekirse `Number(...)` ile normalize et

## Şu Anda Projede Kullanıma En Uygun SQL Nesneleri

### 1. `pr_kontrol_kaydet`

Amaç:

- Günlük kontrol formu ve form cevaplarını tek transaction içinde kaydetmek

Mevcut kullanım:

- `node-service/src/controllers/checklistYonetici.ts`
- `formKaydet`

Durum:

- Zaten doğru mantıkla kullanılıyor.
- Bu, repo içinde SQL procedure kullanımının en iyi örneği.

Ne zaman kullanılmalı:

- Operatörün kontrol formu gönderdiği endpoint'lerde
- Bir ana kayıt + çoklu alt kayıt birlikte oluşuyorsa

Backend notu:

- Bu procedure mantığını korumak iyi bir tercih çünkü çoklu insert akışını veritabanı tarafında toparlıyor.

### 2. `sp_makine_temel_kaydet`

Amaç:

- Firma, makine türü, makine ve makine özellikleri kaydını tek akışta oluşturmak

Backend'de en uygun yer:

- `node-service/src/controllers/makineKontrol.ts`
- `makineEkle`

Şu anki durum:

- `makineEkle` bunu Prisma ile parça parça yapıyor.
- Eğer bu süreci tamamen veritabanı tarafına taşımak istersen bu procedure doğru aday.

Ne zaman tercih edilmeli:

- Firma ve makine türü yoksa otomatik oluşturulsun istiyorsan
- Kayıt akışını veritabanı yönetsin istiyorsan
- Çok adımlı makine kayıt sürecini tek `CALL` ile toplamak istiyorsan

Ne zaman tercih edilmemeli:

- Uygulama katmanında daha görünür doğrulama istiyorsan
- ID bazlı akış kullanıyorsan ve zaten tüm ilişkileri frontend/backend çözüyorsa

Öneri:

- Kısa vadede mevcut Prisma akışını bozma
- Orta vadede `makineEkle` için alternatif servis yaz:
  - `createMachineWithProcedure()`

Örnek:

```ts
await prisma.$executeRaw`
  CALL public.sp_makine_temel_kaydet(
    ${firma_adi},
    ${makine_tur_adi},
    ${makine_adi},
    ${makine_qr},
    ${seri_no},
    ${satin_alma_tarihi}::date,
    ${satin_alma_maliyeti},
    ${garanti_suresi},
    ${toplam_calisma_saati},
    ${risk_katsayisi},
    ${servis_pin},
    ${JSON.stringify(teknik_ozellikler)}::jsonb,
    ${telefon},
    ${email},
    ${il},
    ${ilce},
    ${acik_adres}
  )
`;
```

### 3. `sp_bakim_ekle`

Amaç:

- Bakım kaydı, servis firması, arıza ilişkisi, bakım türü ve değişen parça akışını DB tarafında toplamak

Backend'de en uygun yer:

- `node-service/src/controllers/bakimKontrol.ts`
- `bakimKaydiGir`

Şu anki durum:

- `bakimKaydiGir` Prisma transaction ile iyi çalışıyor.
- Fakat procedure versiyonu isim bazlı çözümleme yapıyor:
  - makine adı
  - bakım yapan kişi adı
  - servis firma adı
  - arıza türü adı
  - bakım türü adı

Bu yüzden dikkat:

- Backend tarafın şu an ID bazlı çalışıyor.
- Procedure ise daha çok dış kaynaklı, serbest metinle gelen veri için tasarlanmış görünüyor.

Ne zaman kullanılmalı:

- Kullanıcılar isim bazlı veri giriyorsa
- ETL/import süreçleri varsa
- "Makine adı, servis adı, parça adı" üzerinden toplu kayıt alınacaksa

Ne zaman kullanılmamalı:

- Normal API akışında zaten `id` değerleri güvenli şekilde geliyorsa

Öneri:

- Mevcut API için mevcut Prisma transaction daha net
- Bu procedure'ü ayrı bir import endpoint'inde kullanmak daha mantıklı

Örnek kullanım yeri:

- Yeni bir endpoint:
  - `POST /api/bakimlar/import`

### 4. `pr_ariza_kayit`

Amaç:

- Arıza kaydı oluşturmak
- Arıza türü yoksa otomatik açmak

Backend'de en uygun yer:

- Yeni bir arıza controller'ı açılacaksa orada
- Ya da `makineKontrol.ts` içinde servis/teknisyen akışına bağlı bir arıza oluşturma endpoint'inde

Önerilen yeni dosya:

```text
node-service/src/controllers/arizaKontrol.ts
node-service/src/routes/arizaRoutes.ts
```

Uygun endpoint örneği:

```text
POST /api/arizalar
```

Ne zaman kullanılmalı:

- Arıza türünü kullanıcı metin olarak giriyorsa
- Tür yoksa otomatik tanımlansın isteniyorsa

### 5. `sp_tedarikci_ekle`

Amaç:

- Tedarikçi + iletişim bilgisini tek akışta eklemek

Backend'de en uygun yer:

- `node-service/src/controllers/firmaKontrol.ts`
- `tedarikciEkle`

Şu anki durum:

- `tedarikciEkle` şu an Prisma ile bunu zaten yapıyor.

Ne zaman kullanılmalı:

- Tedarikçi ekleme mantığını tamamen veritabanına taşımak istersen
- Veri kalitesi kurallarını DB tarafında merkezileştirmek istersen

Öneri:

- Kullanılabilir, ama mevcut Prisma kodu zaten anlaşılır.
- Öncelik düşük.

### 6. `sp_parca_ekle`

Amaç:

- Parça eklemek
- Kategori yoksa açmak
- Tedarikçi yoksa işlemi durdurmak

Backend'de en uygun yer:

- Projede henüz ayrı bir parça controller'ı görünmüyor

Önerilen yeni dosyalar:

```text
node-service/src/controllers/parcaKontrol.ts
node-service/src/routes/parcaRoutes.ts
```

Örnek endpoint:

```text
POST /api/parcalar
GET /api/parcalar/detay
```

Bu procedure özellikle parça yönetim ekranı geldiğinde çok iş görür.

### 7. `sp_garanti_firmasi_kaydet`

Amaç:

- Garanti firması ve iletişim kaydını oluşturmak

Backend'de en uygun yer:

- `makineKontrol.ts` içindeki makine ekleme akışının ön adımı olarak
- Ya da ayrı garanti firması yönetim endpoint'inde

Ancak:

- Bu procedure tanımı mevcut şema ile uyumsuz görünüyor.
- Aşağıdaki "kritik notlar" bölümüne bak.

### 8. `get_sorular`

Amaç:

- Genel sorular + makine türüne özel soruları tek sorguda döndürmek

Backend'de en uygun yer:

- `node-service/src/controllers/checklistYonetici.ts`
- `qrIleSablonGetir`

Şu anki durum:

- `qrIleSablonGetir` önce makineyi, sonra şablonu, sonra maddeleri Prisma ile ayrı adımlarda çekiyor.

Bu function mantıken çok uygun:

- QR ile makine bulunur
- Sonra `get_sorular(makine_id)` çağrılır
- Tek endpoint içinde sorular hazır döner

Ama önemli:

- Function tanımı şu an şemayla uyuşmuyor olabilir.
- Doğrudan üretime almadan önce düzeltme/test gerekir.

## View'lar Nerede Kullanılmalı

### 1. `view_makineler`

Amaç:

- Makine listesi için hazır, birleştirilmiş görünüm

En uygun yer:

- `node-service/src/controllers/makineKontrol.ts`
- `tumMakineBilgileriGetir`

Ne sağlar:

- `firma`, `makine_turu`, `makine_ozellikleri` join yükünü view içine alır
- Liste ekranlarında daha sade sorgu kullanırsın

Örnek:

```ts
const makineler = await prisma.$queryRaw`
  SELECT * FROM public.view_makineler
`;
```

En iyi kullanım alanı:

- Yönetici makine liste ekranı
- Rapor ekranı
- Excel export

### 2. `view_garanti_firmalari`

Amaç:

- Garanti firmalarını iletişim bilgileriyle birlikte hazır sunmak

En uygun yer:

- Yeni garanti firma liste endpoint'i
- Ya da `makineDetayGetir` içinde yardımcı veri endpoint'i

Örnek endpoint:

```text
GET /api/garanti-firmalari
```

### 3. `v_parca_detay_listesi`

Amaç:

- Parça, kategori, tedarikçi ve iletişim bilgilerini tek yerde sunmak

En uygun yer:

- Yeni parça listeleme endpoint'i
- Satın alma / stok raporu ekranı

Örnek endpoint:

```text
GET /api/parcalar/detay
```

### 4. `view_dashboard_masraf_analizi`

Amaç:

- Makine bazında toplam bakım + toplam parça + toplam masraf özetini vermek

En uygun yer:

- `node-service/src/controllers/analizKontrol.ts`
- Yeni bir dashboard controller'ı

En mantıklı endpoint:

```text
GET /api/dashboard/masraf-analizi
```

Bu view, şu an controller içinde elle yapılan maliyet hesaplarını sadeleştirebilir.

### 5. `view_dashboard_makine_masraf_detayli`

Amaç:

- Masrafı bakım türü ve parça düzeyinde detaylandırmak

En uygun yer:

- Yönetici dashboard
- Makine masraf detay ekranı

Örnek endpoint:

```text
GET /api/dashboard/makine-masraf-detay
```

### 6. `view_dashboard_kritik_uyarilar`

Amaç:

- Kritik risk, AI tahmini ve açık arıza kayıtlarını tek listede toplamak

En uygun yer:

- Yeni dashboard controller
- Ana sayfa uyarı paneli

Örnek endpoint:

```text
GET /api/dashboard/kritik-uyarilar
```

Bu view özellikle yönetici paneli için çok değerli.

### 7. `view_dashboard_bakim_bekleyenler`

Amaç:

- Açık arızası bulunan ve risk seviyesiyle birlikte önceliklendirilen makineleri göstermek

En uygun yer:

- Bakım bekleyen makine listesi
- Görev atama ekranı

Örnek endpoint:

```text
GET /api/dashboard/bakim-bekleyenler
```

### 8. `v_dashboard_bakim_rapor`

Amaç:

- Bakım raporunu servis, parça, tedarikçi ve maliyet detaylarıyla vermek

En uygun yer:

- Yönetici rapor ekranı
- PDF/Excel export
- Servis performans raporu

Örnek endpoint:

```text
GET /api/raporlar/bakim
```

### 9. `view_operator_makine_ozeti`

Amaç:

- Operatörün makine kullanım ve risk özetini çıkarmak

En uygun yer:

- `node-service/src/controllers/gorevKontrol.ts`
- Operatör görev özet ekranı

Örnek endpoint:

```text
GET /api/gorevler/operator-ozet
```

### 10. `view_teknisyen_bakim_ozeti`

Amaç:

- Teknisyen/servis sorumlusu bazında bakım özetini sunmak

En uygun yer:

- `node-service/src/controllers/gorevKontrol.ts`
- Ya da yeni servis performans endpoint'i

Örnek endpoint:

```text
GET /api/gorevler/teknisyen-ozet
```

## En Faydalı Entegrasyon Sırası

Benim önerim şu sırayla ilerlemek:

1. Önce yalnızca `view` entegrasyonu yap
2. Sonra zaten kullanılan `pr_kontrol_kaydet` dışındaki procedure'leri tek tek değerlendir
3. Yazma işlemlerinde yalnızca gerçekten çok adımlı olan akışları procedure'e taşı

Öncelik sırası:

1. `view_dashboard_kritik_uyarilar`
2. `view_dashboard_masraf_analizi`
3. `view_makineler`
4. `v_parca_detay_listesi`
5. `view_operator_makine_ozeti`
6. `view_teknisyen_bakim_ozeti`
7. `sp_parca_ekle`
8. `pr_ariza_kayit`
9. `sp_makine_temel_kaydet`
10. `sp_bakim_ekle`

Sebep:

- View'lar read-only olduğu için daha güvenli
- Procedure'ler ise veri yazdığı için şema uyumsuzluğu varsa daha büyük risk oluşturur

## Önerilen Backend Yerleşimi

### Yeni route grubu önerisi

```text
GET /api/dashboard/kritik-uyarilar
GET /api/dashboard/masraf-analizi
GET /api/dashboard/bakim-bekleyenler
GET /api/dashboard/makine-masraf-detay
GET /api/raporlar/bakim
GET /api/parcalar/detay
GET /api/garanti-firmalari
```

### Yeni controller önerisi

```text
node-service/src/controllers/dashboardKontrol.ts
node-service/src/controllers/raporKontrol.ts
node-service/src/controllers/parcaKontrol.ts
node-service/src/controllers/arizaKontrol.ts
```

### Örnek controller yapısı

```ts
import { Request, Response } from "express";
import prisma from "../config/prisma";

export async function kritikUyarilariGetir(req: Request, res: Response) {
  try {
    const rows = await prisma.$queryRaw`
      SELECT * FROM public.view_dashboard_kritik_uyarilar
    `;

    res.status(200).json({
      success: true,
      data: rows,
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

## Güvenli Kullanım Kuralları

### 1. Raw SQL'i servis katmanında topla

Controller içinde uzun SQL birikirse okunabilirlik düşer.

### 2. `unsafe` kullanma

Şu tip kullanım tercih et:

```ts
await prisma.$queryRaw`
  SELECT * FROM public.view_makineler WHERE "Makine Adı" ILIKE ${"%" + q + "%"}
`;
```

### 3. Numeric alanları normalize et

PostgreSQL numeric alanları bazen string benzeri dönebilir. Gerekirse response öncesi dönüştür:

```ts
const normalized = rows.map((row) => ({
  ...row,
  genel_toplam_maliyet: Number(row.genel_toplam_maliyet ?? 0),
}));
```

### 4. View'lar için pagination ve filtre ekle

Özellikle rapor endpoint'lerinde:

- tarih aralığı
- firma filtresi
- makine filtresi
- sayfalama

eklemek iyi olur.

## `init.sql` İçin Kritik İnceleme Notları

Buradaki bölüm önemli. Aşağıdaki nesneler mantık olarak faydalı olsa da bazıları mevcut Prisma şemasıyla uyumsuz görünüyor.

### 1. `get_sorular`

Muhtemel sorunlar:

- Parametre adı `makine_qr` ama tipi `integer`
- İçeride `m.m_tur_id` kullanılıyor
- Prisma şemasında alan adı `makine_tur_id`

Yorum:

- Function fikri doğru
- Ama tanım büyük ihtimalle eski şemadan kalmış

### 2. `pr_kontrol_kaydet`

Muhtemel sorun:

- `form_madde_cevap` içine `soru_tipi` alanı yazıyor
- Prisma şemasındaki `form_madde_cevap` modelinde bu alan görünmüyor

Yorum:

- Çalışan veritabanı ile Prisma şeman arasında fark olabilir
- Bu procedure zaten backend'de kullanıldığı için canlı DB üzerinde karşılığı olabilir
- Prisma şemasını tekrar doğrulamak faydalı olur

### 3. `func_form_sonrasi_tetikle`

Muhtemel sorun:

- `makine` tablosunda `mevcut_risk_skoru` alanını update ediyor
- Prisma şemasındaki `makine` modelinde böyle bir alan görünmüyor

Yorum:

- Trigger mantığı faydalı olabilir
- Ama kolon ismi güncel mi kontrol edilmeli

### 4. `pr_makine_operator`

Muhtemel sorun:

- Procedure içinde başka bir `create or replace procedure` gömülü
- Tanım yapısı problemli görünüyor

Yorum:

- Bu nesne doğrudan kullanıma hazır görünmüyor

### 5. `sp_garanti_firmasi_kaydet`

Muhtemel sorunlar:

- `iletisim` tablosunda `email` yerine Prisma şemasında `mail` var
- `garanti_firma` tablosunda `g_firma_adi` kullanılıyor gibi görünüyor
- Prisma şemasında alan `firma_adi`

Yorum:

- Bu procedure büyük ihtimalle düzeltme istiyor

### 6. Bazı view join koşulları şüpheli

Özellikle şu view'larda join alanları dikkat istiyor:

- `view_dashboard_bakim_bekleyenler`
- `view_dashboard_makine_masraf_detayli`
- `view_dashboard_masraf_analizi`
- `view_teknisyen_bakim_ozeti`

Muhtemel örnek sorunlar:

- `ariza_id` ile `ariza_tur_id` eşlenmiş olabilir
- `bakim_id` ile `bakim_tur_id` eşlenmiş olabilir
- `parca_degisim_id` ile `parca_id` eşlenmiş olabilir

Yorum:

- Bu view'lar mantıksal olarak çok değerli
- Ama doğrudan backend'e bağlamadan önce SQL sonucu örnek veriyle doğrulanmalı

## Pratik Çalışma Planı

En sağlıklı ilerleyiş:

1. Önce her view için `SELECT * FROM ... LIMIT 5` çalıştır
2. Sonuç kolonlarını kontrol et
3. Şema uyumsuzluğu varsa SQL tarafını düzelt
4. Sonra backend'de read-only endpoint aç
5. Procedure'ler için test payload'ları oluştur
6. Sadece doğrulanan procedure'leri production akışına al

## Sonuç

Bu repo için genel tavsiyem:

- `view` yapıları dashboard ve raporlama için çok uygun
- `procedure` yapıları ise çok adımlı kayıt akışlarında faydalı
- Şu anda en güvenli başlangıç noktası `view` entegrasyonu
- En olgun procedure örneği şu an `pr_kontrol_kaydet`
- `sp_bakim_ekle`, `sp_makine_temel_kaydet`, `sp_tedarikci_ekle`, `sp_parca_ekle` gibi nesneler kullanılabilir, ama önce mevcut şemayla birebir uyumları doğrulanmalı

Eğer istersen ikinci adımda bunun devamı olarak sana şunlardan birini de hazırlayabilirim:

- view'lar için hazır `dashboardKontrol.ts` kodu
- procedure çağrıları için `services/sql` katmanı
- `init.sql` içindeki problemli view/procedure'lerin tek tek düzeltme listesi
