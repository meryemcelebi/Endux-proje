import { Request, Response } from 'express';
import prisma from '../config/prisma';
import { Prisma } from '@prisma/client';
import { supabase } from '../config/supabase';

const ACIL_BILDIRIM_ETIKETI = "[ACIL_BILDIRIM]";



export const bakimKaydiGir = async (req: Request, res: Response) => {
    console.log('Frontend\'den gelen bakım verisi:', req.body);

    try {
        const {
            makine_id, bakim_tur_id, aciklama, durus_suresi,
            servis_firma_id, ariza_id, bakim_maliyet, teknisyen_id,
            degisen_Parcalar, puan
        } = req.body;

        // 1. GÜVENLİK KONTROLÜ: (servis_firma_id artık zorunlu değil!)
        if (!makine_id || bakim_maliyet === undefined) {
            return res.status(400).json({ success: false, message: 'makine_id ve bakim_maliyet alanları zorunludur.' });
        }

        // 2. VERİTABANI KONTROLLERİ (P2003 Hatasını Önlemek İçin Ön Tarama)
        // Makine var mı?
        // (Not: prisma.makine yazan kısımlardaki model isimlerinin Canan'ın şemasıyla aynı olduğuna emin ol)
        const makineVarMi = await prisma.makine.findUnique({ where: { makine_id: Number(makine_id) } });
        if (!makineVarMi) {
            return res.status(404).json({ success: false, message: `Hata: Sistemde ${makine_id} numaralı bir makine bulunamadı.` });
        }

        // Arıza türü var mı? (Eğer frontend'den gönderildiyse)
        if (ariza_id) {
            const arizaVarMi = await prisma.ariza_turu.findUnique({ where: { ariza_tur_id: Number(ariza_id) } });
            if (!arizaVarMi) {
                return res.status(404).json({ success: false, message: `Hata: Sistemde ${ariza_id} numaralı bir arıza türü bulunamadı.` });
            }
        }

        // Teknisyen/Kullanıcı rolüne göre ID'yi ayarla
        const currentUserId = Number(req.user?.userId || teknisyen_id);
        const isServisRole = req.user?.rol === 'SERVIS';

        const sonuc = await prisma.$transaction(async (tx) => {

            // A. Bakım Kaydını Oluştur
            const bakimKaydi = await tx.bakim_kaydi.create({
                data: {
                    makine_id: Number(makine_id),
                    // Eğer SERVIS rolüyse sorumlu_id'ye, değilse kullanici_id'ye ata
                    sorumlu_id: isServisRole ? currentUserId : null,
                    kullanici_id: !isServisRole ? currentUserId : null,

                    servis_firma_id: servis_firma_id ? Number(servis_firma_id) : null,
                    ariza_id: null,
                    bakim_tur_id: bakim_tur_id ? Number(bakim_tur_id) : null,

                    bakim_maliyet: Number(bakim_maliyet),
                    durus_suresi: durus_suresi ? new Prisma.Decimal(durus_suresi) : null,
                    aciklama: aciklama || null,
                    bakim_tarihi: new Date(),

                    // TPM İş Akışı: Form kaydedildiği an bu görev TAMAMLANDI sayılır
                    durum: "TAMAMLANDI"
                },
            });


            await tx.makine.update({
                where: { makine_id: Number(makine_id) },
                data: { aktiflik_durumu: true }
            });

            // C. Puan ve Firma ID geldiyse servis_puan tablosuna ekle
            if (puan !== undefined && puan !== null && servis_firma_id) {
                await tx.servis_puan.create({
                    data: {
                        servis_firma_id: Number(servis_firma_id),
                        puan: Number(puan),
                        bakim_id: bakimKaydi.bakim_id,
                        puanlayan_kullanici_id: Number(teknisyen_id),
                        tarih: new Date()
                    }
                });
            }


            if (degisen_Parcalar && Array.isArray(degisen_Parcalar) && degisen_Parcalar.length > 0) {
                for (const parca of degisen_Parcalar) {
                    const parcaId = Number(parca.parca_id);
                    const adet = Number(parca.adet) || 1;

                    if (!parcaId) continue;

                    // Parçayı bul
                    const mevcutParca = await tx.parca.findUnique({
                        where: { parca_id: parcaId }
                    });

                    if (!mevcutParca) {
                        throw new Error(`Kritik Hata: ${parcaId} numaralı parça depoda bulunamadı. İşlem iptal edildi.`);
                    }

                    if ((mevcutParca.stok_miktari || 0) < adet) {
                        throw new Error(
                            `Stok Hatası: "${mevcutParca.parca_adi}" için depoda yeterli stok yok. ` +
                            `Mevcut: ${mevcutParca.stok_miktari}, İstenen: ${adet}`
                        );
                    }

                    // Parça değişim kaydı oluştur
                    await tx.parca_degisim.create({
                        data: {
                            bakim_id: bakimKaydi.bakim_id,
                            parca_id: parcaId,
                            adet: adet
                        }
                    });

                    // Stoktan düş
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

        // Başarılıysa Frontend'e 200 dön
        return res.status(200).json({
            success: true,
            message: 'Bakım başarıyla kaydedildi ve makine yeniden aktif duruma getirildi!',
            data: sonuc
        });

    } catch (error: any) {
        console.error("Bakım kaydı oluşturulurken sistem hatası:", error);

        // Transaction içindeki "throw new Error" fırlatmalarını yakalayıp frontend'e insan dilinde iletme
        return res.status(500).json({
            success: false,
            message: error.message || 'Veritabanı kayıt işlemi sırasında bir hata oluştu.'
        });
    }
};

export const acilBakimBildir = async (req: Request, res: Response) => {
    try {
        const makineId = Number(req.body.makine_id);
        const aciklama = String(req.body.aciklama || "").trim();
        const kullaniciId = Number(req.user?.userId) || null;

        if (!makineId) {
            return res.status(400).json({
                success: false,
                message: "makine_id alanı zorunludur."
            });
        }

        if (!aciklama) {
            return res.status(400).json({
                success: false,
                message: "Detaylı arıza açıklaması zorunludur."
            });
        }

        const makine = await prisma.makine.findUnique({
            where: { makine_id: makineId },
            select: { makine_id: true, makine_adi: true }
        });

        if (!makine) {
            return res.status(404).json({
                success: false,
                message: "Makine bulunamadı."
            });
        }

        await prisma.makine.update({
            where: { makine_id: makineId },
            data: { aktiflik_durumu: false }
        });

        const bakimKaydi = await prisma.bakim_kaydi.create({
            data: {
                makine_id: makineId,
                kullanici_id: kullaniciId,
                bakim_maliyet: 0,
                aciklama: `${ACIL_BILDIRIM_ETIKETI} ${aciklama}`,
                bakim_tarihi: new Date(),
                durum: "ONAYLANDI"
            }
        });

        return res.status(201).json({
            success: true,
            message: "Acil bakım bildirimi oluşturuldu ve teknik servise aktarıldı.",
            data: {
                bakim_id: bakimKaydi.bakim_id,
                makine_id: makine.makine_id,
                makine_adi: makine.makine_adi,
                durum: bakimKaydi.durum,
                acil_bildirim: true
            }
        });
    } catch (error: any) {
        console.error("Acil bakım bildirimi oluşturulurken hata:", error);
        return res.status(500).json({
            success: false,
            message: "Acil bakım bildirimi oluşturulurken bir hata oluştu."
        });
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
                // Dahili teknisyen bilgisi için kullanici tablosu
                kullanici: {
                    select: {
                        kullanici_id: true,
                        ad: true,
                        soyad: true,
                        telefon: true
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

            }
        });

        return res.status(200).json({
            success: true,
            message: `${updated.count} adet bakım görevi teknik servis listesine aktarıldı.`,
            data: {
                count: updated.count,
                bakim_idler
            }
        });

    } catch (error) {
        console.error('Bakım onayı sırasında hata:', error);
        res.status(500).json({
            success: false,
            message: 'Bakım kayıtları onaylanırken bir hata oluştu.'

        });
    }
};

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

        });

        res.status(200).json({
            success: true,

            message: "İşlem başarıyla onaylandı ve listeden kaldırıldı."
        });
    } catch (error) {
        console.error("Bakım onaylama hatası:", error);
        res.status(500).json({ success: false, message: "Onaylama sırasında bir hata oluştu." });

    }


}

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
    }
};

