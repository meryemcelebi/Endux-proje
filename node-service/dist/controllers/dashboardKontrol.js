"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getDashboardOzet = void 0;
const prisma_1 = __importDefault(require("../config/prisma"));
const ONAY_BEKLEYEN_DURUMLAR = ['BEKLEYEN', 'Onay Bekliyor'];
const getDashboardOzet = async (req, res) => {
    try {
        const [makineDurumlari, onayBekleyenMakineler, ortalamaOee, kritikRiskliMakineler,] = await Promise.all([
            prisma_1.default.makine.groupBy({
                by: ['aktiflik_durumu'],
                _count: {
                    _all: true,
                },
            }),
            prisma_1.default.makine.findMany({
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
            prisma_1.default.oee_raporlari.aggregate({
                _avg: {
                    oee_skoru: true,
                },
            }),
            prisma_1.default.risk_skoru.findMany({
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
        const toplamMakine = makineDurumlari.reduce((toplam, durum) => toplam + durum._count._all, 0);
        const toplamAktifMAkine = makineDurumlari.find(durum => durum.aktiflik_durumu === true)?._count._all ?? 0;
        const toplamPasifMakine = makineDurumlari.find(durum => durum.aktiflik_durumu === false)?._count._all ?? 0;
        return res.status(200).json({
            success: true,
            data: {
                makine_ozeti: {
                    toplam: toplamMakine,
                    aktif: toplamAktifMAkine,
                    bakimda: toplamPasifMakine
                },
                operasyonel_performans: {
                    ortalama_oee: Number((ortalamaOee._avg.oee_skoru ?? 0).toFixed(2))
                },
                acil_aksiyonlar: {
                    onay_bekleyen_is: onayBekleyenMakineler.length,
                    onay_bekleyen_makineler: onayBekleyenMakineler.map(m => {
                        const bekleyenBakim = m.bakim_kaydi?.[0];
                        return {
                            id: bekleyenBakim?.bakim_id ?? m.makine_id,
                            bakim_id: bekleyenBakim?.bakim_id ?? null,
                            makine_id: m.makine_id,
                            makine_ad: m.makine_adi,
                            ariza_notu: bekleyenBakim?.aciklama || "Makine pasife alınmış, arıza notu yok.",
                            bakim_durum: bekleyenBakim?.durum || "Bekliyor"
                        };
                    }),
                    kritik_riskli_makineler: kritikRiskliMakineler.map((risk) => ({
                        makine_adi: risk.makine.makine_adi ?? 'Makine Adı yok',
                        risk_skoru: Number(risk.risk_skoru ?? 0)
                    }))
                }
            }
        });
    }
    catch (error) {
        console.error("Dashboard özeti alınırken hata oluştu:", error);
        return res.status(500).json({
            success: false,
            message: "Dashboard özeti alınırken hata oluştu."
        });
    }
};
exports.getDashboardOzet = getDashboardOzet;
