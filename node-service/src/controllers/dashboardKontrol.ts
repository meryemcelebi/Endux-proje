import { Request, Response } from 'express';
import prisma from '../config/prisma';

const ONAY_BEKLEYEN_DURUMLAR = ['BEKLEYEN' , 'Onay Bekliyor'];

export const getDashboardOzet = async (req: Request, res: Response): Promise<Response> => {
    try {
        const  [
            makineDurumlari,
            onayBekleyenIs,
            ortalamaOee,
            kritikRiskliMakineler,

        ] = await Promise.all([
            prisma.makine.groupBy({
                by: ['aktiflik_durumu'],
                _count: {
                    _all: true,
                },
            }),
            prisma.bakim_kaydi.count({
                where: {
                    durum: { in: ONAY_BEKLEYEN_DURUMLAR }
                }
            }),
            prisma.oee_raporlari.aggregate({
                _avg: {
                    oee_skoru: true,
                },
            }),

            prisma.risk_skoru.findMany({
                where: { 
                    risk_skoru: {
                        not: null,

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
            })
        ]);

        const toplamMakine = makineDurumlari.reduce(
            (toplam , durum) => toplam + durum._count._all,
            0    
          );
        const toplamAktifMAkine = makineDurumlari.find( durum => durum.aktiflik_durumu === true)?._count._all ?? 0;
        const toplamPasifMakine = makineDurumlari.find( durum => durum.aktiflik_durumu === false)?._count._all ?? 0;

        return res.status(200).json({
            success: true,
            data: {
                makine_ozeti: {
                    toplam: toplamMakine,
                    aktif: toplamAktifMAkine,
                    bakimda: toplamPasifMakine
                },
                operasyonel_performans:  {
                    ortalama_oee: Number((ortalamaOee._avg.oee_skoru ?? 0).toFixed(2))


                },
                acil_aksiyonlar: {
                    onay_bekleyen_is: onayBekleyenIs,
                    kritik_riskli_makineler: kritikRiskliMakineler.map((risk) => ({
                        makine_adi: risk.makine.makine_adi ?? 'Makine Adı yok',
                        risk_skoru: Number(risk.risk_skoru ?? 0)
                    }))

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
    
