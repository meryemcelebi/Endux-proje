import { Request, Response } from "express";
import prisma from "../config/prisma";



// 1 - 5 arasında servise puan verilir, 5 en yüksek puandır

export async function servisPuanVer(req: Request, res: Response) {
    try {
        const { servis_firma_id, puan, yorum } = req.body;
        const puanlayanID = Number(req.user?.userId);

        if (!servis_firma_id || puan === undefined || puan === null) {
            res.status(400).json({
                success: false,
                message: "Servis firma ID'si ve puan alanları zorunludur."
            });
            return;
        }
        const puanDegeri = Number(puan);
       
        // puan yerine puanDegeri üzerinden kontrol ediyoruz
          
        if (Number.isNaN(puanDegeri) || !Number.isInteger(puanDegeri) || puanDegeri < 1 || puanDegeri > 5) {
           res.status(400).json({
             success: false,
             message: "Puan 1 ile 5 arasında olmalıdır ve tam sayı olmalıdır."
           });
        return;
        }

        //servis firma var mı 
        const servisFirma = await prisma.servis_firma.findUnique({
            where: { servis_firma_id: Number(servis_firma_id) }
        });
        if (!servisFirma) {
            res.status(404).json({
                success: false,
                message: "Belirtilen ID'ye sahip servis firması bulunamadı."
            });
            return;
        }
        const sonuc = await prisma.$transaction(async (tx) => {

            //puan kaydı oluştur
            const yeniPuan = await tx.servis_puan.create({
                data: {
                    servis_firma_id: Number(servis_firma_id),
                    puan: puanDegeri,
                    yorum: yorum ? String(yorum) : null,
                    puanlayan_kullanici_id: puanlayanID,
                    tarih: new Date()
                }
            });

            return yeniPuan;
        });
        res.status(201).json({
            success: true,
            message: 'Puan başarıyla verildi.',
            data: sonuc
        });
    }

    catch (error) {
        console.error("Puan verme hatası:", error);
        res.status(500).json({
            success: false,
            message: 'Puan verirken bir hata oluştu.'
        });
    }
}



export async function tedarikciPuanVer(req: Request, res: Response) {
    try {
        const { tedarikci_id, puan, yorum } = req.body;
        const puanlayanID = Number(req.user?.userId);
        if (!tedarikci_id || puan === undefined || puan === null) {
            res.status(400).json({
                success: false,
                message: "Tedarikçi ID'si ve puan alanları zorunludur."
            });
            return;
        }
        const puanDegeri = Number(puan);

     // puan yerine puanDegeri üzerinden kontrol ediyoruz
       if (Number.isNaN(puanDegeri) || !Number.isInteger(puanDegeri) || puanDegeri < 1 || puanDegeri > 5) {
           res.status(400).json({
             success: false,
             message: "Puan 1 ile 5 arasında olmalıdır ve tam sayı olmalıdır."
            });
           return;
        }

        //tedarikçi var mı
        const tedarikci = await prisma.tedarikci.findUnique({
            where: { tedarikci_id: Number(tedarikci_id) }
        });
        if (!tedarikci) {
            res.status(404).json({
                success: false,
                message: "Belirtilen ID'ye sahip tedarikçi bulunamadı."
            });
            return;
        }
        const sonuc = await prisma.$transaction(async (tx) => {
            //puan kaydı oluştur
            const yeniPuan = await tx.tedarikci_puan.create({
                data: {
                    tedarikci_id: Number(tedarikci_id),
                    puan: puanDegeri,
                    yorum: yorum ? String(yorum) : null,
                    puanlayan_kullanici_id: puanlayanID,
                    tarih: new Date()
                }
            });
            return yeniPuan;
        });
        res.status(201).json({
            success: true,
            message: 'Puan başarıyla verildi.',
            data: sonuc
        });
    } catch (error) {
        console.error("Puan verme hatası:", error);
        res.status(500).json({
            success: false,
            message: 'Puan verirken bir hata oluştu.'
        });
    }
};

