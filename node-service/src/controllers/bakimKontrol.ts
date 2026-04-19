import { Request, Response } from 'express';
import prisma from '../config/prisma';
import { Decimal } from '@prisma/client/runtime/client';



export const bakimKaydiGir = async (req: Request, res: Response) => {
    try {
        const {
            makine_id,
            bakim_tur_id,
            aciklama,
            durus_suresi,
            servis_firma_id,
            ariza_id,
            bakim_maliyet,
            sorumlu_id,
            degisen_Parcalar } = req.body;


        if (!makine_id || !bakim_maliyet || !sorumlu_id || !servis_firma_id) {
            return res.status(400).json({ error: 'makine_id, bakim_maliyet, teknisyen_id ve servis_firma_id zorunludur.' });
        }


        const sonuc = await prisma.$transaction(async (tx) => {
            const bakimKaydi = await tx.bakim_kaydi.create({
                data: {
                    makine_id: Number(makine_id),
                    sorumlu_id: Number(sorumlu_id),
                    servis_firma_id: Number(servis_firma_id),
                    ariza_id: ariza_id ? Number(ariza_id) : undefined,
                    // bakim_turu string değil — bakim_tur_id FK olarak integer
                    bakim_tur_id: bakim_tur_id ? Number(bakim_tur_id) : undefined,
                    bakim_maliyet: Number(bakim_maliyet),
                    durus_suresi: durus_suresi ? Decimal(durus_suresi) : null,
                    aciklama: aciklama || null,
                    bakim_tarihi: new Date(),
                },
            });
            // degisen parçaların kaydedilmesi
            // parca_degisim tablosu sadece 3 kolon içerir: parca_degisim_id, bakim_id, parca_id
            if (degisen_Parcalar && Array.isArray(degisen_Parcalar) && degisen_Parcalar.length > 0) {
                await tx.parca_degisim.createMany({
                    data: degisen_Parcalar.map((parca: any) => ({
                        bakim_id: bakimKaydi.bakim_id,
                        parca_id: parca.parca_id ? Number(parca.parca_id) : null,
                    })),
                });
            }
            return bakimKaydi;
        });
        res.status(201).json({
            success: true,
            message: 'Bakım kaydı başarıyla oluşturuldu.',
            data: sonuc
        });
    } catch (error) {
        console.error('Bakım kaydı oluşturulurken hata:', error);
        res.status(500).json({ error: 'Bakım kaydı oluşturulurken bir hata oluştu.' });
    }
};



export const makineBakimKayitlari = async (req: Request, res: Response) => {
    try {
        const makineIdParam = req.params.makine_id;
        if (!makineIdParam || isNaN(Number(makineIdParam))) {
            return res.status(400).json({
                success: false,
                message: 'Geçerli bir makine_id parametresi gereklidir. Örnek: /api/bakimlar/1'
            });

        }
        const makine_id = Number(makineIdParam);
        //makine var mı kontrolü
        const makineVarMi = await prisma.makine.findUnique({
            where: { makine_id: makine_id },
        });
        if (!makineVarMi) {
            return res.status(404).json({
                success: false,
                message: `makine_id ${makine_id} ile eşleşen bir makine bulunamadı.`
            });
        }
        ///bakım kayıtlarının çekilmesi, teknisyen ve parça değişim bilgilerinin dahil
        const bakimKayitlari = await prisma.bakim_kaydi.findMany({
            where: { makine_id: makine_id },
            include: {
                //bakım yapan teknisyenin bilgileri (servis_sorumlusu tablosundan)
                servis_sorumlusu: {
                    select: {
                        sorumlu_id: true,
                        ad: true,
                        soyad: true,
                        telefon: true,
                        unvan: true,
                    },
                },
                //değişen parçaların bilgileri (parca_degisim tablosundan)
                // parca_degisim → parca ilişkisi üzerinden parça bilgilerine erişiyoruz
                parca_degisim: {
                    include: {
                        parca: {
                            select: {
                                parca_id: true,
                                parca_adi: true,
                                parca_maliyeti: true,
                                tahmini_omur_saati: true,
                            }
                        }
                    }
                },
                //bakım yapan servis firmasının bilgileri (servis_firma tablosundan)
                // servis_firma'da telefon yok — iletisim tablosundan çekilir
                servis_firma: {
                    select: {
                        servis_firma_id: true,
                        firma_adi: true,
                        iletisim: {
                            select: {
                                telefon: true,
                                mail: true,
                            }
                        }
                    }
                },
                //bakım türü bilgileri
                bakim_turu: {
                    select: {
                        bakim_tur_id: true,
                        bakim_tur_adi: true,
                    }
                },
                //ilgili arıza bilgileri
                ariza_kaydi: {
                    select: {
                        ariza_id: true,
                        ariza_aciklama: true,
                        ariza_tur_id: true,
                        ariza_turu: {
                            select: {
                                ariza_tur: true,
                            }
                        }
                    }
                }
            },
            orderBy: {
                bakim_tarihi: 'desc', //bakım tarihine göre azalan sırada
            },
        });
        res.status(200).json({
            success: true,
            message: `${makine_id} makinesine ait bakım kayıtları başarıyla getirildi.`,
            data: bakimKayitlari,
        });
    } catch (error) {
        console.error('Bakım kayıtları getirilirken hata:', error);
        res.status(500).json({ error: 'Bakım kayıtları getirilirken bir hata oluştu.' });
    }
};
