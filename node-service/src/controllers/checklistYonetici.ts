import { Request, Response, NextFunction } from "express";
import prisma from "../config/prisma";

//operatorlerden gelen form verilerini database'e ekler:

export async function formKaydet(req:Request , res:Response ,next:NextFunction): Promise<void> {
    try {
        const {makine_id, sablon_id, genel_not,cevaplar} = req.body;
        // Token'dan giriş yapan operatörün ID'sini alıyoruz
        const operator_id=Number(req.user?.userId);

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