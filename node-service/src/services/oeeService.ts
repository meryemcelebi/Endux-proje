import prisma from '../config/prisma';
import { oeeSkoruHesapla, oeeYuvarla } from '../utils/oee';

const VARSAYILAN_TEORIK_KAPASITE = 100;

type Vardiya = {
    baslangic_saati: string;
    bitis_saati: string;
};

function gunBaslangici(tarih: Date): Date {
    const d = new Date(tarih);
    d.setHours(0, 0, 0, 0);
    return d;
}

function gunBitisi(tarih: Date): Date {
    const d = new Date(tarih);
    d.setHours(23, 59, 59, 999);
    return d;
}

function gunSayisiHesapla(baslangic: Date, bitis: Date): number {
    const farkMs = gunBaslangici(bitis).getTime() - gunBaslangici(baslangic).getTime();
    return Math.max(Math.floor(farkMs / (1000 * 60 * 60 * 24)) + 1, 1);
}

function donemBelirle(gunSayisi: number): string {
    if (gunSayisi <= 1) return 'Günlük';
    if (gunSayisi <= 7) return 'Haftalık';
    if (gunSayisi <= 31) return 'Aylık';
    if (gunSayisi <= 93) return '3 Aylık';
    return 'Yıllık';
}

function vardiyaSuresiDakika(vardiya: Vardiya): number {
    const [basSaat, basDakika] = vardiya.baslangic_saati.split(':').map(Number);
    const [bitSaat, bitDakika] = vardiya.bitis_saati.split(':').map(Number);
    const baslangic = basSaat * 60 + basDakika;
    let bitis = bitSaat * 60 + bitDakika;

    if (bitis <= baslangic) {
        bitis += 24 * 60;
    }

    return Math.max(bitis - baslangic, 0);
}

function vardiyaPlanliSureDakika(vardiyalar: Vardiya[], gunSayisi: number): number {
    return vardiyalar.reduce((toplam, vardiya) => toplam + vardiyaSuresiDakika(vardiya), 0) * gunSayisi;
}

function teknikKapasiteOku(teknikOzellikler: unknown): number {
    if (!teknikOzellikler || typeof teknikOzellikler !== 'object') {
        return VARSAYILAN_TEORIK_KAPASITE;
    }

    const data = teknikOzellikler as Record<string, unknown>;
    const adaylar = [
        data.teorik_kapasite_saat,
        data.teorik_kapasite,
        data.saatlik_kapasite,
        data.kapasite_saat,
    ];

    const kapasite = adaylar.map(Number).find((deger) => Number.isFinite(deger) && deger > 0);
    return kapasite || VARSAYILAN_TEORIK_KAPASITE;
}

async function kaliteKontrolOraniHesapla(makineId: number, baslangic: Date, bitis: Date) {
    const formlar = await prisma.gunluk_kontrol_formu.findMany({
        where: {
            makine_id: makineId,
            kontrol_tarihi: { gte: baslangic, lte: bitis },
        },
        select: { form_id: true },
    });

    const formIdleri = formlar.map((form) => form.form_id);
    if (!formIdleri.length) {
        return { kalite: 95, toplamKontrol: 0, hataliKontrol: 0 };
    }

    const kaliteCevaplari = await prisma.form_madde_cevap.findMany({
        where: {
            form_id: { in: formIdleri },
            kontrol_maddesi: {
                OR: [
                    { madde_adi: { contains: 'kalite', mode: 'insensitive' } },
                    { madde_adi: { contains: 'baskı', mode: 'insensitive' } },
                    { madde_adi: { contains: 'çapak', mode: 'insensitive' } },
                    { madde_adi: { contains: 'eksik', mode: 'insensitive' } },
                    { madde_adi: { contains: 'yüzey', mode: 'insensitive' } },
                ],
            },
        },
        select: { durum: true },
    });

    if (!kaliteCevaplari.length) {
        return { kalite: 95, toplamKontrol: 0, hataliKontrol: 0 };
    }

    const olumsuzDurumlar = ['NOK', 'Kötü', 'Hatalı', 'Uygun Değil', 'KÖTÜ', 'HATALI'];
    const hataliKontrol = kaliteCevaplari.filter((cevap) => {
        const durum = cevap.durum || '';
        return olumsuzDurumlar.some((olumsuz) => durum.toUpperCase().includes(olumsuz.toUpperCase()));
    }).length;

    const kalite = ((kaliteCevaplari.length - hataliKontrol) / kaliteCevaplari.length) * 100;

    return {
        kalite: oeeYuvarla(kalite),
        toplamKontrol: kaliteCevaplari.length,
        hataliKontrol,
    };
}

