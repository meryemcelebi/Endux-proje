import { Request, Response } from "express";
import prisma from "../config/prisma";
import { Decimal } from "@prisma/client/runtime/client";


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
                succes: false,
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

        //toplam onarım maliyeti
        const toplamOnarimMaliyeti = toplamBakimMaliyeti + toplamParcaMaliyeti;

        //maliyet oranı yüzdesi
        const maliyetOraniYuzdesi = satinAlmaMaliyeti > 0
            //bölme hatası almamak için satinAlmaMaliyeti sıfırdan büyükse hesaplama yapıyoruz
            ? parseFloat(((toplamOnarimMaliyeti / satinAlmaMaliyeti) * 100).toFixed(2))
            : 0;

        res.status(200).json({
            succes: true,
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
            succes: false,
            message: "Maliyet analizi sırasında bir hata oluştu"
        });
    }

};


