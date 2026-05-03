"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getMakineOee = getMakineOee;
exports.oeeGetir = oeeGetir;
exports.topluOeeGetir = topluOeeGetir;
const prisma_1 = __importDefault(require("../config/prisma"));
async function getMakineOee(makineId, baslangicTarihi, bitisTarihi) {
    const makine = await prisma_1.default.makine.findUnique({
        where: { makine_id: makineId },
        select: { makine_adi: true, makine_turu: true }
    });
    if (!makine) {
        throw new Error(`Makine bulunamadı : ${makineId}`);
    }
    // OEE Raporlarından Trend Verileri
    const oeeTrend = await prisma_1.default.oee_raporlari.findMany({
        where: {
            makine_id: makineId,
            tarih: {
                gte: baslangicTarihi,
                lte: bitisTarihi,
            }
        },
        orderBy: {
            tarih: 'asc'
        },
        select: {
            tarih: true,
            kullanilabilirlik_orani: true,
            performans_orani: true,
            kalite_orani: true,
            oee_skoru: true
        }
    });
    // Duruş Kayıtlarından Pasta Grafik İçin Gruplama
    const duruslar = await prisma_1.default.durus_kaydi.groupBy({
        by: ['durus_nedeni'],
        where: {
            makine_id: makineId,
            vardiya_tarihi: {
                gte: baslangicTarihi,
                lte: bitisTarihi,
            }
        },
        _sum: {
            durus_sure_dk: true
        }
    });
    const durusPastaGrafik = duruslar.map(d => ({
        neden: d.durus_nedeni,
        toplam_sure_dk: d._sum.durus_sure_dk || 0
    }));
    return {
        makine_id: makineId,
        makine_adi: makine.makine_adi,
        makine_turu: makine.makine_turu.makine_tur_adi,
        tarih_araligi: {
            baslangic: baslangicTarihi.toISOString().split('T')[0],
            bitis: bitisTarihi.toISOString().split('T')[0]
        },
        oee_trend: oeeTrend.map(t => ({
            tarih: t.tarih ? t.tarih.toISOString().split('T')[0] : null,
            kullanilabilirlik: t.kullanilabilirlik_orani,
            performans: t.performans_orani,
            kalite: t.kalite_orani,
            oee_skoru: t.oee_skoru
        })),
        durus_nedenleri: durusPastaGrafik
    };
}
// oee getir : get api tek oee
async function oeeGetir(req, res) {
    try {
        const makineId = parseInt(req.params.id);
        const baslangic = req.query.baslangic;
        const bitis = req.query.bitis;
        if (isNaN(makineId)) {
            return res.status(400).json({ success: false, message: 'Geçersiz makine ID' });
        }
        if (!baslangic || !bitis) {
            return res.status(400).json({ success: false, message: 'Başlangıç ve bitiş tarihleri gereklidir' });
        }
        const baslangicTarihi = new Date(baslangic);
        const bitisTarihi = new Date(bitis);
        if (isNaN(baslangicTarihi.getTime()) || isNaN(bitisTarihi.getTime())) {
            return res.status(400).json({ success: false, message: "Geçersiz tarih formatı." });
        }
        if (baslangicTarihi > bitisTarihi) {
            return res.status(400).json({ success: false, message: "Başlangıç tarihi bitiş tarihinden sonra olamaz." });
        }
        const sonuc = await getMakineOee(makineId, baslangicTarihi, bitisTarihi);
        res.status(200).json({
            success: true,
            message: `${sonuc.makine_adi} makinesi için OEE hesaplandı.`,
            data: sonuc,
        });
    }
    catch (error) {
        console.error("OEE getirme hatası:", error);
        res.status(500).json({ success: false, message: error.message || "OEE getirilirken bir hata oluştu." });
    }
}
// toplu oee getir : get api çoklu oee
async function topluOeeGetir(req, res) {
    try {
        const baslangic = req.query.baslangic;
        const bitis = req.query.bitis;
        if (!baslangic || !bitis) {
            return res.status(400).json({ success: false, message: 'Başlangıç ve bitiş tarihleri gereklidir' });
        }
        const baslangicTarihi = new Date(baslangic);
        const bitisTarihi = new Date(bitis);
        if (isNaN(baslangicTarihi.getTime()) || isNaN(bitisTarihi.getTime())) {
            return res.status(400).json({ success: false, message: "Geçersiz tarih formatı." });
        }
        const makineler = await prisma_1.default.makine.findMany({
            where: { aktiflik_durumu: true },
            select: { makine_id: true, makine_adi: true },
        });
        const sonuclar = [];
        const hatalar = [];
        for (const makine of makineler) {
            try {
                const oee = await getMakineOee(makine.makine_id, baslangicTarihi, bitisTarihi);
                // Ortalama OEE hesapla (trend üzerinden)
                let avgOee = 0;
                let avgKull = 0;
                let avgPerf = 0;
                let avgKalite = 0;
                if (oee.oee_trend.length > 0) {
                    const totalOee = oee.oee_trend.reduce((acc, val) => acc + (val.oee_skoru || 0), 0);
                    const totalKull = oee.oee_trend.reduce((acc, val) => acc + (val.kullanilabilirlik || 0), 0);
                    const totalPerf = oee.oee_trend.reduce((acc, val) => acc + (val.performans || 0), 0);
                    const totalKalite = oee.oee_trend.reduce((acc, val) => acc + (val.kalite || 0), 0);
                    avgOee = totalOee / oee.oee_trend.length;
                    avgKull = totalKull / oee.oee_trend.length;
                    avgPerf = totalPerf / oee.oee_trend.length;
                    avgKalite = totalKalite / oee.oee_trend.length;
                }
                sonuclar.push({
                    makine_id: oee.makine_id,
                    makine_adi: oee.makine_adi,
                    makine_turu: oee.makine_turu,
                    oee_skoru: parseFloat(avgOee.toFixed(2)),
                    kullanabilirlik: parseFloat(avgKull.toFixed(2)),
                    performans: parseFloat(avgPerf.toFixed(2)),
                    kalite: parseFloat(avgKalite.toFixed(2)),
                });
            }
            catch (err) {
                hatalar.push({
                    makine_id: makine.makine_id,
                    makine_adi: makine.makine_adi,
                    hata: err.message,
                });
            }
        }
        const ortalamaOee = sonuclar.length > 0
            ? parseFloat((sonuclar.reduce((acc, s) => acc + s.oee_skoru, 0) / sonuclar.length).toFixed(2))
            : 0;
        // Tüm raporları çekip haftalık trend oluştur
        const tumOeeKayitlari = await prisma_1.default.oee_raporlari.findMany({
            where: { tarih: { gte: baslangicTarihi, lte: bitisTarihi } },
            select: { tarih: true, kullanilabilirlik_orani: true, performans_orani: true, kalite_orani: true, oee_skoru: true }
        });
        // Verileri haftalara grupla
        const haftalikGruplar = {};
        tumOeeKayitlari.forEach(kayit => {
            if (!kayit.tarih)
                return;
            const diffTime = Math.abs(bitisTarihi.getTime() - kayit.tarih.getTime());
            const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));
            const haftaIndex = Math.floor(diffDays / 7); // 0 = Bu Hafta, 1 = Geçen Hafta, 2 = 3. Hafta vs. (geriye dönük)
            let weekLabel = "Bu Hafta";
            if (haftaIndex === 1)
                weekLabel = "Geçen H.";
            else if (haftaIndex > 1)
                weekLabel = `${haftaIndex + 1}. Hafta`;
            if (!haftalikGruplar[weekLabel])
                haftalikGruplar[weekLabel] = { oee: [], a: [], p: [], q: [] };
            if (kayit.oee_skoru)
                haftalikGruplar[weekLabel].oee.push(kayit.oee_skoru);
            if (kayit.kullanilabilirlik_orani)
                haftalikGruplar[weekLabel].a.push(kayit.kullanilabilirlik_orani);
            if (kayit.performans_orani)
                haftalikGruplar[weekLabel].p.push(kayit.performans_orani);
            if (kayit.kalite_orani)
                haftalikGruplar[weekLabel].q.push(kayit.kalite_orani);
        });
        const fabrika_trend = Object.keys(haftalikGruplar).map(week => {
            const getAvg = (arr) => arr.length ? parseFloat((arr.reduce((a, b) => a + b, 0) / arr.length).toFixed(1)) : 0;
            const g = haftalikGruplar[week];
            return {
                week,
                oee: getAvg(g.oee),
                a: getAvg(g.a),
                p: getAvg(g.p),
                q: getAvg(g.q)
            };
        }).reverse(); // Eskiden yeniye sıralamak için reverse()
        res.status(200).json({
            success: true,
            message: 'OEE skorları hesaplandı.',
            data: {
                fabrika_ortalama_oee: ortalamaOee,
                donem: { baslangic, bitis },
                fabrika_trend,
                makineler: sonuclar,
                hatali_makineler: hatalar,
            },
        });
    }
    catch (error) {
        console.error("Toplu OEE hesaplama hatası:", error);
        res.status(500).json({ success: false, message: error.message || "Toplu OEE hesaplanırken bir hata oluştu." });
    }
}