async function hariciDurusDakikaHesapla(makineId: number, baslangic: Date, bitis: Date): Promise<number> {
    const [duruslar, bakimlar, arizalar] = await Promise.all([
        prisma.durus_kaydi.findMany({
            where: {
                makine_id: makineId,
                vardiya_tarihi: { gte: baslangic, lte: bitis },
            },
            select: { durus_sure_dk: true },
        }),
        prisma.bakim_kaydi.findMany({
            where: {
                makine_id: makineId,
                bakim_tarihi: { gte: baslangic, lte: bitis },
            },
            select: { durus_suresi: true },
        }),
        prisma.ariza_kaydi.findMany({
            where: {
                makine_id: makineId,
                baslangic_zamani: { gte: baslangic, lte: bitis },
            },
            select: { baslangic_zamani: true, bitis_zamani: true },
        }),
    ]);

    const durusDakika = duruslar.reduce((toplam, durus) => toplam + Number(durus.durus_sure_dk || 0), 0);
    const bakimDakika = bakimlar.reduce((toplam, bakim) => toplam + Number(bakim.durus_suresi || 0) * 60, 0);
    const arizaDakika = arizalar.reduce((toplam, ariza) => {
        if (!ariza.baslangic_zamani || !ariza.bitis_zamani) return toplam;
        return toplam + ((ariza.bitis_zamani.getTime() - ariza.baslangic_zamani.getTime()) / (1000 * 60));
    }, 0);

    return Math.max(durusDakika + bakimDakika + arizaDakika, 0);
}

