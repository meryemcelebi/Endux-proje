"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.hesaplaDurusSuresi = hesaplaDurusSuresi;
exports.otomatikDurusSuresiHesapla = otomatikDurusSuresiHesapla;
const prisma_1 = __importDefault(require("../config/prisma"));
/**
 * İki tarih arasındaki duruş süresini vardiya saatlerine göre hesaplar.
 * Sadece vardiya saatleri içinde kalan süreler sayılır.
 *
 * @param baslangic - Makinenin durduğu an (bakım kaydı oluşturulma zamanı)
 * @param bitis - Bakımın tamamlandığı an
 * @param vardiyalar - Vardiya tanımları [{baslangic_saati: "08:00", bitis_saati: "17:00"}, ...]
 * @returns Toplam duruş süresi (saat cinsinden)
 */
function hesaplaDurusSuresi(baslangic, bitis, vardiyalar) {
    if (!baslangic || !bitis || bitis <= baslangic || !vardiyalar.length) {
        return 0;
    }
    let toplamDakika = 0;
    // Gün gün iterasyon yapılacak aralığı belirle
    const gunBaslangic = new Date(baslangic);
    gunBaslangic.setHours(0, 0, 0, 0);
    const gunBitis = new Date(bitis);
    gunBitis.setHours(0, 0, 0, 0);
    // Gece vardiyası bir sonraki güne taşabileceği için +1 gün ekle
    gunBitis.setDate(gunBitis.getDate() + 1);
    const currentDay = new Date(gunBaslangic);
    while (currentDay <= gunBitis) {
        for (const vardiya of vardiyalar) {
            const [vbSaat, vbDakika] = vardiya.baslangic_saati.split(':').map(Number);
            const [vsSaat, vsDakika] = vardiya.bitis_saati.split(':').map(Number);
            // Vardiya başlangıç zamanını oluştur
            const vardiyaBaslangic = new Date(currentDay);
            vardiyaBaslangic.setHours(vbSaat, vbDakika, 0, 0);
            // Vardiya bitiş zamanını oluştur
            const vardiyaBitis = new Date(currentDay);
            vardiyaBitis.setHours(vsSaat, vsDakika, 0, 0);
            // Gece vardiyası kontrolü: bitiş saati < başlangıç saati ise ertesi güne taşar
            // Örn: 17:00-01:00 → bitiş ertesi gün 01:00
            if (vardiyaBitis <= vardiyaBaslangic) {
                vardiyaBitis.setDate(vardiyaBitis.getDate() + 1);
            }
            // Kesişim hesapla: max(vardiyaBaslangic, baslangic) — min(vardiyaBitis, bitis)
            const kesisimBaslangic = new Date(Math.max(vardiyaBaslangic.getTime(), baslangic.getTime()));
            const kesisimBitis = new Date(Math.min(vardiyaBitis.getTime(), bitis.getTime()));
            if (kesisimBitis > kesisimBaslangic) {
                const dakikaFarki = (kesisimBitis.getTime() - kesisimBaslangic.getTime()) / (1000 * 60);
                toplamDakika += dakikaFarki;
            }
        }
        // Sonraki güne geç
        currentDay.setDate(currentDay.getDate() + 1);
    }
    // Saat cinsinden döndür (2 ondalık basamak)
    return Math.round((toplamDakika / 60) * 100) / 100;
}
/**
 * Veritabanından vardiya saatlerini çeker ve duruş süresini hesaplar.
 * Controller'lardan doğrudan çağrılabilir.
 */
async function otomatikDurusSuresiHesapla(baslangic, bitis) {
    const vardiyalar = await prisma_1.default.vardiya_saatleri.findMany({
        select: {
            baslangic_saati: true,
            bitis_saati: true
        }
    });
    if (!vardiyalar.length) {
        // Vardiya tanımı yoksa ham saat farkını döndür
        const saatFarki = (bitis.getTime() - baslangic.getTime()) / (1000 * 60 * 60);
        return Math.round(saatFarki * 100) / 100;
    }
    return hesaplaDurusSuresi(baslangic, bitis, vardiyalar);
}
