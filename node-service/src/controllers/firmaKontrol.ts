import { Request, Response } from "express";
import prisma from "../config/prisma";

export async function tumTedarikcileriGetir(req: Request, res: Response) {
    try {
        const tedarikciler = await prisma.tedarikci.findMany({
            include: {
                iletisim: true
            },
            orderBy: {
                tedarikci_id: "asc"
            }
        });
        res.status(200).json({
            success: true,
            message: `${tedarikciler.length} adet tedarikçi getirildi.`,
            data: tedarikciler
        });
    } catch (error) {
        console.error("Tedarikçileri getirme hatası:", error);
        res.status(500).json({

            success: false,
            message: 'Tedarikçiler getirilirken bir hata oluştu.'
        });

    }
};

export async function tedarikciEkle(req: Request, res: Response) {
    try {
        const { firma_adi, telefon, email, adres, il, ilce, aktiflik, yetkili_kisi, vergi_no } = req.body;

        if (!firma_adi || aktiflik === undefined) {
            res.status(400).json({
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
};



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
            },
            orderBy: {
                servis_firma_id: "asc"
            }
        });
        res.status(200).json({
            success: true,
            message: `${servisFirmalari.length} adet servis firması getirildi.`,
            data: servisFirmalari
        });
    } catch (error) {
        console.error("Servis firmalarını getirme hatası:", error);
        res.status(500).json({
            success: false,
            message: 'Servis firmaları getirilirken bir hata oluştu.'
        });
    }
};

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
};
