import { Request, Response } from "express";
import { v4 as uuidv4 } from "uuid";
import prisma from "../config/prisma";

export const makineEkle= async (req : Request, res : Response) => {
    try {
        const { 
    makine_ad, 
    firma_id, 
    m_tur_id, 
    seri_no, 
    satin_alma_tarihi, 
    satin_alma_maliyeti, 
    aktiflik_durumu 
} = req.body;

 if (!makine_ad || !firma_id || !m_tur_id || !seri_no || !satin_alma_tarihi || !satin_alma_maliyeti || aktiflik_durumu===undefined) {
        return res.status(400).json({ hata: "Tüm alanlar zorunludur." });
    }
if (typeof satin_alma_maliyeti !== "number") {
        return res.status(400).json({ hata: "Satin alma maliyeti sayısal bir değer olmalıdır." });
    }   
if (typeof aktiflik_durumu !== "boolean") {
        return res.status(400).json({ hata: "Aktiflik durumu boolean (true/false) olmalıdır." });
    }
if (Array.isArray(seri_no)&& seri_no.length === 0) {
        return res.status(400).json({ hata: "En az bir adet seri numarası girilmelidir." });
    
    }

const yeniMakine = await prisma.makine.create({
    data: {
    makine_ad: makine_ad,
    firma_id:Number(firma_id),
    m_tur_id:Number(m_tur_id),
    seri_no:Array.isArray(seri_no) ? seri_no : [seri_no],
    satin_alma_tarihi: new Date(satin_alma_tarihi),
    satin_alma_maliyeti:Number(satin_alma_maliyeti),
    aktiflik_durumu:Boolean(aktiflik_durumu),
    makine_qr:uuidv4(),
    mevcut_risk_skoru: 0, // Başlangıç risk skoru (Zorunlu alan)
    top_cal_sma_saati: [],
    makine_ozellikleri: []
    }
});
res.status(201).json({ message: "Makine başarıyla eklendi.", makine: yeniMakine });
    
}
catch (error) {
         res.status(500).json({success: false,
             message: "Makine eklenirken bir hata oluştu." 
            });
    }}




export const qrileMakineGetir = async (req: Request, res: Response) => {
    try {
        const {qr_uuid} = req.params; //istekten QR kodu parametresini al
        const makine =await prisma.makine.findUnique({
            where: {
                makine_qr: qr_uuid
            },
                include: {
                firma: true,
                makine_turu: true,
                bakim_kaydi: true,
                gunluk_kontrol_formu: true,
                makine_kullanim: true,
                ariza_kaydi: true
            }


        });
        if (!makine) {
            return res.status(404).json({ success: false, message: "Makine bulunamadı." });
        }
        res.status(200).json({ success: true, makine });
    } catch (error) {
        res.status(500).json({ success: false, message: "Makine getirilirken bir hata oluştu." });
    }
};