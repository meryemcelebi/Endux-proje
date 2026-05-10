import { Request, Response } from 'express';
import prisma from '../config/prisma';
import { averageOeeComponents, calculateOeeScore } from '../utils/oee';

export async function getMakineOee(makineId: number, baslangicTarihi: Date, bitisTarihi: Date) {
    const makine = await prisma.makine.findUnique({
        where: { makine_id: makineId },
        select: { makine_adi: true, makine_turu: true }
    });

    if (!makine) {
        throw new Error(`Makine bulunamadı : ${makineId}`);
    }

    // OEE Raporlarından Trend Verileri
    const oeeTrend = await prisma.oee_raporlari.findMany({
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
    const duruslar = await prisma.durus_kaydi.groupBy({
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
            oee_skoru: calculateOeeScore(
                t.kullanilabilirlik_orani,
                t.performans_orani,
                t.kalite_orani
            ) ?? t.oee_skoru
        })),
        durus_nedenleri: durusPastaGrafik
    };
}

// oee getir : get api tek oee
export async function oeeGetir(req: Request, res: Response) {
    try {
        const makineId = parseInt(req.params.id);
        const baslangic = req.query.baslangic as string;
        const bitis = req.query.bitis as string;

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
    } catch (error: any) {
        console.error("OEE getirme hatası:", error);
        res.status(500).json({ success: false, message: error.message || "OEE getirilirken bir hata oluştu." });
    }
}

// toplu oee getir : get api çoklu oee
export async function topluOeeGetir(req: Request, res: Response) {
    try {
        const baslangic = req.query.baslangic as string;
        const bitis = req.query.bitis as string;
        
        if (!baslangic || !bitis) {
            return res.status(400).json({ success: false, message: 'Başlangıç ve bitiş tarihleri gereklidir' });
        }
        
        const baslangicTarihi = new Date(baslangic);
        const bitisTarihi = new Date(bitis);

        if (isNaN(baslangicTarihi.getTime()) || isNaN(bitisTarihi.getTime())) {
            return res.status(400).json({ success: false, message: "Geçersiz tarih formatı." });
        }

        const makineler = await prisma.makine.findMany({
            where: { aktiflik_durumu: true },
            select: { makine_id: true, makine_adi: true },
        });

        const sonuclar: any[] = [];
        const hatalar: any[] = [];

        for (const makine of makineler) {
            try {
                const oee = await getMakineOee(makine.makine_id, baslangicTarihi, bitisTarihi);
                
                let avgOee = 0;
                let avgKull = 0;
                let avgPerf = 0;
                let avgKalite = 0;

                if (oee.oee_trend.length > 0) {
                    const averages = averageOeeComponents(oee.oee_trend, {
                        availability: val => val.kullanilabilirlik,
                        performance: val => val.performans,
                        quality: val => val.kalite,
                    });

                    avgOee = averages.oee;
                    avgKull = averages.availability;
                    avgPerf = averages.performance;
                    avgKalite = averages.quality;
                }

                sonuclar.push({
                    makine_id: oee.makine_id,
                    makine_adi: oee.makine_adi,
                    makine_turu: oee.makine_turu,
                    oee_skoru: avgOee,
                    kullanabilirlik: avgKull,
                    performans: avgPerf,
                    kalite: avgKalite,
                });
            } catch (err: any) {
                hatalar.push({
                    makine_id: makine.makine_id,
                    makine_adi: makine.makine_adi,
                    hata: err.message,
                });
            }
        }

        const fabrikaOrtalamalari = averageOeeComponents(sonuclar, {
            availability: s => s.kullanabilirlik,
            performance: s => s.performans,
            quality: s => s.kalite,
        });
            
        // Tüm raporları çekip haftalık trend oluştur
        const tumOeeKayitlari = await prisma.oee_raporlari.findMany({
            where: { tarih: { gte: baslangicTarihi, lte: bitisTarihi } },
            select: { tarih: true, kullanilabilirlik_orani: true, performans_orani: true, kalite_orani: true, oee_skoru: true }
        });

        // Verileri haftalara grupla
        const haftalikGruplar: Record<string, { a: number[], p: number[], q: number[] }> = {};
        
        tumOeeKayitlari.forEach(kayit => {
            if (!kayit.tarih) return;
            const diffTime = Math.abs(bitisTarihi.getTime() - kayit.tarih.getTime());
            const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));
            const haftaIndex = Math.floor(diffDays / 7); // 0 = Bu Hafta, 1 = Geçen Hafta, 2 = 3. Hafta vs. (geriye dönük)
            
            let weekLabel = "Bu Hafta";
            if (haftaIndex === 1) weekLabel = "Geçen H.";
            else if (haftaIndex > 1) weekLabel = `${haftaIndex + 1}. Hafta`;

            if (!haftalikGruplar[weekLabel]) haftalikGruplar[weekLabel] = { a: [], p: [], q: [] };
            
            if (kayit.kullanilabilirlik_orani != null) haftalikGruplar[weekLabel].a.push(kayit.kullanilabilirlik_orani);
            if (kayit.performans_orani != null) haftalikGruplar[weekLabel].p.push(kayit.performans_orani);
            if (kayit.kalite_orani != null) haftalikGruplar[weekLabel].q.push(kayit.kalite_orani);
        });

        const fabrika_trend = Object.keys(haftalikGruplar).map(week => {
            const getAvg = (arr: number[]) => arr.length ? parseFloat((arr.reduce((a,b) => a+b, 0) / arr.length).toFixed(1)) : 0;
            const g = haftalikGruplar[week];
            const a = getAvg(g.a);
            const p = getAvg(g.p);
            const q = getAvg(g.q);
            return {
                week,
                oee: calculateOeeScore(a, p, q, 1) ?? 0,
                a,
                p,
                q
            };
        }).reverse(); // Eskiden yeniye sıralamak için reverse()
            
        res.status(200).json({
            success: true,
            message: 'OEE skorları hesaplandı.',
            data: {
                fabrika_ortalama_oee: fabrikaOrtalamalari.oee,
                fabrika_bilesenleri: {
                    kullanilabilirlik: fabrikaOrtalamalari.availability,
                    performans: fabrikaOrtalamalari.performance,
                    kalite: fabrikaOrtalamalari.quality,
                },
                donem: { baslangic, bitis },
                fabrika_trend,
                makineler: sonuclar,
                hatali_makineler: hatalar,
            },
        });
    } catch (error: any) {
        console.error("Toplu OEE hesaplama hatası:", error);
        res.status(500).json({ success: false, message: error.message || "Toplu OEE hesaplanırken bir hata oluştu." });
    }
}