export const getTeknikServisIsleri = async (req: Request, res: Response) => {
    try {
        const isler = await prisma.bakim_kaydi.findMany({
            where: {
                durum: {
                    in: ['BEKLEYEN', 'Onay Bekliyor', 'Teknik Serviste', 'TAMAMLANDI', 'Bakımda', 'ONAYLANDI']
                }
            },
            include: {
                makine: {
                    select: {
                        makine_adi: true
                    }
                },
                ariza_kaydi: {
                    select: {
                        ariza_aciklama: true
                    }
                },
                servis_firma: {
                    select: {
                        firma_adi: true
                    }
                },
                servis_sorumlusu: {
                    select: {
                        ad: true,
                        soyad: true
                    }
                },
                kullanici: {
                    select: {
                        ad: true,
                        soyad: true
                    }
                },
                parca_degisim: {
                    include: {
                        parca: {
                            select: {
                                parca_adi: true,
                                parca_maliyeti: true
                            }
                        }
                    }
                }
            },
            orderBy: {
                bakim_tarihi: 'desc'
            }
        });

        const enGuncelIslerMap = new Map<number, any>();
        for (const is of isler) {
            // Her makine_id için sadece ilk karşılaştığımızı (en yenisini) alıyoruz.
            if (is.makine_id && !enGuncelIslerMap.has(is.makine_id)) {
                enGuncelIslerMap.set(is.makine_id, is);
            }
        }

        // Map'ten sadece eşsiz (en güncel) kayıtları diziye çevir
        const filtrelenmisIsler = Array.from(enGuncelIslerMap.values());

        // 3. Görseldeki tabloya uygun formatta DTO hazırlıyoruz
        const tabloVerisi = filtrelenmisIsler.map((is: any) => {
            // Durum mapping: Teknik Serviste -> ONAYLANDI (frontend mantığı)
            let frontendDurum = is.durum;
            if (is.durum === 'Teknik Serviste' || is.durum === 'Bakımda') {
                frontendDurum = 'ONAYLANDI';
            }
            const aciklama = is.aciklama || "";
            const acilBildirim = aciklama.includes(ACIL_BILDIRIM_ETIKETI);
            const temizAciklama = aciklama.replace(ACIL_BILDIRIM_ETIKETI, "").trim();

            return {
                bakim_id: is.bakim_id,
                makine_id: is.makine_id,
                makine_adi: is.makine?.makine_adi || `Makine #${is.makine_id}`,
                durum: frontendDurum,
                ariza_notu: is.ariza_kaydi?.ariza_aciklama || temizAciklama || "Belirtilmemiş",
                acil_bildirim: acilBildirim,
                kayit_tarihi: is.bakim_tarihi ? is.bakim_tarihi.toISOString().split('T')[0] : "Bilinmiyor",
                // Rapor detayları (TAMAMLANDI olanlar için)
                bakim_maliyet: is.bakim_maliyet ? Number(is.bakim_maliyet) : 0,
                durus_suresi: is.durus_suresi ? Number(is.durus_suresi) : 0,
                aciklama: temizAciklama,
                servis_firmasi: is.servis_firma?.firma_adi || "Belirtilmemiş",
                // Teknisyen adı: kullanici_id doluysa iç personel, sorumlu_id doluysa misafir servis
                teknisyen: is.kullanici_id && is.kullanici
                    ? `${is.kullanici.ad} ${is.kullanici.soyad}`
                    : is.sorumlu_id && is.servis_sorumlusu
                        ? `${is.servis_sorumlusu.ad} ${is.servis_sorumlusu.soyad}`
                        : "Belirtilmemiş",
                degisen_parcalar: (is.parca_degisim || []).map((pd: any) => ({
                    parca_adi: pd.parca?.parca_adi || "Bilinmeyen",
                    adet: pd.adet || 1,
                    maliyet: pd.parca?.parca_maliyeti || 0
                }))
            };
        });

        res.status(200).json({
            success: true,
            message: "Teknik servis iş listesi getirildi.",
            data: tabloVerisi
        });

    } catch (error) {
        console.error('Teknik servis işleri getirilirken hata:', error);
        res.status(500).json({
            success: false,
            message: 'Teknik servis iş listesi getirilirken bir hata oluştu.'
        });
    }
};

