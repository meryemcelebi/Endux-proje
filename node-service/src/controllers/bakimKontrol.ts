import {Request, Response} from 'express';
import prisma from '../config/prisma';
import { arrayBuffer } from 'node:stream/consumers';
import { Decimal } from '@prisma/client/runtime/client';


export const bakimKaydiGir=async (req: Request, res: Response) => {
    try {
        const {makine_id, bakim_turu, aciklama, durus_suresi, servis_firma_id, ariza_id, bakim_maliyet, degisen_Parcalar}=req.body;
        if (!makine_id || !bakim_turu || !aciklama || !durus_suresi || !servis_firma_id || !ariza_id || !bakim_maliyet) {
            return res.status(400).json({error: 'Tüm alanlar zorunludur.'});
        }
        const teknisyenID=parseInt(req.user!.userId);
        const sonuc=await prisma.$transaction(async (tx) => {
            const bakimKaydi=await tx.bakim_kaydi.create({
                data: {
                    makine_id:Number(makine_id),
                    kullanici_id:teknisyenID,
                    bakim_turu:Array.isArray(bakim_turu) ? bakim_turu.join(',') : bakim_turu,
                    servis_firma_id:Number(servis_firma_id),
                    ariza_id:Number(ariza_id),
                    durus_suresi:durus_suresi ? new Date(durus_suresi) : null,
                    bakim_tarihi:[new Date()],
                    aciklama: aciklama || null,
                    bakim_maliyet:  Array.isArray(bakim_maliyet)
                                         ? bakim_maliyet.map(Number)
                                         : [Number(bakim_maliyet || 0)],
                                         
                    
                },
            });
            //degisen parçaların kaydedilmesi
            if (degisen_Parcalar && Array.isArray(degisen_Parcalar) && degisen_Parcalar.length > 0) {
                //createMany kullanarak toplu ekleme yapabiliriz
                 await tx.parca_degisim.createMany({
                    data: degisen_Parcalar.map((parca: any) => ({
                        bakim_id: bakimKaydi.bakim_id, //yeni oluşturulan bakım kaydının ID'si
                        parca_id: Number(parca.parca_id),
                        tedarikci_id: Number(parca.tedarikci_id),
                        parca_maliyeti:Number(parca.parca_maliyeti),
                        tedarik_gun_suresi:Number(parca.tedarik_gun_suresi),
                        makine_id:Number(makine_id),
                    })),
                });
            }
            return bakimKaydi;
        });
        res.status(201).json({success: true,
            message: 'Bakım kaydı başarıyla oluşturuldu.',
             data: sonuc});
    } catch (error) {
        console.error('Bakım kaydı oluşturulurken hata:', error);
        res.status(500).json({error: 'Bakım kaydı oluşturulurken bir hata oluştu.'});
    }
};



export const makineBakimKaytlari=async (req: Request, res: Response) => {
    try {
        const makineId=req.params.makine_id;    
        if(isNaN(Number(makineId))){   
            return res.status(400).json({error: 'Geçersiz makine ID.'});
        }      
        const makineVar=await prisma.makine.findUnique({
            where:{makine_id:Number(makineId)},
        });
        if(!makineVar){
            return res.status(404).json({error: 'Belirtilen ID ile makine bulunamadı.'});

        }
        //findMany kullanarak makineye ait tüm bakım kayıtlarını çekelim
        //include ile ilişkili tablolaları cekelim
        const bakimlar=await prisma.bakim_kaydi.findMany({
            where:{makine_id:Number(makineId)},
            include:{
                //bakım sırasında değişen parçalar
                parca_degisim:{
                    include:{
                        parca:true,  //değişen parçanın detayları
                        tedarikci:true //değişen parçanın tedarikçi bilgileri
                    }, },
                    //bakımı yaoan servis firmasının bilgileri
                    servis_firma:true,
                    //bakımı yapan teknisyenin bilgileri
                    kullanici:{
                        select:{
                            kullanici_id:true,
                            ad:true,
                            soyad:true
                        }
                    }


                },
                //orderBy
                orderBy:{
                    bakim_tarihi:'desc'
                }
        });
        res.status(200).json({success: true,
            message:'Makine #${makineId} için ${bakimlar.length} adet bakım kaydı bulundu.',
            data: bakimlar
        })
    } catch (error) {
        console.error('Bakım kayıtları çekilirken hata:', error);
        res.status(500).json({error: 'Bakım kayıtları çekilirken bir hata oluştu.'});
    }
};


                    
