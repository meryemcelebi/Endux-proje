import { Request, Response } from "express";
import prisma from "../config/prisma";

export async function tumTedarikcileriGetir(req: Request, res: Response) {
    try {
        const tedarikciler = await prisma.tedarikci.findMany({
            include: {
                iletisim: true,
                satin_alma: {
                    select: {
                        puan: true
                    }
                },
                tedarikci_puan: {
                    select: {
                        puan: true,
                        yorum: true,
                        tarih: true
                    },
                    orderBy: {
                        tarih: "desc"
                    }
                }
            },
            orderBy: {
                tedarikci_id: "asc"
            }
        });

        const dataWithAvg = tedarikciler.map(t => {
            const satinAlmaPuanlari = t.satin_alma
                .filter(sa => sa.puan !== null && sa.puan !== undefined)
                .map(sa => Number(sa.puan));

            const genelPuanlar = t.tedarikci_puan
                .filter(tp => tp.puan !== null && tp.puan !== undefined)
                .map(tp => Number(tp.puan) * 2); // 1-5'i 1-10'a normalize et

            const tumPuanlar = [...satinAlmaPuanlari, ...genelPuanlar];

            const ortalama = tumPuanlar.length > 0
                ? Number((tumPuanlar.reduce((a, b) => a + b, 0) / tumPuanlar.length).toFixed(1))
                : 0;

            return {
                ...t,
                ortalama_puan: ortalama,
                yorum: t.tedarikci_puan?.[0]?.yorum || null,
                satin_alma: undefined,
                tedarikci_puan: undefined
            };
        });

        res.status(200).json({
            success: true,
            message: `${tedarikciler.length} adet tedarikçi getirildi.`,
            data: dataWithAvg
        });
    } catch (error) {
        console.error("Tedarikçileri getirme hatası:", error);
        res.status(500).json({
            success: false,
            message: 'Tedarikçiler getirilirken bir hata oluştu.'
        });
    }
}

export async function tedarikciEkle(req: Request, res: Response) {
    try {
        const { firma_adi, telefon, email, adres, il, ilce, aktiflik, yetkili_kisi, vergi_no } = req.body;

        if (!firma_adi || aktiflik === undefined) {
            return res.status(400).json({
                success: false,
                message: "Firma adı ve aktiflik alanları zorunludur."
            });
        }

        // iletişim bilgileri ayrı tabloda — önce iletisim kaydı oluştur
        let iletisim_id: number | undefined;
        if (telefon || email || adres || il || ilce) {
            const yeniIletisim = await prisma.iletisim.create({
                data: {
                    telefon: telefon ? String(telefon) : null,
                    mail: email ? String(email) : null,
                    acik_adres: adres ? String(adres) : null,
                    il: il ? String(il) : null,
                    ilce: ilce ? String(ilce) : null,
                }
            });
            iletisim_id = yeniIletisim.iletisim_id;
        }

        const yeniTedarikci = await prisma.tedarikci.create({
            data: {
                firma_adi: firma_adi,
                aktiflik: Boolean(aktiflik),
                yetkili_kisi: yetkili_kisi ? String(yetkili_kisi) : null,
                vergi_no: vergi_no ? String(vergi_no) : null,
                iletisim_id: iletisim_id,
                kayit_tarihi: new Date(),
            }
        });
        res.status(201).json({
            success: true,
            message: 'Tedarikçi başarıyla eklendi.',
            data: yeniTedarikci
        });
    } catch (error) {
        console.error("Tedarikçi ekleme hatası:", error);
        res.status(500).json({
            success: false,
            message: 'Tedarikçi eklenirken bir hata oluştu.'
        });
    }
}



//servis firmaları işlemleri

