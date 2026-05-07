import { Request, Response } from "express";
import prisma from "../config/prisma";
import { Decimal } from "@prisma/client/runtime/client";
import { parse } from "path";


export async function maliyetAnalizi(req: Request, res: Response) {
    try {
        const makineId = parseInt(req.params.id);
        if (isNaN(makineId)) {
            return res.status(404).json({
                success: false,
                message: "Geçersiz makine ID'si"
            });

        }

        const makine = await prisma.makine.findUnique({
            where: { makine_id: makineId },
            include: {
                bakim_kaydi: {
                    include: {
                        parca_degisim: {
                            include: {
                                parca: true
                            }
                        }
                    }
                }
            }
        });
        if (!makine) {
            return res.status(404).json({
                success: false,
                message: "Belirtilen ID ile makine bulunamadı"
            });

        }
        const satinAlmaMaliyeti = Number(makine.satin_alma_maliyeti);

        let toplamBakimMaliyeti = 0;
        for (const bakim of makine.bakim_kaydi) {
            // bakim_maliyet DB'de scalar (numeric)
            toplamBakimMaliyeti += Number(bakim.bakim_maliyet);
        }

        let toplamParcaMaliyeti = 0;

        for (const bakim of makine.bakim_kaydi) {
            for (const degisim of bakim.parca_degisim) {
                // parca_maliyeti parca tablosunda — parca ilişkisi üzerinden erişim
                toplamParcaMaliyeti += Number(degisim.parca?.parca_maliyeti ?? 0);
            }
        }

        // Toplam onarım maliyeti
        const toplamOnarimMaliyeti = toplamBakimMaliyeti + toplamParcaMaliyeti;

        // Maliyet oranı yüzdesi
        const maliyetOraniYuzdesi = satinAlmaMaliyeti > 0
            // Bölme hatası almamak için satinAlmaMaliyeti sıfırdan büyükse hesaplama yapıyoruz
            ? parseFloat(((toplamOnarimMaliyeti / satinAlmaMaliyeti) * 100).toFixed(2))
            : 0;

        res.status(200).json({
            success: true,
            data: {
                makine_id: makineId,
                makine_adi: makine.makine_adi,
                satin_alma_maliyeti: satinAlmaMaliyeti,
                toplam_bakim_maliyeti: parseFloat(toplamBakimMaliyeti.toFixed(2)),
                toplam_parca_maliyeti: parseFloat(toplamParcaMaliyeti.toFixed(2)),
                toplam_onarim_maliyeti: parseFloat(toplamOnarimMaliyeti.toFixed(2)),
                maliyet_orani_yuzdesi: maliyetOraniYuzdesi,
                toplam_bakim_sayisi: makine.bakim_kaydi.length
            }
        });
    } catch (error) {
        console.error("Maliyet analizi hatası:", error);
        res.status(500).json({
            success: false,
            message: "Maliyet analizi sırasında bir hata oluştu"
        });
    }

};


/***
 * Maliyet Renk Kuralı
 * >%10 ise kırmızı
 * >%5 ise sarı
 * 2% -5% Turuncu
 * %2 ise yeşil
 */

