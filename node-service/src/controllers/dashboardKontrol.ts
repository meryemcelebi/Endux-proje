import { Request, Response } from 'express';
import prisma from '../config/prisma';
import { calculateOeeScore, roundOeeValue } from '../utils/oee';

const ONAY_BEKLEYEN_DURUMLAR = ['BEKLEYEN', 'Onay Bekliyor'];

export const getDashboardOzet = async (req: Request, res: Response): Promise<Response> => {
    try {
        const [
            makineDurumlari,
            onayBekleyenMakineler,
            ortalamaOee,
            kritikRiskliMakineler,
            bakimiYaklasanAdaylar,
            maliyetAdaylari
        ] = await Promise.all([
            prisma.makine.groupBy({
                by: ['aktiflik_durumu'],
                _count: {
                    _all: true,
                },
            }),
            prisma.makine.findMany({
                where: {
                    aktiflik_durumu: false,
                    bakim_kaydi: {
                        some: {
                            durum: {
                                in: ONAY_BEKLEYEN_DURUMLAR
                            }
                        }
                    }
                },
                include: {
                    bakim_kaydi: {
                        where: {
                            durum: {
                                in: ONAY_BEKLEYEN_DURUMLAR
                            }
                        },
                        orderBy: { bakim_tarihi: 'desc' },
                        take: 1,
                        select: {
                            bakim_id: true,
                            aciklama: true,
                            durum: true
                        }
                    }
                }
            }),
            prisma.oee_raporlari.aggregate({
                _avg: {
                    kullanilabilirlik_orani: true,
                    performans_orani: true,
                    kalite_orani: true,
                },
            }),

            prisma.risk_skoru.findMany({
                where: {
                    risk_skoru: {
                        gte: 80,
                    }
                },
                distinct: ['makine_id'],
                orderBy: {
                    risk_skoru: 'desc',
                },
                take: 5,
                include: {
                    makine: {
                        select: {
                            makine_adi: true,
                        }
                    }
                }
            }),

            // TPM: Bakımı yaklaşan makine adaylarını çek
            prisma.makine.findMany({
                where: {
                    aktiflik_durumu: true,
                    makine_turu: {
                        periyodik_bakim_saati: { not: null }
                    }
                },
                include: {
                    makine_turu: {
                        select: {
                            makine_tur_adi: true,
                            periyodik_bakim_saati: true
                        }
                    }
                }
            }),

            // Maliyet Analizi Toplamları (Fabrika Geneli)
            prisma.$queryRawUnsafe<any[]>(`
                SELECT 
                    (SELECT COALESCE(SUM(satin_alma_maliyeti), 0)::FLOAT FROM makine) as toplam_makine_alim,
                    (SELECT COALESCE(SUM(bakim_maliyet), 0)::FLOAT FROM bakim_kaydi) as toplam_servis_ucreti,
                    (SELECT COALESCE(SUM(p.parca_maliyeti * COALESCE(pd.adet, 1)), 0)::FLOAT 
                     FROM parca_degisim pd 
                     JOIN parca p ON pd.parca_id = p.parca_id) as toplam_parca_masrafi
            `)
        ]);

        // Maliyet Özeti Ayarları
        const maliyetOzetData = maliyetAdaylari && maliyetAdaylari[0] ? maliyetAdaylari[0] : {
            toplam_makine_alim: 0,
            toplam_servis_ucreti: 0,
            toplam_parca_masrafi: 0
        };

        // TPM: %90 eşik algoritması — bakımı yaklaşan makineleri filtrele
        const bakimiYaklasanMakineler = bakimiYaklasanAdaylar
            .filter(m => {
                const calismaSaati = Number(m.toplam_calisma_saati || 0);
                const periyodik = m.makine_turu?.periyodik_bakim_saati || 3000;
                const esikDeger = periyodik * 0.9; // %90 eşik
                return calismaSaati >= esikDeger;
            })
            .map(m => {
                const calismaSaati = Number(m.toplam_calisma_saati || 0);
                const periyodik = m.makine_turu?.periyodik_bakim_saati || 3000;
                const kalanSaat = Math.max(0, periyodik - calismaSaati);
                return {
                    makine_id: m.makine_id,
                    makine_adi: m.makine_adi || "İsimsiz Makine",
                    makine_turu: m.makine_turu?.makine_tur_adi || "Bilinmeyen Tür",
                    calisma_saati: calismaSaati,
                    periyodik_limit: periyodik,
                    kalan_saat: kalanSaat,
                    aciliyet: kalanSaat <= 0 ? "GEÇMİŞ" : kalanSaat <= 100 ? "KRİTİK" : "UYARI"
                };
            })
            .sort((a, b) => a.kalan_saat - b.kalan_saat); // En acil olan önce

        const toplamMakine = makineDurumlari.reduce(
            (toplam, durum) => toplam + durum._count._all,
            0
        );
        const toplamAktifMAkine = makineDurumlari.find(durum => durum.aktiflik_durumu === true)?._count._all ?? 0;
        const toplamPasifMakine = makineDurumlari.find(durum => durum.aktiflik_durumu === false)?._count._all ?? 0;
        const ortalamaKullanilabilirlik = roundOeeValue(ortalamaOee._avg.kullanilabilirlik_orani ?? 0);
        const ortalamaPerformans = roundOeeValue(ortalamaOee._avg.performans_orani ?? 0);
        const ortalamaKalite = roundOeeValue(ortalamaOee._avg.kalite_orani ?? 0);
        const hesaplananOee = calculateOeeScore(
            ortalamaKullanilabilirlik,
            ortalamaPerformans,
            ortalamaKalite
        ) ?? 0;

        return res.status(200).json({
            success: true,
            data: {
                makine_ozeti: {
                    toplam: toplamMakine,
                    aktif: toplamAktifMAkine,
                    bakimda: toplamPasifMakine
                },
                operasyonel_performans: {
                    ortalama_oee: hesaplananOee,
                    kullanilabilirlik: ortalamaKullanilabilirlik,
                    performans: ortalamaPerformans,
                    kalite: ortalamaKalite
                },
                acil_aksiyonlar: {
                    onay_bekleyen_is: onayBekleyenMakineler.length,
                    onay_bekleyen_makineler: onayBekleyenMakineler.map(m => {
                        const bekleyenBakim = m.bakim_kaydi?.[0];
                        return {
                            id: bekleyenBakim?.bakim_id ?? m.makine_id,
                            bakim_id: bekleyenBakim?.bakim_id ?? null,
                            makine_id: m.makine_id,
                            makine_ad: m.makine_adi || "İsimsiz Makine",
                            ariza_notu: bekleyenBakim?.aciklama || "Makine pasife alınmış, arıza notu yok.",
                            bakim_durum: bekleyenBakim?.durum || "Bekliyor"
                        };
                    }),
                    kritik_riskli_makineler: kritikRiskliMakineler.map((risk) => ({
                        makine_id: risk.makine_id,
                        makine_adi: risk.makine.makine_adi || 'Makine Adı yok',
                        risk_skoru: Number(risk.risk_skoru ?? 0)
                    }))
                },
                // Maliyet Özeti
                maliyet_ozeti: {
                    toplam_makine_alim: Number(maliyetOzetData?.toplam_makine_alim || 0),
                    toplam_servis_ucreti: Number(maliyetOzetData?.toplam_servis_ucreti || 0),
                    toplam_parca_masrafi: Number(maliyetOzetData?.toplam_parca_masrafi || 0)
                },
                // TPM: Bakımı yaklaşan makineler
                bakimi_yaklasan: {
                    sayi: bakimiYaklasanMakineler.length,
                    makineler: bakimiYaklasanMakineler
                }
            }
        });
    } catch (error) {
        console.error("Dashboard özeti alınırken hata oluştu:", error);
        return res.status(500).json({
            success: false,
            message: "Dashboard özeti alınırken hata oluştu."
        });
    }
};

