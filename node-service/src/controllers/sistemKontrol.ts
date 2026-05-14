import { Request, Response } from "express";
import prisma from "../config/prisma";

//firma listesi API 
export const siralaFirmalar = async (req: Request, res: Response) => {
    try {
        const firmalar = await prisma.firma.findMany({ select: { firma_id: true, firma_adi: true } });
        res.json({ success: true, firmalar });
    } catch (error) {
        res.status(500).json({ success: false, message: "Firmalar listelenirken bir hata oluştu." });
    }
};

//rol listesi API
export const siralaRoller = async (req: Request, res: Response) => {
    try {
        const roller = await prisma.rol.findMany({ select: { rol_id: true, rol_adi: true } });
        res.json({ success: true, roller });
    } catch (error) {
        res.status(500).json({ success: false, message: "Roller listelenirken bir hata oluştu." });
    }

};
//makine türleri listesi API
export const siralaMakineTurleri = async (req: Request, res: Response) => {
    try {
        const makineTurleri = await prisma.makine_turu.findMany({ select: { makine_tur_id: true, makine_tur_adi: true, periyodik_bakim_saati: true } });
        res.json({ success: true, makineTurleri });
    } catch (error) {
        res.status(500).json({ success: false, message: "Makine türleri listelenirken bir hata oluştu." });
    }
};

//ariza türleri listesi API
export const siralaArizaTurleri = async (req: Request, res: Response) => {
    try {
        const makine_tur_id = req.query.makine_tur_id;
        let whereClause = {};
        if (makine_tur_id) {
             whereClause = {
                  OR: [
                      { makine_tur_id: Number(makine_tur_id) },
                      { makine_tur_id: null }
                  ]
             };
        }
        const arizaTurleri = await prisma.ariza_turu.findMany({ 
             where: whereClause,
             select: { ariza_tur_id: true, ariza_tur: true } 
        });
        res.json({ success: true, arizaTurleri });
    } catch (error) {
        res.status(500).json({ success: false, message: "Arıza türleri listelenirken bir hata oluştu." });
    }
};
