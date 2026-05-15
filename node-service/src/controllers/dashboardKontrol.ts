import { Request, Response } from 'express';
import prisma from '../config/prisma';
import { calculateOeeScore, roundOeeValue } from '../utils/oee';

const ONAY_BEKLEYEN_DURUMLAR = ['BEKLEYEN', 'Onay Bekliyor'];

export const getDashboardOzet = async (req: Request, res: Response): Promise<Response> => {
    try {
        await prisma.$executeRawUnsafe(`
            ALTER TABLE "makine_turu"
            ADD COLUMN IF NOT EXISTS "saatlik_durus_maliyeti" DOUBLE PRECISION DEFAULT 0
        `);

        const [
            makineDurumlari,
            onayBekleyenMakineler,
            ortalamaOee,
            kritikRiskliMakineler,
            bakimiYaklasanAdaylar,
            maliyetAnalizi,
            makineBazliMaliyetler,
            parcaKategoriMaliyetleri,
            aylikMaliyetTrend
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

            // Maliyet Analizi Toplamları (TPM Kategorileri)
            prisma.$queryRawUnsafe<any[]>(`
                SELECT 
                    -- 1. Planlı Bakım Maliyeti (Bakım türü tam olarak 'Planlı Bakım' veya 'Önleyici Bakım' olanlar)
                    (SELECT COALESCE(SUM(bakim_maliyet), 0)::FLOAT FROM bakim_kaydi bk 
                     JOIN bakim_turu bt ON bk.bakim_tur_id = bt.bakim_tur_id 
                     WHERE bt.bakim_tur_adi ILIKE '%Planlı%' OR bt.bakim_tur_adi ILIKE '%Önleyici%' OR bt.bakim_tur_adi ILIKE '%Periyodik%') as planli_bakim_maliyeti,
                    
                    -- 2. Arızi Bakım Maliyeti (Geriye kalan tüm bakım maliyetleri)
                    (SELECT COALESCE(SUM(bakim_maliyet), 0)::FLOAT FROM bakim_kaydi bk 
                     JOIN bakim_turu bt ON bk.bakim_tur_id = bt.bakim_tur_id 
                     WHERE bt.bakim_tur_adi NOT ILIKE '%Planlı%' AND bt.bakim_tur_adi NOT ILIKE '%Önleyici%' AND bt.bakim_tur_adi NOT ILIKE '%Periyodik%') as arizi_bakim_maliyeti,
                    
                    -- 3. Yedek Parça Giderleri (Parça değişim tablosundan)
                    (SELECT COALESCE(SUM(p.parca_maliyeti * COALESCE(pd.adet, 1)), 0)::FLOAT 
                     FROM parca_degisim pd 
                     JOIN parca p ON pd.parca_id = p.parca_id) as toplam_parca_masrafi,
                    
                    -- 4. Dış Servis Ücretleri (Sorumlu ID kolu dolu olan tüm bakımların maliyeti)
                    (SELECT COALESCE(SUM(bakim_maliyet), 0)::FLOAT FROM bakim_kaydi WHERE sorumlu_id IS NOT NULL) as dis_servis_maliyeti,
                    
                    -- 5. Duruş Maliyeti (durus_suresi * saatlik_durus_maliyeti)
                    (SELECT COALESCE(SUM(bk.durus_suresi * COALESCE(mt.saatlik_durus_maliyeti, 0)), 0)::FLOAT 
                     FROM bakim_kaydi bk 
                     JOIN makine m ON bk.makine_id = m.makine_id
                     JOIN makine_turu mt ON m.makine_tur_id = mt.makine_tur_id
                     WHERE bk.durus_suresi IS NOT NULL) as durus_maliyeti,

                    (SELECT COALESCE(SUM(satin_alma_maliyeti), 0)::FLOAT FROM makine) as toplam_makine_alim
            `),

            // Makine Bazlı Maliyet Dağılımı (Detay Sayfası İçin)
            prisma.$queryRawUnsafe<any[]>(`
                SELECT 
                    m.makine_id,
                    m.makine_adi,
                    l.fabrika_alani,
                    -- Planlı Bakım
                    COALESCE(SUM(CASE WHEN bt.bakim_tur_adi ILIKE '%Planlı%' OR bt.bakim_tur_adi ILIKE '%Önleyici%' OR bt.bakim_tur_adi ILIKE '%Periyodik%' THEN bk.bakim_maliyet ELSE 0 END), 0)::FLOAT as planli_maliyet,
                    -- Arızi Bakım
                    COALESCE(SUM(CASE WHEN bt.bakim_tur_adi NOT ILIKE '%Planlı%' AND bt.bakim_tur_adi NOT ILIKE '%Önleyici%' AND bt.bakim_tur_adi NOT ILIKE '%Periyodik%' THEN bk.bakim_maliyet ELSE 0 END), 0)::FLOAT as arizi_maliyet,
                    -- Dış Servis (Sorumlu ID olanlar)
                    COALESCE(SUM(CASE WHEN bk.sorumlu_id IS NOT NULL THEN bk.bakim_maliyet ELSE 0 END), 0)::FLOAT as dis_servis_maliyet,
                    -- Yedek Parça (Makineye ait parça değişimleri)
                    COALESCE((SELECT SUM(p.parca_maliyeti * COALESCE(pd.adet, 1)) FROM parca_degisim pd JOIN parca p ON pd.parca_id = p.parca_id WHERE pd.bakim_id IN (SELECT bakim_id FROM bakim_kaydi WHERE makine_id = m.makine_id)), 0)::FLOAT as parca_maliyeti,
                    -- Duruş
                    COALESCE(SUM(bk.durus_suresi), 0)::FLOAT as toplam_durus_suresi,
                    COALESCE(SUM(bk.durus_suresi * COALESCE(mt.saatlik_durus_maliyeti, 0)), 0)::FLOAT as durus_kaybi_maliyeti
                FROM makine m
                LEFT JOIN makine_turu mt ON m.makine_tur_id = mt.makine_tur_id
                LEFT JOIN lokasyon l ON m.makine_id = l.makine_id
                LEFT JOIN bakim_kaydi bk ON m.makine_id = bk.makine_id
                LEFT JOIN bakim_turu bt ON bk.bakim_tur_id = bt.bakim_tur_id
                GROUP BY m.makine_id, m.makine_adi, l.fabrika_alani
                ORDER BY (COALESCE(SUM(bk.bakim_maliyet), 0) + COALESCE(SUM(bk.durus_suresi * COALESCE(mt.saatlik_durus_maliyeti, 0)), 0)) DESC
                LIMIT 20
            `),

            // 7. Yedek Parça Kategori Bazlı Maliyetler (YENİ)
            prisma.$queryRawUnsafe<any[]>(`
                SELECT 
                    pk.kategori_adi as kategori,
                    l.fabrika_alani as lokasyon,
                    SUM(p.parca_maliyeti * COALESCE(pd.adet, 1))::FLOAT as maliyet
                FROM parca_degisim pd
                JOIN parca p ON pd.parca_id = p.parca_id
                JOIN parca_kategori pk ON p.kategori_id = pk.kategori_id
                JOIN bakim_kaydi bk ON pd.bakim_id = bk.bakim_id
                JOIN makine m ON bk.makine_id = m.makine_id
                LEFT JOIN lokasyon l ON m.makine_id = l.makine_id
                GROUP BY pk.kategori_adi, l.fabrika_alani
                ORDER BY SUM(p.parca_maliyeti * COALESCE(pd.adet, 1)) DESC
            `),

            // 8. Aylık Maliyet Trendi (Son 3 Ay)
            prisma.$queryRawUnsafe<any[]>(`
                WITH aylar AS (
                    SELECT generate_series(
                        date_trunc('month', CURRENT_DATE - interval '5 months'),
                        date_trunc('month', CURRENT_DATE),
                        '1 month'::interval
                    )::DATE as ay_baslangic
                ),
                bakim_maliyetleri AS (
                    SELECT 
                        date_trunc('month', bk.bakim_tarihi)::DATE as ay,
                        COALESCE(SUM(CASE WHEN bt.bakim_tur_adi ILIKE '%Planlı%' OR bt.bakim_tur_adi ILIKE '%Önleyici%' OR bt.bakim_tur_adi ILIKE '%Periyodik%' THEN bk.bakim_maliyet ELSE 0 END), 0)::FLOAT as planli,
                        COALESCE(SUM(CASE WHEN bt.bakim_tur_adi NOT ILIKE '%Planlı%' AND bt.bakim_tur_adi NOT ILIKE '%Önleyici%' AND bt.bakim_tur_adi NOT ILIKE '%Periyodik%' THEN bk.bakim_maliyet ELSE 0 END), 0)::FLOAT as arizi,
                        COALESCE(SUM(CASE WHEN bk.sorumlu_id IS NOT NULL THEN bk.bakim_maliyet ELSE 0 END), 0)::FLOAT as dis_servis
                    FROM bakim_kaydi bk
                    LEFT JOIN bakim_turu bt ON bk.bakim_tur_id = bt.bakim_tur_id
                    WHERE bk.bakim_tarihi >= date_trunc('month', CURRENT_DATE - interval '5 months')
                    GROUP BY date_trunc('month', bk.bakim_tarihi)::DATE
                ),
                parca_maliyetleri AS (
                    SELECT 
                        date_trunc('month', bk.bakim_tarihi)::DATE as ay,
                        COALESCE(SUM(p.parca_maliyeti * COALESCE(pd.adet, 1)), 0)::FLOAT as parca
                    FROM parca_degisim pd
                    JOIN parca p ON pd.parca_id = p.parca_id
                    JOIN bakim_kaydi bk ON pd.bakim_id = bk.bakim_id
                    WHERE bk.bakim_tarihi >= date_trunc('month', CURRENT_DATE - interval '5 months')
                    GROUP BY date_trunc('month', bk.bakim_tarihi)::DATE
                )
                SELECT 
                    a.ay_baslangic as ay,
                    COALESCE(bm.planli, 0) as planli,
                    COALESCE(bm.arizi, 0) as arizi,
                    COALESCE(bm.dis_servis, 0) as dis_servis,
                    COALESCE(pm.parca, 0) as parca
                FROM aylar a
                LEFT JOIN bakim_maliyetleri bm ON a.ay_baslangic = bm.ay
                LEFT JOIN parca_maliyetleri pm ON a.ay_baslangic = pm.ay
                ORDER BY a.ay_baslangic ASC
            `)
        ]);

        // Maliyet Özeti Ayarları (TPM Uyumlu)
        const maliyetOzetData = maliyetAnalizi && maliyetAnalizi[0] ? maliyetAnalizi[0] : {
            planli_bakim_maliyeti: 0,
            arizi_bakim_maliyeti: 0,
            toplam_parca_masrafi: 0,
            dis_servis_maliyeti: 0,
            durus_maliyeti: 0,
            toplam_makine_alim: 0
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
                // Maliyet Özeti (TPM Kurumsal Standart)
                maliyet_ozeti: {
                    planli_bakim: Number(maliyetOzetData?.planli_bakim_maliyeti || 0),
                    arizi_bakim: Number(maliyetOzetData?.arizi_bakim_maliyeti || 0),
                    parca_gideri: Number(maliyetOzetData?.toplam_parca_masrafi || 0),
                    dis_servis: Number(maliyetOzetData?.dis_servis_maliyeti || 0),
                    durus_maliyeti: Number(maliyetOzetData?.durus_maliyeti || 0),
                    toplam_alim: Number(maliyetOzetData?.toplam_makine_alim || 0),
                    makine_detaylari: makineBazliMaliyetler || [],
                    parca_kategori_detaylari: parcaKategoriMaliyetleri || [],
                    aylik_trend: (aylikMaliyetTrend || []).map((row: any) => ({
                        ay: row.ay,
                        planli: Number(row.planli || 0),
                        arizi: Number(row.arizi || 0),
                        dis_servis: Number(row.dis_servis || 0),
                        parca: Number(row.parca || 0),
                        toplam: Number(row.planli || 0) + Number(row.arizi || 0) + Number(row.dis_servis || 0) + Number(row.parca || 0)
                    }))
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