export async function tumServisFirmalariniGetir(req: Request, res: Response) {
    try {
        const servisFirmalari = await prisma.servis_firma.findMany({
            include: {
                servis_sorumlusu: {
                    select: {
                        sorumlu_id: true,
                        ad: true,
                        soyad: true,
                        telefon: true,
                        unvan: true,
                        aktiflik: true,
                    }
                },
                iletisim: true,
                servis_firma_uzmanlik: true,
                servis_puan: {
                    select: {
                        puan: true
                    }
                }
            },
            orderBy: {
                servis_firma_id: "asc"
            }
        });

        const dataWithAvg = servisFirmalari.map(f => {
            const puanlar = f.servis_puan.map(sp => Number(sp.puan));
            const ortalama = puanlar.length > 0
                ? Number((puanlar.reduce((a, b) => a + b, 0) / puanlar.length).toFixed(1))
                : 0;

            return {
                ...f,
                ortalama_puan: ortalama,
                toplam_islem: puanlar.length,
                servis_puan: undefined // Veriyi şişirmemek için
            };
        });

        res.status(200).json({
            success: true,
            message: `${servisFirmalari.length} adet servis firması getirildi.`,
            data: dataWithAvg
        });
    } catch (error) {
        console.error("Servis firmalarını getirme hatası:", error);
        res.status(500).json({
            success: false,
            message: 'Servis firmaları getirilirken bir hata oluştu.'
        });
    }
}

export async function servisFirmasiEkle(req: Request, res: Response): Promise<void> {
    try {
        const { firma_adi, telefon, email, adres, il, ilce, uzmanlik_alani } = req.body;
        if (!firma_adi) {
            res.status(400).json({
                success: false,
                message: "Firma adı zorunludur."
            });
            return;
        }

        // iletişim bilgileri ayrı tabloda
        let iletisim_id: number | undefined;
        if (telefon || email || adres || il || ilce) {
            const yeniIletisim = await prisma.iletisim.create({
                data: {
                    telefon: telefon ? String(telefon) : null,
                    mail: email ? String(email) : null,
                    acik_adres: adres ? String(adres) : null,
                    il: il ? String(il) : null,
                    ilce: ilce ? String(ilce) : null,
                }
            });
            iletisim_id = yeniIletisim.iletisim_id;
        }

        const yeniServisFirmasi = await prisma.servis_firma.create({
            data: {
                firma_adi: String(firma_adi),
                aktiflik: true,
                iletisim_id: iletisim_id,
            }
        });

        // uzmanlık alanı ayrı tabloda (servis_firma_uzmanlik)
        if (uzmanlik_alani) {
            await prisma.servis_firma_uzmanlik.create({
                data: {
                    servis_firma_id: yeniServisFirmasi.servis_firma_id,
                    uzmanlik_adi: String(uzmanlik_alani),
                }
            });
        }

        res.status(201).json({
            success: true,
            message: 'Servis firması başarıyla eklendi.',
            data: yeniServisFirmasi
        });
    } catch (error) {
        console.error("Servis firması ekleme hatası:", error);
        res.status(500).json({
            success: false,
            message: 'Servis firması eklenirken bir hata oluştu.'
        });
    }
}
export async function tedarikciSil(req: Request, res: Response): Promise<void> {
    try {
        const id = Number(req.params.id);

        // Hard delete yerine Soft Delete (aktiflik = false) yapıyoruz
        // Bu sayede geçmiş satın alma ve puanlama verileri korunur
        await prisma.tedarikci.update({
            where: { tedarikci_id: id },
            data: { aktiflik: false }
        });

        res.status(200).json({
            success: true,
            message: 'Tedarikçi sözleşmesi iptal edildi (Pasif duruma getirildi).'
        });
    } catch (error) {
        console.error("Tedarikçi iptal hatası:", error);
        res.status(500).json({
            success: false,
            message: 'Tedarikçi iptal edilirken bir hata oluştu.'
        });
    }
}

export async function servisFirmasiSil(req: Request, res: Response): Promise<void> {
    try {
        const id = Number(req.params.id);

        // Hard delete yerine Soft Delete (aktiflik = false) yapıyoruz
        // Bu sayede geçmiş bakım kayıtları ve teknisyen bilgileri korunur
        await prisma.servis_firma.update({
            where: { servis_firma_id: id },
            data: { aktiflik: false }
        });

        res.status(200).json({
            success: true,
            message: 'Servis firması sözleşmesi iptal edildi (Pasif duruma getirildi).'
        });
    } catch (error) {
        console.error("Servis firması iptal hatası:", error);
        res.status(500).json({
            success: false,
            message: 'Servis firması iptal edilirken bir hata oluştu.'
        });
    }
}
