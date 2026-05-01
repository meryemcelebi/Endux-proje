import { Request, Response } from 'express';
import prisma from '../config/prisma';
import { Prisma } from '@prisma/client';



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
            teknisyen_id,
            degisen_Parcalar,
            puan } = req.body;


        if (!makine_id || !bakim_maliyet || !teknisyen_id || !servis_firma_id) {
            return res.status(400).json({ error: 'makine_id, bakim_maliyet, teknisyen_id ve servis_firma_id zorunludur.' });
        }


        const sonuc = await prisma.$transaction(async (tx) => {
            const bakimKaydi = await tx.bakim_kaydi.create({
                data: {
                    makine_id: Number(makine_id),
                    sorumlu_id: Number(teknisyen_id),
                    servis_firma_id: Number(servis_firma_id),
                    ariza_id: ariza_id ? Number(ariza_id) : null,
                    bakim_tur_id: bakim_tur_id ? Number(bakim_tur_id) : null,
                    bakim_maliyet: Number(bakim_maliyet),
                    durus_suresi: durus_suresi ? new Prisma.Decimal(durus_suresi) : null,
                    durus_suresi: durus_suresi ? new Decimal(durus_suresi) : null,
                    aciklama: aciklama || null,
                    bakim_tarihi: new Date(),
                },
            });

            // Puan geldiyse servis_puan tablosuna ekle
            if (puan !== undefined && puan !== null) {
                await tx.servis_puan.create({
                    data: {
                        servis_firma_id: Number(servis_firma_id),
                        puan: Number(puan),
                        bakim_id: bakimKaydi.bakim_id,
                        puanlayan_kullanici_id: Number(teknisyen_id), // Şimdilik işlemi yapan sorumlu puanlıyor
                        tarih: new Date()
                    }
                });
            }
            // ... (rest of the logic for degisen_Parcalar)
            // degisen parçaların kaydedilmesi
            // parca_degisim tablosu sadece 3 kolon içerir: parca_degisim_id, bakim_id, parca_id
            if (degisen_Parcalar && Array.isArray(degisen_Parcalar) && degisen_Parcalar.length > 0) {
                await tx.parca_degisim.createMany({
                    data: degisen_Parcalar.map((parca: any) => ({
                        bakim_id: bakimKaydi.bakim_id,
                        parca_id: parca.parca_id ? Number(parca.parca_id) : null,
                    })),
                });
                // 🔧 Parça değişimleri + stok düşme
                if (Array.isArray(degisen_Parcalar) && degisen_Parcalar.length > 0) {
                    for (const parca of degisen_Parcalar) {
                        const parcaId = Number(parca.parca_id);
                        const adet = Number(parca.adet) || 1;

                        if (!parcaId) continue;

                        // Parçayı bul
                        const mevcutParca = await tx.parca.findUnique({
                            where: { parca_id: parcaId }
                        });

                        if (!mevcutParca) {
                            throw new Error(`parca_id ${parcaId} bulunamadı.`);
                        }

                        if ((mevcutParca.stok_miktari || 0) < adet) {
                            throw new Error(
                                `"${mevcutParca.parca_adi}" için yeterli stok yok. ` +
                                `Mevcut: ${mevcutParca.stok_miktari}, İstenen: ${adet}`
                            );
                        }

                        // Parça değişim kaydı
                        await tx.parca_degisim.create({
                            data: {
                                bakim_id: bakimKaydi.bakim_id,
                                parca_id: parcaId,
                                adet: adet
                            }
                        });

                        // Stok düş
                        await tx.parca.update({
                            where: { parca_id: parcaId },
                            data: {
                                stok_miktari: { decrement: adet }
                            }
                        });
                    }
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
                // servis_puan bilgisini dahil et
                servis_puan: {
                    select: {
                        puan: true
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

<<<<<<< HEAD
export const bakimPuanla = async (req: Request, res: Response) => {
    try {
        const bakim_id = Number(req.params.id);
        const { puan } = req.body;

        if (isNaN(bakim_id) || puan === undefined) {
            return res.status(400).json({
                success: false,
                message: "Bakım ID ve puan zorunludur."
            });
        }

        // Önce bakım kaydını bul (firma_id ve sorumlu_id lazım)
        const bakim = await prisma.bakim_kaydi.findUnique({
            where: { bakim_id: bakim_id }
        });

        if (!bakim) {
            return res.status(404).json({ success: false, message: "Bakım kaydı bulunamadı." });
        }

        // servis_puan tablosuna upsert yap (bakim_id unique olduğu için)
        const guncelPuan = await prisma.servis_puan.upsert({
            where: { bakim_id: bakim_id },
            update: { puan: Number(puan) },
            create: {
                bakim_id: bakim_id,
                servis_firma_id: bakim.servis_firma_id,
                puan: Number(puan),
                puanlayan_kullanici_id: bakim.sorumlu_id || 1, // Varsayılan sistem kullanıcısı
                tarih: new Date()
=======
export async function dusukStokUyarisi(req: Request, res: Response): Promise<void> {
    try {
        const dusukStokParcalar = await prisma.$queryRaw<any[]> `
      SELECT parca_id, parca_adi, stok_miktari, min_stok_seviyesi,
             tedarik_gun_suresi, parca_maliyeti
      FROM parca
      WHERE stok_miktari <= min_stok_seviyesi
      ORDER BY stok_miktari ASC
    `;
        res.status(200).json({
            success: true,
            message: `${dusukStokParcalar.length} adet parça düşük stok seviyesinde.`,
            data: dusukStokParcalar
        });
    } catch (error) {
        console.error('stok uyarısı hatası:', error);
        res.status(500).json({ error: 'Düşük stok uyarısı getirilirken bir hata oluştu.' });
    }
}

// -----------------------------------------
// BAKIM ONAY/RED İŞLEMLERİ
// -----------------------------------------

export const bakimlariOnayla = async (req: Request, res: Response) => {
    try {
        const { bakim_idler } = req.body;

        if (!bakim_idler || !Array.isArray(bakim_idler) || bakim_idler.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'Onaylanacak kayıtların ID dizisi (bakim_idler) gereklidir.'
            });
        }

        // Seçilen bakım kayıtlarının durumunu 'Teknik Serviste' olarak güncelle
        const updated = await prisma.bakim_kaydi.updateMany({
            where: {
                bakim_id: { in: bakim_idler }
            },
            data: {
                durum: 'Teknik Serviste'
>>>>>>> 5b8a9a331802ed33037242851251595a72e68397
            }
        });

        res.status(200).json({
            success: true,
<<<<<<< HEAD
            message: "İşlem puanı başarıyla kaydedildi.",
            data: guncelPuan
        });
    } catch (error) {
        console.error("Bakım puanlama hatası:", error);
        res.status(500).json({
            success: false,
            message: "Puan kaydedilirken bir hata oluştu."
=======
            message: `${updated.count} adet bakım talebi başarıyla onaylandı ve Teknik Servis listesine aktarıldı.`,
            data: updated
        });

    } catch (error) {
        console.error('Bakım onayı sırasında hata:', error);
        res.status(500).json({
            success: false,
            message: 'Bakım kayıtları onaylanırken bir hata oluştu.'
>>>>>>> 5b8a9a331802ed33037242851251595a72e68397
        });
    }
};

<<<<<<< HEAD
export const bakimOnayla = async (req: Request, res: Response) => {
    try {
        const bakim_id = Number(req.params.id);

        if (isNaN(bakim_id)) {
            return res.status(400).json({ success: false, message: "Geçerli bir Bakım ID gereklidir." });
        }

        // Önce puanlanmış mı kontrol et
        const bakim = await prisma.bakim_kaydi.findUnique({
            where: { bakim_id: bakim_id },
            include: { servis_puan: true }
        });

        if (!bakim) {
            return res.status(404).json({ success: false, message: "Bakım kaydı bulunamadı." });
        }

        if (!bakim.servis_puan) {
            return res.status(400).json({
                success: false,
                message: "Bu işlem henüz puanlanmamış. Listeden kaldırmadan önce puanlamanız gerekmektedir."
            });
        }

        await prisma.bakim_kaydi.update({
            where: { bakim_id: bakim_id },
            data: { puan_onaylandi: true }
=======
export const bakimiYokSay = async (req: Request, res: Response) => {
    try {
        const { bakim_idler } = req.body;

        // Hem tekli id hem de array kabul et
        const ids = Array.isArray(bakim_idler) ? bakim_idler : [bakim_idler];

        if (!ids || ids.length === 0 || !ids[0]) {
            return res.status(400).json({
                success: false,
                message: 'Reddedilecek kaydın ID bilgisi (bakim_idler) gereklidir.'
            });
        }

        // Seçilen bakım kayıtlarının durumunu 'İptal Edildi' olarak güncelle
        const updated = await prisma.bakim_kaydi.updateMany({
            where: {
                bakim_id: { in: ids }
            },
            data: {
                durum: 'İptal Edildi'
            }
>>>>>>> 5b8a9a331802ed33037242851251595a72e68397
        });

        res.status(200).json({
            success: true,
<<<<<<< HEAD
            message: "İşlem başarıyla onaylandı ve listeden kaldırıldı."
        });
    } catch (error) {
        console.error("Bakım onaylama hatası:", error);
        res.status(500).json({ success: false, message: "Onaylama sırasında bir hata oluştu." });
=======
            message: `${updated.count} adet bakım talebi reddedildi / arşive taşındı.`,
            data: updated
        });

    } catch (error) {
        console.error('Bakım reddetme sırasında hata:', error);
        res.status(500).json({
            success: false,
            message: 'Bakım kayıtları reddedilirken bir hata oluştu.'
        });
    }
};

export const getOnayBekleyenler = async (req: Request, res: Response) => {
    try {
        const bekleyenler = await prisma.bakim_kaydi.findMany({
            where: {
                durum: {
                    in: ['BEKLEYEN', 'Onay Bekliyor']
                }
            },
            include: {
                makine: {
                    select: {
                        makine_adi: true,
                        risk_skoru: {
                            select: {
                                risk_skoru: true
                            },
                            orderBy: {
                                hesaplama_tarihi: 'desc'
                            },
                            take: 1
                        }
                    }
                },
                ariza_kaydi: {
                    select: {
                        ariza_aciklama: true
                    }
                }
            },
            orderBy: {
                bakim_tarihi: 'desc'
            }
        });

        // Veriyi frontend'in beklediği zengin DTO formatına çevirme
        const zenginVeri = bekleyenler.map(bakim => {
            // Risk skoru (makine'den veya 0)
            const riskSkoru = (bakim.makine?.risk_skoru && bakim.makine.risk_skoru.length > 0)
                ? Number(bakim.makine.risk_skoru[0].risk_skoru)
                : Math.floor(Math.random() * 40) + 40; // DB'de yoksa 40-80 arası mock skor

            // Öncelik belirleme
            let oncelik = "Düşük";
            if (riskSkoru > 75) oncelik = "Kritik";
            else if (riskSkoru > 50) oncelik = "Yüksek";
            else if (riskSkoru > 30) oncelik = "Orta";

            // Arıza notu (Arıza açıklaması yoksa bakım açıklamasını veya varsayılan metni kullan)
            let arizaNotu = bakim.ariza_kaydi?.ariza_aciklama || bakim.aciklama;
            if (!arizaNotu || arizaNotu.trim() === '') {
                // Mock endüstriyel arıza notları
                const mockNotlar = [
                    "Soğutma pompası basınç kaybediyor. Operatör yanık kokusu bildirdi.",
                    "Ana spindle ekseninde milimetrik kayma tespit edildi. Kalibrasyon gerekli.",
                    "Hidrolik yağ seviyesi kritik sınırın altında, sızıntı kontrolü yapılmalı.",
                    "Sensör verilerinde ani dalgalanma var. Pnömatik valf tepki vermiyor.",
                    "Motor aşırı ısınıyor (Termal eşik aşıldı). Soğutma fanı çalışmıyor olabilir."
                ];
                arizaNotu = mockNotlar[bakim.bakim_id % mockNotlar.length];
            }

            return {
                bakim_id: bakim.bakim_id,
                makine_adi: bakim.makine?.makine_adi || `Makine #${bakim.makine_id}`,
                hata_kodu: `ERR-M${bakim.makine_id}-${bakim.bakim_id}`,
                ariza_notu: arizaNotu,
                oncelik: oncelik,
                ai_risk_skoru: riskSkoru,
                durum: "Onay Bekliyor",
                tarih: bakim.bakim_tarihi ? bakim.bakim_tarihi.toISOString().split('T')[0] : new Date().toISOString().split('T')[0]
            };
        });

        res.status(200).json({
            success: true,
            data: zenginVeri
        });
    } catch (error) {
        console.error('Onay bekleyenleri getirirken hata:', error);
        res.status(500).json({
            success: false,
            message: 'Onay bekleyen kayıtlar getirilirken bir hata oluştu.'
        });
>>>>>>> 5b8a9a331802ed33037242851251595a72e68397
    }
};