export async function makineOeeHesapla(makineId: number, baslangicTarihi: Date, bitisTarihi: Date) {
    const baslangic = gunBaslangici(baslangicTarihi);
    const bitis = gunBitisi(bitisTarihi);
    const gunSayisi = gunSayisiHesapla(baslangic, bitis);

    const [makine, vardiyalar, uretimKayitlari] = await Promise.all([
        prisma.makine.findUnique({
            where: { makine_id: makineId },
            include: {
                makine_ozellikleri: true,
                makine_turu: true,
            },
        }),
        prisma.vardiya_saatleri.findMany({
            select: { baslangic_saati: true, bitis_saati: true },
        }),
        prisma.uretim_kaydi.findMany({
            where: {
                makine_id: makineId,
                vardiya_tarihi: { gte: baslangic, lte: bitis },
            },
            select: {
                planlanan_sure_dk: true,
                fiili_sure_dk: true,
                durus_sure_dk: true,
                teorik_uretim: true,
                gercek_uretim: true,
                hatali_uretim: true,
            },
        }),
    ]);

    if (!makine) {
        throw new Error(`Makine bulunamadı: ID ${makineId}`);
    }

    const vardiyaPlanliDakika = vardiyaPlanliSureDakika(vardiyalar, gunSayisi);
    const uretimPlanliDakika = uretimKayitlari.reduce((toplam, kayit) => toplam + Number(kayit.planlanan_sure_dk || 0), 0);
    const toplamPlanliDakika = vardiyaPlanliDakika || uretimPlanliDakika;
    const teorikKapasiteSaat = teknikKapasiteOku(makine.makine_ozellikleri?.teknik_ozellikler);

    const uretimDurusDakika = uretimKayitlari.reduce((toplam, kayit) => toplam + Number(kayit.durus_sure_dk || 0), 0);
    const hariciDurusDakika = uretimKayitlari.length ? 0 : await hariciDurusDakikaHesapla(makineId, baslangic, bitis);
    const toplamDurusDakika = uretimKayitlari.length ? uretimDurusDakika : hariciDurusDakika;
    const kullanilabilirDakika = Math.max(toplamPlanliDakika - toplamDurusDakika, 0);

    const kullanilabilirlik = toplamPlanliDakika > 0
        ? oeeYuvarla((kullanilabilirDakika / toplamPlanliDakika) * 100)
        : 0;

    const gercekUretim = uretimKayitlari.reduce((toplam, kayit) => toplam + Number(kayit.gercek_uretim || 0), 0);
    const teorikUretimKayit = uretimKayitlari.reduce((toplam, kayit) => toplam + Number(kayit.teorik_uretim || 0), 0);
    const teorikUretim = teorikUretimKayit || Math.round((kullanilabilirDakika / 60) * teorikKapasiteSaat);

    let performans = 0;
    let gercekUretimHesaplanan = gercekUretim;
    let fallbackPerformansKullanildi = false;
    if (teorikUretim > 0 && gercekUretim > 0) {
        performans = oeeYuvarla(Math.min((gercekUretim / teorikUretim) * 100, 100));
    } else if (!uretimKayitlari.length && teorikUretim > 0) {
        const kullanimlar = await prisma.makine_kullanim.findMany({
            where: {
                makine_id: makineId,
                baslangic_zamani: { gte: baslangic, lte: bitis },
            },
            select: { baslangic_zamani: true, bitis_zamani: true, gunluk_top_calisma_saati: true },
        });

        const gercekCalismaSaati = kullanimlar.reduce((toplam, kullanim) => {
            const gunlukSaat = Number(kullanim.gunluk_top_calisma_saati || 0);
            if (gunlukSaat > 0) return toplam + gunlukSaat;
            return toplam + ((kullanim.bitis_zamani.getTime() - kullanim.baslangic_zamani.getTime()) / (1000 * 60 * 60));
        }, 0);

        gercekUretimHesaplanan = Math.round(gercekCalismaSaati * teorikKapasiteSaat * 0.9);
        if (gercekUretimHesaplanan > 0) {
            performans = oeeYuvarla(Math.min((gercekUretimHesaplanan / teorikUretim) * 100, 100));
        } else {
            fallbackPerformansKullanildi = true;
            gercekUretimHesaplanan = Math.round(teorikUretim * 0.9);
            performans = 90;
        }
    }

    const hataliUretim = uretimKayitlari.reduce((toplam, kayit) => toplam + Number(kayit.hatali_uretim || 0), 0);
    const kontrolKalite = await kaliteKontrolOraniHesapla(makineId, baslangic, bitis);
    const kalite = gercekUretim > 0
        ? oeeYuvarla(Math.max(((gercekUretim - hataliUretim) / gercekUretim) * 100, 0))
        : kontrolKalite.kalite;

    const oeeSkoru = oeeSkoruHesapla(kullanilabilirlik, performans, kalite) ?? 0;
    const durusNedenleri = await prisma.durus_kaydi.groupBy({
        by: ['durus_nedeni'],
        where: {
            makine_id: makineId,
            vardiya_tarihi: { gte: baslangic, lte: bitis },
        },
        _sum: { durus_sure_dk: true },
    });

    return {
        makine_id: makineId,
        makine_adi: makine.makine_adi,
        makine_turu: makine.makine_turu.makine_tur_adi,
        donem: donemBelirle(gunSayisi),
        tarih_araligi: {
            baslangic: baslangic.toISOString().split('T')[0],
            bitis: bitis.toISOString().split('T')[0],
            gun_sayisi: gunSayisi,
        },
        detaylar: {
            kullanilabilirlik_yuzdesi: kullanilabilirlik,
            performans_yuzdesi: performans,
            kalite_yuzdesi: kalite,
        },
        ham_veriler: {
            veri_kaynagi: uretimKayitlari.length
                ? 'uretim_kaydi'
                : fallbackPerformansKullanildi
                    ? 'vardiya_saatleri_ve_varsayilan_performans'
                    : 'makine_kullanim_ve_kontrol_formu',
            varsayilan_performans_kullanildi: fallbackPerformansKullanildi,
            vardiya_sayisi: vardiyalar.length,
            uretim_kaydi_sayisi: uretimKayitlari.length,
            toplam_planli_sure_saat: oeeYuvarla(toplamPlanliDakika / 60),
            toplam_durus_saat: oeeYuvarla(toplamDurusDakika / 60),
            kullanilabilir_sure_saat: oeeYuvarla(kullanilabilirDakika / 60),
            teorik_kapasite_saat: teorikKapasiteSaat,
            gercek_uretim_adet: gercekUretim || gercekUretimHesaplanan,
            teorik_uretim_adet: teorikUretim,
            hatali_uretim_adet: hataliUretim,
            toplam_kalite_kontrolu: kontrolKalite.toplamKontrol,
            hatali_kontrol_sayisi: kontrolKalite.hataliKontrol,
        },
        durus_nedenleri: durusNedenleri.map((durus) => ({
            neden: durus.durus_nedeni,
            toplam_sure_dk: durus._sum.durus_sure_dk || 0,
        })),
        oee_skoru: oeeSkoru,
        oee_trend: [{
            tarih: bitis.toISOString().split('T')[0],
            kullanilabilirlik,
            performans,
            kalite,
            oee_skoru: oeeSkoru,
        }],
    };
}