export async function lokasyonHaritasi(req: Request, res: Response): Promise<void> {
    try {
        const katFilter = req.query.kat as string | undefined;
        const firmaFilter = req.query.firma_id ? Number(req.query.firma_id) : undefined;

        const makineler = await prisma.makine.findMany({
            where: {
                ...(firmaFilter ? { firma_id: firmaFilter } : {}),
                aktiflik_durumu: true,
            },
            select: {
                makine_id: true,
                makine_adi: true,
                seri_no: true,
                satin_alma_maliyeti: true,
                aktiflik_durumu: true,
                makine_turu: {
                    select: {
                        makine_tur_adi: true,

                    }
                },

                lokasyon: {
                    select: {
                        lokasyon_id: true,
                        fabrika_alani: true,
                        x_koor: true,
                        y_koor: true,
                        kat: true,

                    }
                },
                bakim_kaydi: {
                    select: {
                        bakim_maliyet: true,
                        parca_degisim: {
                            select: {
                                parca: {
                                    select: {
                                        parca_maliyeti: true
                                    }
                                }
                            }
                        }


                    }
                },
                risk_skoru: {
                    orderBy: { hesaplama_tarihi: 'desc' },
                    take: 1,
                    select: {
                        risk_skoru: true,
                        risk_seviyesi: true,

                    }
                }


            }

        });
        // Harita verileri

        // harita verileri
        const haritaVerisi = makineler
            .filter((m) => {
                if (katFilter) return m.lokasyon.some((l) => l.kat === katFilter);
                return true;
            })
            .map((m) => {
                const satinAlma = Number(m.satin_alma_maliyeti || 0);
                let toplamBakimMaliyeti = 0;
                let toplamParcaMaliyeti = 0;

                for (const bakim of m.bakim_kaydi) {
                    toplamBakimMaliyeti += Number(bakim.bakim_maliyet || 0);
                    for (const degisim of bakim.parca_degisim) {
                        // Düzeltildi: Parça maliyeti doğrudan ilişkili tablodan çekiliyor
                        toplamParcaMaliyeti += Number(degisim.parca?.parca_maliyeti ?? 0);
                    }
                }

                const toplamOnarim = toplamBakimMaliyeti + toplamParcaMaliyeti;
                const maliyetOrani = satinAlma > 0 ? (toplamOnarim / satinAlma) * 100 : 0;

                //renk belirleme 
                let renk: string;
                if (maliyetOrani > 10) renk = 'KIRMIZI';
                else if (maliyetOrani > 5) renk = 'SARI';
                else if (maliyetOrani >= 2) renk = 'TURUNCU';
                else renk = 'YESIL';

                const lokasyon = m.lokasyon[0] || null;
                const sonRisk = m.risk_skoru[0] || null;

                return {
                    makine_id: m.makine_id,
                    makine_adi: m.makine_adi,
                    seri_no: m.seri_no,
                    // Düzeltildi: makine_turu null gelme ihtimaline karşı optional chaining (?) eklendi
                    makine_turu: m.makine_turu?.makine_tur_adi || 'Tanımsız',
                    kat: lokasyon?.kat || null,
                    fabrika_alani: lokasyon?.fabrika_alani || null,
                    x: lokasyon ? Number(lokasyon.x_koor) : null,
                    y: lokasyon ? Number(lokasyon.y_koor) : null,
                    satin_alma_maliyeti: parseFloat(satinAlma.toFixed(2)), // "maaliyeti" yazım yanlışı düzeltildi
                    toplam_onarim_maliyeti: parseFloat(toplamOnarim.toFixed(2)),
                    maliyet_orani_yuzdesi: parseFloat(maliyetOrani.toFixed(2)),
                    renk: renk,
                    risk_skoru: sonRisk?.risk_skoru ? Number(sonRisk.risk_skoru) : null,
                    risk_seviyesi: sonRisk?.risk_seviyesi ?? null,
                };
            });

        //katlara göre gruplama
        const katMap: Record<string, typeof haritaVerisi> = {};
        for (const item of haritaVerisi) {
            const kat = item.kat || 'TANIMSIZ';
            if (!katMap[kat]) katMap[kat] = [];
            katMap[kat].push(item);

        }
        res.status(200).json({
            success: true,
            message: `${haritaVerisi.length} makine için lokasyon haritası oluşturuldu.`,
            data: {
                toplam_makine: haritaVerisi.length,
                katlar: katMap,
                tum_makineler: haritaVerisi,
            }
        });


    } catch (error) {
        console.error("Lokasyon haritası oluşturma hatası:", error);
        res.status(500).json({
            success: false,
            message: "Lokasyon haritası oluşturulurken bir hata oluştu."
        });
    }
}