export const bakimPuaniKaydet = async (req: Request, res: Response) => {
    try {
        const bakimId = Number(req.params.bakim_id);
        const puanDegeri = Number(req.body?.puan);
        const puanlayanKullaniciId = Number(req.user?.userId);

        if (!bakimId || Number.isNaN(bakimId)) {
            return res.status(400).json({ success: false, message: "Geçerli bir bakım ID gereklidir." });
        }

        if (Number.isNaN(puanDegeri) || !Number.isInteger(puanDegeri) || puanDegeri < 1 || puanDegeri > 5) {
            return res.status(400).json({ success: false, message: "Puan 1 ile 5 arasında tam sayı olmalıdır." });
        }

        if (!puanlayanKullaniciId || Number.isNaN(puanlayanKullaniciId)) {
            return res.status(401).json({ success: false, message: "Geçerli bir kullanıcı oturumu bulunamadı." });
        }

        const bakim = await prisma.bakim_kaydi.findUnique({
            where: { bakim_id: bakimId },
            select: {
                bakim_id: true,
                servis_firma_id: true,
                servis_puan_id: true
            }
        });

        if (!bakim) {
            return res.status(404).json({ success: false, message: "Bakım kaydı bulunamadı." });
        }

        if (!bakim.servis_firma_id) {
            return res.status(400).json({ success: false, message: "Bu bakım kaydı için servis firması tanımlı değil." });
        }

        const puanKaydi = await prisma.$transaction(async (tx) => {
            const kayit = bakim.servis_puan_id
                ? await tx.servis_puan.update({
                    where: { puan_id: bakim.servis_puan_id },
                    data: {
                        puan: puanDegeri,
                        puanlayan_kullanici_id: puanlayanKullaniciId,
                        tarih: new Date()
                    }
                })
                : await tx.servis_puan.create({
                    data: {
                        servis_firma_id: Number(bakim.servis_firma_id),
                        puan: puanDegeri,
                        puanlayan_kullanici_id: puanlayanKullaniciId,
                        tarih: new Date(),
                        bakim_id: bakimId
                    }
                });

            if (!bakim.servis_puan_id) {
                await tx.bakim_kaydi.update({
                    where: { bakim_id: bakimId },
                    data: { servis_puan_id: kayit.puan_id }
                });
            }

            return kayit;
        });

        return res.status(200).json({
            success: true,
            message: "Bakım puanı başarıyla kaydedildi.",
            data: puanKaydi
        });
    } catch (error) {
        console.error("Bakım puanlama hatası:", error);
        return res.status(500).json({ success: false, message: "Bakım puanı kaydedilirken bir hata oluştu." });
    }
};