export async function fabrikaOeeHesapla(baslangicTarihi: Date, bitisTarihi: Date) {
    const baslangic = gunBaslangici(baslangicTarihi);
    const bitis = gunBitisi(bitisTarihi);
    const gunSayisi = gunSayisiHesapla(baslangic, bitis);

    let makineler = await prisma.makine.findMany({
        where: { aktiflik_durumu: true },
        include: {
            makine_ozellikleri: true,
            makine_turu: true,
        }
    });

    if (!makineler.length) {
        makineler = await prisma.makine.findMany({
            include: {
                makine_ozellikleri: true,
                makine_turu: true,
            }
        });
    }

    const makineIds = makineler.map(m => m.makine_id);
    if (!makineIds.length) {
        return {
            fabrika_ortalama_oee: 0,
            fabrika_bilesenleri: { kullanilabilirlik: 0, performans: 0, kalite: 0 },
            donem: {
                baslangic: baslangic.toISOString().split('T')[0],
                bitis: bitis.toISOString().split('T')[0],
            },
            fabrika_trend: [],
            makineler: [],
            hatali_makineler: [],
        };
    }

    const [
        vardiyalar,
        uretimKayitlariTum,
        duruslarTum,
        bakimlarTum,
        arizalarTum,
        kullanimlarTum,
        formlarTum
    ] = await Promise.all([
        prisma.vardiya_saatleri.findMany({
            select: { baslangic_saati: true, bitis_saati: true },
        }),
        prisma.uretim_kaydi.findMany({
            where: {
                makine_id: { in: makineIds },
                vardiya_tarihi: { gte: baslangic, lte: bitis },
            },
            select: {
                makine_id: true,
                planlanan_sure_dk: true,
                fiili_sure_dk: true,
                durus_sure_dk: true,
                teorik_uretim: true,
                gercek_uretim: true,
                hatali_uretim: true,
            },
        }),
        prisma.durus_kaydi.findMany({
            where: {
                makine_id: { in: makineIds },
                vardiya_tarihi: { gte: baslangic, lte: bitis },
            },
            select: { makine_id: true, durus_sure_dk: true, durus_nedeni: true },
        }),
        prisma.bakim_kaydi.findMany({
            where: {
                makine_id: { in: makineIds },
                bakim_tarihi: { gte: baslangic, lte: bitis },
            },
            select: { makine_id: true, durus_suresi: true },
        }),
        prisma.ariza_kaydi.findMany({
            where: {
                makine_id: { in: makineIds },
                baslangic_zamani: { gte: baslangic, lte: bitis },
            },
            select: { makine_id: true, baslangic_zamani: true, bitis_zamani: true },
        }),
        prisma.makine_kullanim.findMany({
            where: {
                makine_id: { in: makineIds },
                baslangic_zamani: { gte: baslangic, lte: bitis },
            },
            select: { makine_id: true, baslangic_zamani: true, bitis_zamani: true, gunluk_top_calisma_saati: true },
        }),
        prisma.gunluk_kontrol_formu.findMany({
            where: {
                makine_id: { in: makineIds },
                kontrol_tarihi: { gte: baslangic, lte: bitis },
            },
            select: { form_id: true, makine_id: true },
        })
    ]);

    const formIdleri = formlarTum.map(f => f.form_id);
    const kaliteCevaplariTum = formIdleri.length ? await prisma.form_madde_cevap.findMany({
        where: {
            form_id: { in: formIdleri },
            kontrol_maddesi: {
                OR: [
                    { madde_adi: { contains: 'kalite', mode: 'insensitive' } },
                    { madde_adi: { contains: 'baskı', mode: 'insensitive' } },
                    { madde_adi: { contains: 'çapak', mode: 'insensitive' } },
                    { madde_adi: { contains: 'eksik', mode: 'insensitive' } },
                    { madde_adi: { contains: 'yüzey', mode: 'insensitive' } },
                ],
            },
        },
        select: { form_id: true, durum: true },
    }) : [];

    const uretimMap = new Map<number, typeof uretimKayitlariTum>();
    const durusMap = new Map<number, typeof duruslarTum>();
    const bakimMap = new Map<number, typeof bakimlarTum>();
    const arizaMap = new Map<number, typeof arizalarTum>();
    const kullanimMap = new Map<number, typeof kullanimlarTum>();
    const formMap = new Map<number, typeof formlarTum>();

    uretimKayitlariTum.forEach(r => {
        if (!uretimMap.has(r.makine_id)) uretimMap.set(r.makine_id, []);
        uretimMap.get(r.makine_id)!.push(r);
    });
    duruslarTum.forEach(r => {
        if (!durusMap.has(r.makine_id)) durusMap.set(r.makine_id, []);
        durusMap.get(r.makine_id)!.push(r);
    });
    bakimlarTum.forEach(r => {
        if (!bakimMap.has(r.makine_id)) bakimMap.set(r.makine_id, []);
        bakimMap.get(r.makine_id)!.push(r);
    });
    arizalarTum.forEach(r => {
        if (!arizaMap.has(r.makine_id)) arizaMap.set(r.makine_id, []);
        arizaMap.get(r.makine_id)!.push(r);
    });
    kullanimlarTum.forEach(r => {
        if (!kullanimMap.has(r.makine_id)) kullanimMap.set(r.makine_id, []);
        kullanimMap.get(r.makine_id)!.push(r);
    });
    formlarTum.forEach(r => {
        if (!formMap.has(r.makine_id)) formMap.set(r.makine_id, []);
        formMap.get(r.makine_id)!.push(r);
    });

    const formToMakineId = new Map<number, number>();
    formlarTum.forEach(f => formToMakineId.set(f.form_id, f.makine_id));

    const kaliteCevaplariMap = new Map<number, typeof kaliteCevaplariTum>();
    kaliteCevaplariTum.forEach(c => {
        const mId = formToMakineId.get(c.form_id);
        if (mId !== undefined) {
            if (!kaliteCevaplariMap.has(mId)) kaliteCevaplariMap.set(mId, []);
            kaliteCevaplariMap.get(mId)!.push(c);
        }
    });

    const vardiyaPlanliDakika = vardiyaPlanliSureDakika(vardiyalar, gunSayisi);
    const sonuclar: any[] = [];
    const hatalar: any[] = [];

    for (const makine of makineler) {
        try {
            const makineId = makine.makine_id;
            const uretimKayitlari = uretimMap.get(makineId) || [];
            const duruslar = durusMap.get(makineId) || [];
            const bakimlar = bakimMap.get(makineId) || [];
            const arizalar = arizaMap.get(makineId) || [];
            const kullanimlar = kullanimMap.get(makineId) || [];
            const kaliteCevaplari = kaliteCevaplariMap.get(makineId) || [];

            const uretimPlanliDakika = uretimKayitlari.reduce((toplam, kayit) => toplam + Number(kayit.planlanan_sure_dk || 0), 0);
            const toplamPlanliDakika = vardiyaPlanliDakika || uretimPlanliDakika;
            const teorikKapasiteSaat = teknikKapasiteOku(makine.makine_ozellikleri?.teknik_ozellikler);

            const uretimDurusDakika = uretimKayitlari.reduce((toplam, kayit) => toplam + Number(kayit.durus_sure_dk || 0), 0);
            
            let hariciDurusDakika = 0;
            if (!uretimKayitlari.length) {
                const durusDakika = duruslar.reduce((toplam, durus) => toplam + Number(durus.durus_sure_dk || 0), 0);
                const bakimDakika = bakimlar.reduce((toplam, bakim) => toplam + Number(bakim.durus_suresi || 0) * 60, 0);
                const arizaDakika = arizalar.reduce((toplam, ariza) => {
                    if (!ariza.baslangic_zamani || !ariza.bitis_zamani) return toplam;
                    return toplam + ((ariza.bitis_zamani!.getTime() - ariza.baslangic_zamani!.getTime()) / (1000 * 60));
                }, 0);
                hariciDurusDakika = Math.max(durusDakika + bakimDakika + arizaDakika, 0);
            }

            const toplamDurusDakika = uretimKayitlari.length ? uretimDurusDakika : hariciDurusDakika;
            const kullanilabilirDakika = Math.max(toplamPlanliDakika - toplamDurusDakika, 0);

            const kullanilabilirlik = toplamPlanliDakika > 0
                ? oeeYuvarla((kullanilabilirDakika / toplamPlanliDakika) * 100)
                : 0;

            const gercekUretim = uretimKayitlari.reduce((toplam, kayit) => toplam + Number(kayit.gercek_uretim || 0), 0);
            const teorikUretimKayit = uretimKayitlari.reduce((toplam, kayit) => toplam + Number(kayit.teorik_uretim || 0), 0);
            const teorikUretim = teorikUretimKayit || Math.round((kullanilabilirDakika / 60) * teorikKapasiteSaat);

            let performans = 0;
            let gercekUretimHesaplanan = gercekUretim;
            let fallbackPerformansKullanildi = false;
            if (teorikUretim > 0 && gercekUretim > 0) {
                performans = oeeYuvarla(Math.min((gercekUretim / teorikUretim) * 100, 100));
            } else if (!uretimKayitlari.length && teorikUretim > 0) {
                const gercekCalismaSaati = kullanimlar.reduce((toplam, kullanim) => {
                    const gunlukSaat = Number(kullanim.gunluk_top_calisma_saati || 0);
                    if (gunlukSaat > 0) return toplam + gunlukSaat;
                    return toplam + ((kullanim.bitis_zamani!.getTime() - kullanim.baslangic_zamani!.getTime()) / (1000 * 60 * 60));
                }, 0);

                gercekUretimHesaplanan = Math.round(gercekCalismaSaati * teorikKapasiteSaat * 0.9);
                if (gercekUretimHesaplanan > 0) {
                    performans = oeeYuvarla(Math.min((gercekUretimHesaplanan / teorikUretim) * 100, 100));
                } else {
                    fallbackPerformansKullanildi = true;
                    gercekUretimHesaplanan = Math.round(teorikUretim * 0.9);
                    performans = 90;
                }
            }

            const hataliUretim = uretimKayitlari.reduce((toplam, kayit) => toplam + Number(kayit.hatali_uretim || 0), 0);
            
            let kalite = 95;
            if (gercekUretim > 0) {
                kalite = oeeYuvarla(Math.max(((gercekUretim - hataliUretim) / gercekUretim) * 100, 0));
            } else if (kaliteCevaplari.length) {
                const olumsuzDurumlar = ['NOK', 'Kötü', 'Hatalı', 'Uygun Değil', 'KÖTÜ', 'HATALI'];
                const hataliKontrol = kaliteCevaplari.filter((cevap) => {
                    const durum = cevap.durum || '';
                    return olumsuzDurumlar.some((olumsuz) => durum.toUpperCase().includes(olumsuz.toUpperCase()));
                }).length;
                kalite = oeeYuvarla(((kaliteCevaplari.length - hataliKontrol) / kaliteCevaplari.length) * 100);
            }

            const oeeSkoru = oeeSkoruHesapla(kullanilabilirlik, performans, kalite) ?? 0;

            sonuclar.push({
                makine_id: makineId,
                makine_adi: makine.makine_adi,
                makine_turu: makine.makine_turu.makine_tur_adi,
                oee_skoru: oeeSkoru,
                kullanilabilirlik,
                performans,
                kalite,
            });
        } catch (error: any) {
            hatalar.push({
                makine_id: makine.makine_id,
                makine_adi: makine.makine_adi || "İsimsiz Makine",
                hata: error.message,
            });
        }
    }

    const makineOzetleri = sonuclar.map((sonuc) => ({
        makine_id: sonuc.makine_id,
        makine_adi: sonuc.makine_adi,
        makine_turu: sonuc.makine_turu,
        oee_skoru: sonuc.oee_skoru,
        kullanilabilirlik: sonuc.kullanilabilirlik,
        performans: sonuc.performans,
        kalite: sonuc.kalite,
    }));

    const ortalama = (secici: (sonuc: typeof makineOzetleri[number]) => number) => {
        if (!makineOzetleri.length) return 0;
        return oeeYuvarla(makineOzetleri.reduce((toplam, sonuc) => toplam + secici(sonuc), 0) / makineOzetleri.length);
    };

    const kullanilabilirlik = ortalama((sonuc) => sonuc.kullanilabilirlik);
    const performans = ortalama((sonuc) => sonuc.performans);
    const kalite = ortalama((sonuc) => sonuc.kalite);

    return {
        fabrika_ortalama_oee: oeeSkoruHesapla(kullanilabilirlik, performans, kalite) ?? 0,
        fabrika_bilesenleri: {
            kullanilabilirlik,
            performans,
            kalite,
        },
        donem: {
            baslangic: gunBaslangici(baslangicTarihi).toISOString().split('T')[0],
            bitis: gunBitisi(bitisTarihi).toISOString().split('T')[0],
        },
        fabrika_trend: [{
            week: 'Seçili Dönem',
            oee: oeeSkoruHesapla(kullanilabilirlik, performans, kalite, 1) ?? 0,
            a: kullanilabilirlik,
            p: performans,
            q: kalite,
        }],
        makineler: makineOzetleri,
        hatali_makineler: hatalar,
    };
}
