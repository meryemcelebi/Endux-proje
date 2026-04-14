# Makine Özellikleri (JSONB) Doğrulama Katmanı

Bu doküman, `makine_ozellikleri` kolonunun esnek JSONB yapısı yüzünden oluşabilecek "Tip Uyuşmazlığı" veya "eksik parametre" risklerine karşı alınmış olan doğrulama (validation) ve TypeScript arayüzü (interface) kodlarını içermektedir.

Eğer bu doğrulamayı sisteminize tekrar dâhil etmek isterseniz, aşağıdaki 3 dosyada gösterilen değişiklikleri kendi projenize kopyalayabilirsiniz.

---

## 1. TypeScript Tür Tanımlamalarının Eklenmesi
**Dosya:** `src/interfaces/makine.types.ts`

Mevcut `IMakineOzellikleri` arayüzünü aşağıdaki gibi güncelleyin ve her makine tipi için özelleştirilmiş yeni tip arayüzlerini ekleyin:

```typescript
// "makine_ozellikleri" JSONB kolonunu şekillendiren Ana Tip
export interface IMakineOzellikleri {
    tip: 'CNC' | 'KOMPRESOR' | 'ENJEKSIYON' | 'DIGER';
    teknik_spesifikasyonlar: Record<string, string | number | boolean>;
    genel_bakim_periyodu_saat: number;
    ai_genel_bakim_uyari_marji_saat?: number;
    parca_bakim_kurallari?: IParcaBakimKurali[];
    otonom_bakim_kriterleri?: IOtonomFormMaddesi[];
}

// Makineye özel spesifikasyon arayüzleri
export interface ICNCTeknikSpesifikasyon {
    is_mili_hizi_rpm: number;
    eksen_sayisi: number;
    kontrol_unitesi?: string;
}

export interface IKompresorTeknikSpesifikasyon {
    maksimum_basinc_bar: number;
    debi_m3_dk: number;
    motor_gucu_kw?: number;
}

export interface IEnjeksiyonTeknikSpesifikasyon {
    mengene_kuvveti_ton: number;
    enjeksiyon_hacmi_cm3: number;
    vida_capi_mm?: number;
}
```

---

## 2. Doğrulama (Validator) Modülünün Oluşturulması
**Dosya:** `src/utils/makineValidator.ts`

Aşağıdaki kodları boş bir `makineValidator.ts` dosyası açıp içerisine yapıştırın. Bu kod, gelen JSON dosyasının ilgili makinenin gereksinimlerini karşılayıp karşılamadığını Prisma veritabanı işleminden hemen önce denetler.

```typescript
import { IMakineOzellikleri, ICNCTeknikSpesifikasyon, IKompresorTeknikSpesifikasyon, IEnjeksiyonTeknikSpesifikasyon } from '../interfaces/makine.types';

export const validateMakineOzellikleri = (ozellikler: any): { success: boolean, errorMessage?: string } => {
    if (!ozellikler || typeof ozellikler !== 'object') {
        return { success: false, errorMessage: "makine_ozellikleri geçersiz veya eksik." };
    }

    if (!['CNC', 'KOMPRESOR', 'ENJEKSIYON', 'DIGER'].includes(ozellikler.tip)) {
        return { success: false, errorMessage: "Geçersiz makine tipi belirtildi. (Beklenen: CNC, KOMPRESOR, ENJEKSIYON, DIGER)" };
    }

    if (!ozellikler.teknik_spesifikasyonlar || typeof ozellikler.teknik_spesifikasyonlar !== 'object') {
        return { success: false, errorMessage: "teknik_spesifikasyonlar nesnesi eksik." };
    }

    if (typeof ozellikler.genel_bakim_periyodu_saat !== 'number' || ozellikler.genel_bakim_periyodu_saat <= 0) {
        return { success: false, errorMessage: "genel_bakim_periyodu_saat geçerli bir pozitif sayı olmalıdır." };
    }

    const { tip, teknik_spesifikasyonlar } = ozellikler as IMakineOzellikleri;

    // Tipe göre özel olan teknik_spesifikasyonları ayrıştırıp zorunlu alanları doğrularız
    switch (tip) {
        case 'CNC':
            const cncSpec = teknik_spesifikasyonlar as unknown as ICNCTeknikSpesifikasyon;
            if (typeof cncSpec.is_mili_hizi_rpm !== 'number') return { success: false, errorMessage: "CNC için is_mili_hizi_rpm (sayı) zorunludur." };
            if (typeof cncSpec.eksen_sayisi !== 'number') return { success: false, errorMessage: "CNC için eksen_sayisi (sayı) zorunludur." };
            break;
            
        case 'KOMPRESOR':
            const kompSpec = teknik_spesifikasyonlar as unknown as IKompresorTeknikSpesifikasyon;
            if (typeof kompSpec.maksimum_basinc_bar !== 'number') return { success: false, errorMessage: "KOMPRESOR için maksimum_basinc_bar (sayı) zorunludur." };
            if (typeof kompSpec.debi_m3_dk !== 'number') return { success: false, errorMessage: "KOMPRESOR için debi_m3_dk (sayı) zorunludur." };
            break;

        case 'ENJEKSIYON':
            const enjSpec = teknik_spesifikasyonlar as unknown as IEnjeksiyonTeknikSpesifikasyon;
            if (typeof enjSpec.mengene_kuvveti_ton !== 'number') return { success: false, errorMessage: "ENJEKSIYON için mengene_kuvveti_ton (sayı) zorunludur." };
            if (typeof enjSpec.enjeksiyon_hacmi_cm3 !== 'number') return { success: false, errorMessage: "ENJEKSIYON için enjeksiyon_hacmi_cm3 (sayı) zorunludur." };
            break;

        case 'DIGER':
            // Diğer tipler için şimdilik özel bir zorunluluk yok
            break;
    }

    return { success: true };
};
```

---

## 3. Kontrolcüye (Controller) Entegre Edilmesi
**Dosya:** `src/controllers/makineKontrol.ts`

Makinenin sisteme kayıt edildiği servise (örneğin `makineEkle` fonksiyonuna), yazdığımız doğrulama modülünü bağlayın. Prisma üzerinden veritabanına kayıt atılmadan önce (*req.body değerleri çekildikten hemen sonra*) bu fonksiyon çağrılmalıdır:

```typescript
// 1. Validator dosyamızı projenin tepesinde içe aktarıyoruz
import { validateMakineOzellikleri } from '../utils/makineValidator';
import { IMakineOzellikleri } from '../interfaces/makine.types';

export const makineEkle = async (req: Request, res: Response) => {
// ...
        const ozellikler = makine_ozellikleri as IMakineOzellikleri;

        // 2. Doğrulama Katmanı: Gelen özellikler denetleniyor
        if (ozellikler) {
            const valResult = validateMakineOzellikleri(ozellikler);
            // Eğer başarı durumu "false" ise işlemi durdurup hata dönderiyoruz.
            if (!valResult.success) {
                return res.status(400).json({ hata: valResult.errorMessage });
            }
        }

        // Eğer yukarıdaki adımdan başarıyla geçilirse
        // Normal Prisma create işleminize (...await prisma.makine.create) buradan itibaren devam edebilirsiniz.
// ...
```