export const bakimIsleminiOnayla = async (req: Request, res: Response) => {
    try {
        const bakimId = Number(req.params.bakim_id);

        if (!bakimId || Number.isNaN(bakimId)) {
            return res.status(400).json({ success: false, message: "Geçerli bir bakım ID gereklidir." });
        }

        const bakim = await prisma.bakim_kaydi.findUnique({
            where: { bakim_id: bakimId },
            select: {
                bakim_id: true,
                servis_puan_id: true,
                makine_id: true
            }
        });

        if (!bakim) {
            return res.status(404).json({ success: false, message: "Bakım kaydı bulunamadı." });
        }

        if (!bakim.servis_puan_id) {
            return res.status(400).json({ success: false, message: "İşlem onaylanmadan önce puan verilmelidir." });
        }

        await prisma.$transaction([
            prisma.bakim_kaydi.update({
                where: { bakim_id: bakimId },
                data: {
                    durum: "TAMAMLANDI"
                }
            }),
            prisma.makine.update({
                where: { makine_id: bakim.makine_id },
                data: { aktiflik_durumu: true }
            })
        ]);

        return res.status(200).json({
            success: true,
            message: "Bakım işlemi onaylandı."
        });
    } catch (error) {
        console.error("Bakım işlem onayı hatası:", error);
        return res.status(500).json({ success: false, message: "Bakım işlemi onaylanırken bir hata oluştu." });
    }
};




export async function bakimOnaylaProseduru(req: Request, res: Response): Promise<void> {
    try {
        const bakimId = req.body.bakim_id;

        // Canan'ın yazdığı prosedürü Supabase istemcisi ile tetikliyoruz
        const { data, error } = await supabase.rpc('bakim_onayla_fonksiyonu', {
            p_bakim_id: bakimId
        });

        if (error) {
            console.error("Supabase RPC Hatası:", error); // <-- Hata loglama eklendi
            throw error;
        }

        res.status(200).json({ success: true, message: "Bakım başarıyla onaylandı", data });

    } catch (error) {
        console.error("Bakım onaylama işlemi başarısız:", error); // <-- Hata loglama eklendi
        res.status(500).json({ success: false, error: "İşlem başarısız, lütfen logları kontrol edin." });
    }
};

