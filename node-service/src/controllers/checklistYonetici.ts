import { Request, Response, NextFunction } from "express";
import prisma from "../config/prisma";

//operatorlerden gelen form verilerini database'e ekler:

export async function formKaydet(req:Request , res:Response ,next:NextFunction): Promise<void> {
    try {
        const {makine_id, sablon_id, genel_not,cevaplar} = req.body;
        // Token'dan giriş yapan operatörün ID'sini alıyoruz
        const operator_id=Number(req.user?.userId);
         if (!makine_id || !sablon_id) {
            res.status(400).json({ success: false, hata: "Makine ID ve Şablon ID zorunludur." });
            return;
        }

        if (!Array.isArray(cevaplar) || cevaplar.length === 0) {
            res.status(400).json({ success: false, hata: "Geçerli bir cevap listesi sunulmadı." });
            return;
        }

        if (!operator_id) {
            res.status(401).json({success:false, message:"Kullanici kimliği bulunamadi."});
            return;
        }
        const yeniForm=await prisma.$transaction(async (tx) => {
            //Ana form kaydı oluştur
            const form=await tx.gunluk_kontrol_formu.create({
                data:{
                    makine_id: Number(makine_id),
                    kullanici_id: operator_id,
                    sablon_id: Number(sablon_id),
                    genel_not
                }
            });

            if(cevaplar && cevaplar.length > 0){
                const islenecekCevaplar=cevaplar.map((c: any) => ({
                    form_id:form.form_id,
                    madde_id:Number(c.madde_id),
                    girilen_deger:c.girilen_deger,
                    durum:c.durum
                }));
                await tx.form_madde_cevap.createMany({
                    data:islenecekCevaplar
                });
            }
            return form;
        });
        res.status(201).json({
            success:true,
            message:" Form başarıyla kaydedildi.",
            data:{form_id:yeniForm.form_id }

        })


        }
        
        catch (error) {
            console.error("Form kaydetme hatası:", error);
            res.status(500).json({ success: false, message: "Form kaydedilirken bir hata oluştu." });
        }
    }


export async function sablonGetir(req:Request , res:Response ,next:NextFunction): Promise<void> {
    try {
        const sablon_id=Number(req.params.sablon_id);//sablon_id'yi parametrelerden alıyoruz
        const sablon=await prisma.kontrol_sablonu.findUnique({
            where:{sablon_id},
            include:{
                kontrol_maddesi:true //sablonla ilişkili maddeleri de getiriyoruz ??? 
            }
        });
        if(!sablon){
            res.status(404).json({success:false, message:"Sablon bulunamadi."});
            return;
        }
        res.status(200).json({success:true, data:sablon});
    } catch (error) {
        console.error("Sablon getirme hatası:", error);
        res.status(500).json({ success: false, message: "Sablon getirilirken bir hata oluştu." });
    }
    
}

// QR Kod Okutulduğunda Makineyi Bulup Form Şablonunu Döndüren Endpoint (YENI EKLENDI)
export async function qrIleSablonGetir(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
        const makine_qr = req.params.makine_qr;

        // 1. Zincirin İlk Halkası: Makineyi QR kodundan bul
        const makine = await prisma.makine.findUnique({
            where: { makine_qr }
        });

        if (!makine) {
            res.status(404).json({ success: false, message: "Bu QR koda ait makine bulunamadı." });
            return;
        }

        // 2. Zincirin İkinci Halkası: Bulunan makinenin türüne (m_tur_id) ait aktif şablonu getir
        const sablon = await prisma.kontrol_sablonu.findFirst({
            where: { 
                makine_tur_id: makine.m_tur_id,
                aktiflik: true
            },
            include: {
                kontrol_maddesi: true // Şablona ait tüm soruları (Genel ve Özel) getir
            }
        });

        if (!sablon) {
            res.status(404).json({ success: false, message: "Bu makine türü için tanımlanmış aktif bir form şablonu bulunamadı." });
            return;
        }

        // 3. Ekrana Çizilmesi İçin Frontend'e Veriyi Döndür
        res.status(200).json({
            success: true,
            data: {
                makine_id: makine.makine_id,
                makine_ad: makine.makine_ad,
                seri_no: makine.seri_no,
                sablon_id: sablon.sablon_id,
                sablon_adi: sablon.sablon_adi,
                sorular: sablon.kontrol_maddesi
            }
        });

    } catch (error) {
        console.error("QR ile şablon getirme hatası:", error);
        res.status(500).json({ success: false, message: "Şablon getirilirken bir hata oluştu." });
    }
}