export const TumBakimlarToplu = async (req: Request, res: Response): Promise<Response> => {
    try {
        const tumBakimlar = await prisma.bakim_kaydi.findMany({
            include: {
                makine: {
                    select: { makine_adi: true }
                },
                servis_firma: {
                    select: { firma_adi: true }
                },
                servis_puan: {
                    select: {
                        puan_id: true,
                        puan: true
                    }
                }
            },
            orderBy: {
                bakim_tarihi: 'desc'
            }
        });

        // Frontend'in beklediği formata uygun olarak map'liyoruz
        const formatliBakimlar = tumBakimlar.map(b => ({
            ...b,
            makine_ad: b.makine?.makine_adi || 'Bilinmeyen Makine',
            servis_firmasi: b.servis_firma?.firma_adi || `Firma #${b.servis_firma_id}`
        }));

        return res.status(200).json({ success: true, data: formatliBakimlar });
    } catch (error) {
        console.error("Tüm bakımlar çekilirken hata:", error);
        return res.status(500).json({ success: false, message: "Bakımlar çekilemedi." });
    }
};

// Teknisyen bakımı başlatır — PATCH /api/bakimlar/:bakim_id/baslat
export const bakimBaslat = async (req: Request, res: Response) => {
    try {
        const bakimId = Number(req.params.bakim_id);

        if (!bakimId || isNaN(bakimId)) {
            return res.status(400).json({ success: false, message: "Geçerli bir bakım ID gereklidir." });
        }

        const bakim = await prisma.bakim_kaydi.findUnique({
            where: { bakim_id: bakimId },
            select: { durum: true }
        });

        if (!bakim) {
            return res.status(404).json({ success: false, message: "Bakım kaydı bulunamadı." });
        }

        if (bakim.durum !== "Teknik Serviste") {
            return res.status(400).json({
                success: false,
                message: `Bu bakım kaydı başlatılamaz. Mevcut durum: ${bakim.durum}`
            });
        }

        await prisma.bakim_kaydi.update({
            where: { bakim_id: bakimId },
            data: { durum: "Bakımda" }
        });

        res.status(200).json({
            success: true,
            message: "Bakım işlemi başlatıldı. Makine durumu 'Bakımda' olarak güncellendi."
        });
    } catch (error) {
        console.error("Bakım başlatma hatası:", error);
        res.status(500).json({ success: false, message: "Bakım başlatılırken hata oluştu." });
    }
};

// ═══════════════════════════════════════════════════════════════════
// QR BAZLI BAKIM TAMAMLAMA — POST /api/bakimlar/qr-tamamla
// Teknisyen sahada QR okutup formu doldurduktan sonra çağrılır.
// Prisma transaction içinde 2 işlem atomik yapılır:
//   1) bakım kaydını güncelle (maliyet, parça, açıklama, durum=TAMAMLANDI)
//   2) ilgili makinenin aktiflik_durumu = true yap
// ═══════════════════════════════════════════════════════════════════
export const qrBakimTamamla = async (req: Request, res: Response) => {
    try {
        // ─── DEBUG LOG: Gelen veriyi konsola bas ───
        console.log('─────────────────────────────────────────');
        console.log('[QR-TAMAMLA] Gelen istek body:', JSON.stringify(req.body, null, 2));
        console.log('[QR-TAMAMLA] Kullanıcı:', req.user?.userId, '| Rol:', req.user?.rol);
        console.log('─────────────────────────────────────────');

        const {
            bakim_id,
            bakim_maliyet,
            aciklama,
            degisen_parcalar,
            durus_suresi
        } = req.body;

        // Tip dönüşümleri ve validasyon
        const parsedBakimId = Number(bakim_id);
        if (!parsedBakimId || isNaN(parsedBakimId)) {
            console.error('[QR-TAMAMLA] HATA: bakim_id geçersiz →', bakim_id);
            return res.status(400).json({
                success: false,
                message: 'bakim_id zorunludur ve sayısal olmalıdır.'
            });
        }

        // Bakım kaydını kontrol et
        const mevcutBakim = await prisma.bakim_kaydi.findUnique({
            where: { bakim_id: parsedBakimId },
            select: {
                bakim_id: true,
                makine_id: true,
                durum: true
            }
        });

        if (!mevcutBakim) {
            console.error('[QR-TAMAMLA] HATA: Kayıt bulunamadı → bakim_id:', parsedBakimId);
            return res.status(404).json({
                success: false,
                message: 'Bakım kaydı bulunamadı.'
            });
        }

        console.log('[QR-TAMAMLA] Mevcut bakım durumu:', mevcutBakim.durum, '| makine_id:', mevcutBakim.makine_id);

        // Geçerli durumlar: Teknik Serviste, ONAYLANDI, Bakımda + BEKLEYEN (otomatik oluşturulmuş)
        const gecerliDurumlar = ['Teknik Serviste', 'ONAYLANDI', 'Bakımda', 'BEKLEYEN', 'Onay Bekliyor'];
        if (!gecerliDurumlar.includes(mevcutBakim.durum || '')) {
            console.warn('[QR-TAMAMLA] UYARI: Geçersiz durum →', mevcutBakim.durum);
            return res.status(400).json({
                success: false,
                message: `Bu bakım kaydı tamamlanamaz. Mevcut durum: ${mevcutBakim.durum}`
            });
        }

        // Prisma Transaction: 2 işlem atomik olarak yapılır
        const sonuc = await prisma.$transaction(async (tx) => {
            // 1) Bakım kaydını güncelle — durum TAMAMLANDI, form detayları yazılır
            // Tip dönüşümleri — frontend'den gelen değerlerin güvenli parse'ı
            const parsedMaliyet = bakim_maliyet ? Number(bakim_maliyet) : 0;
            const parsedDurus = durus_suresi ? Number(String(durus_suresi)) : null;
            const parsedAciklama = aciklama ? String(aciklama).trim() : '';

            console.log('[QR-TAMAMLA] Parse edilen değerler → maliyet:', parsedMaliyet, '| durus:', parsedDurus, '| aciklama:', parsedAciklama.substring(0, 50));

            const guncellenmisKayit = await tx.bakim_kaydi.update({
                where: { bakim_id: parsedBakimId },
                data: {
                    durum: 'TAMAMLANDI',
                    bakim_maliyet: parsedMaliyet,
                    aciklama: parsedAciklama || undefined,
                    durus_suresi: parsedDurus ? new Prisma.Decimal(parsedDurus) : undefined,
                    bakim_tarihi: new Date() // Tamamlanma anı
                }
            });

            console.log('[QR-TAMAMLA] ✅ Bakım kaydı güncellendi → bakim_id:', parsedBakimId);

            // 2) İlgili makinenin aktiflik_durumu'nu true (Aktif) yap
            await tx.makine.update({
                where: { makine_id: mevcutBakim.makine_id },
                data: {
                    aktiflik_durumu: true
                }
            });

            // 3) Değişen parçalar varsa kaydet ve stok düş
            if (degisen_parcalar && Array.isArray(degisen_parcalar) && degisen_parcalar.length > 0) {
                for (const parca of degisen_parcalar) {
                    const parcaId = Number(parca.parca_id);
                    const adet = Number(parca.adet) || 1;

                    if (!parcaId) continue;

                    const mevcutParca = await tx.parca.findUnique({
                        where: { parca_id: parcaId }
                    });

                    if (!mevcutParca) continue;

                    // Parça değişim kaydı
                    await tx.parca_degisim.create({
                        data: {
                            bakim_id: Number(bakim_id),
                            parca_id: parcaId,
                            adet: adet
                        }
                    });

                    // Stok düş (yeterliyse)
                    if ((mevcutParca.stok_miktari || 0) >= adet) {
                        await tx.parca.update({
                            where: { parca_id: parcaId },
                            data: {
                                stok_miktari: { decrement: adet }
                            }
                        });
                    }
                }
            }

            return guncellenmisKayit;
        });

        res.status(200).json({
            success: true,
            message: 'Bakım başarıyla tamamlandı. Makine aktif duruma geçirildi.',
            data: sonuc
        });
    } catch (error) {
        console.error('QR bakım tamamlama hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Bakım tamamlanırken bir hata oluştu.'
        });
    }
};
