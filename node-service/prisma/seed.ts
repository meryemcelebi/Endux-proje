import { v4 as uuidv4 } from "uuid";
import prisma from "../src/config/prisma";

async function main() {
    console.log("Seeding işlemi başlatılıyor...");

    // 1. İletişim ve Firma (Varsayılan)
    let firma = await prisma.firma.findFirst();
    if (!firma) {
        firma = await prisma.firma.create({
            data: {
                firma_adi: "Varsayılan Endux Firması",
                aktif_mi: true,
                vergi_no: "9876543210",
            }
        });
    }

    // 2. Tedarikçi
    let tedarikci = await prisma.tedarikci.findFirst();
    if (!tedarikci) {
        tedarikci = await prisma.tedarikci.create({
            data: {
                firma_adi: "Genel Yedek Parça A.Ş.",
                aktiflik: true,
                guvenilirlik_skoru: 95.5,
            }
        });
    }

    // 3. Makine Türleri
    const makineTurleriRaw = [
        { ad: "CNC Makinesi", risk: 1.5 },
        { ad: "Pres Makinesi", risk: 2.0 },
        { ad: "Plastik Enjeksiyon Makinesi", risk: 1.8 }
    ];
    let makineTurleri: any[] = [];
    for (const t of makineTurleriRaw) {
        let tur = await prisma.makine_turu.findFirst({ where: { makine_tur_adi: t.ad } });
        if (!tur) {
            tur = await prisma.makine_turu.create({ data: { makine_tur_adi: t.ad, risk_katsayisi: t.risk } });
        }
        makineTurleri.push(tur);
    }

    // 4. Parçalar (Sahte Veriler)
    const parcaListesi = [
        { ad: "Kesici Takım / İş Mili (Spindle) Rulmanları", omur: 8000 },
        { ad: "X-Y-Z Eksen Motorları ve Sürücüleri", omur: 15000 },
        { ad: "Pnömatik Mengene Valfi", omur: 12000 },
        { ad: "Bor Yağı Pompası", omur: 10000 },
        { ad: "Ana Hidrolik Pompa", omur: 15000 },
        { ad: "Hidrolik Yön Valfleri ve Keçeler", omur: 10000 },
        { ad: "Mekanik Gövde / Kılavuz Yatakları", omur: 30000 },
        { ad: "Isıtıcı Rezistans Bantları", omur: 8000 },
        { ad: "Enjeksiyon Vidası ve Kovan (Barel)", omur: 20000 },
        { ad: "Kalıp Soğutma Valfleri (Eşanjör)", omur: 12000 },
    ];
    for (const p of parcaListesi) {
        let eParca = await prisma.parca.findFirst({ where: { parca_adi: p.ad } });
        if (!eParca) {
            await prisma.parca.create({
                data: {
                    parca_adi: p.ad,
                    tahmini_omur_saati: p.omur,
                    parca_maliyeti: 5000,
                    tedarik_gun_suresi: 7,
                    tedarikci_id: tedarikci.tedarikci_id
                }
            });
        }
    }

    // 5. Şablonlar ve Kontrol Maddeleri
    const ortakMaddeler = [
        { ad: "Sıcaklık Anomalisi", alan: "sicaklik" },
        { ad: "Titreşim Anomalisi", alan: "titresim" },
        { ad: "Ses Anomalisi", alan: "ses_anomalisi" },
        { ad: "Yağ Kaçağı/Durumu", alan: "yag_durumu" },
        { ad: "Form Doldurma Süresi (sn)", alan: "form_doldurma_suresi_sn" }
    ];

    const ozelMaddeler: Record<string, { ad: string; alan: string }[]> = {
        "CNC Makinesi": [
            { ad: "İş Mili Ses ve Titreşim", alan: "is_mili_ses_ve_titresim" },
            { ad: "Eksen Ölçü Sapması", alan: "eksen_olcu_sapmasi" },
            { ad: "Takım Zorlanma Durumu", alan: "takim_zorlanma_durumu" },
            { ad: "İşlenen Yüzey Kalitesi", alan: "islenen_yuzey_kalitesi" },
            { ad: "İş Mili Gövde Sıcaklığı", alan: "is_mili_govde_sicakligi" },
            { ad: "Bor Yağı ve Soğutma", alan: "bor_yagi_ve_sogutma" },
            { ad: "Pnömatik Hava Basıncı", alan: "pnomatik_hava_basinci" },
            { ad: "Kızak Yağ Seviyesi", alan: "kizak_yag_seviyesi" }
        ],
        "Pres Makinesi": [
            { ad: "Hidrolik Basınç Seviyesi", alan: "hidrolik_basinc_seviyesi" },
            { ad: "Hidrolik Yağ Sıcaklığı", alan: "hidrolik_yag_sicakligi" },
            { ad: "Yağ Kaçak Durumu", alan: "yag_kacak_durumu" },
            { ad: "Koç Vuruntu Sesi", alan: "koc_vuruntu_sesi" },
            { ad: "Koç Kılavuz Boşluğu", alan: "koc_kilavuz_boslugu" },
            { ad: "Kavrama Fren Hava Basıncı", alan: "kavrama_fren_hava_basinci" },
            { ad: "Tonaj Sapması", alan: "tonaj_sapmasi" },
            { ad: "Basılan Parça Kalitesi", alan: "basilan_parca_kalitesi" }
        ],
        "Plastik Enjeksiyon Makinesi": [
            { ad: "Kovan Rezistans Sıcaklığı", alan: "kovan_rezistans_sicakligi" },
            { ad: "Eriyik Plastik Kokusu", alan: "eriyik_plastik_kokusu" },
            { ad: "Vida Dönüş Sesi", alan: "vida_donus_sesi" },
            { ad: "Enjeksiyon Baskı Basıncı", alan: "enjeksiyon_baski_basinci" },
            { ad: "Mengene Kapanma Basıncı", alan: "mengene_kapanma_basinci" },
            { ad: "Kalıp Soğutma Suyu Debisi", alan: "kalip_sogutma_suyu_debisi" },
            { ad: "Soğutma Suyu Sıcaklığı", alan: "sogutma_suyu_sicakligi" },
            { ad: "Eksik Baskı Durumu", alan: "eksik_baski_durumu" },
            { ad: "Çapaklı Baskı Durumu", alan: "capakli_baski_durumu" }
        ]
    };

    for (const mt of makineTurleri) {
        let sablon = await prisma.kontrol_sablonu.findFirst({
            where: { makine_tur_id: mt.makine_tur_id, sablon_adi: "Günlük Operatör Kontrolü" }
        });
        if (!sablon) {
            sablon = await prisma.kontrol_sablonu.create({
                data: {
                    makine_tur_id: mt.makine_tur_id,
                    sablon_adi: "Günlük Operatör Kontrolü",
                    aciklama: `${mt.makine_tur_adi} için günlük operatör kontrol formu.`,
                    aktiflik: true,
                }
            });

            // Maddeleri ekle
            const eklenecekMaddeler = [...ortakMaddeler, ...(ozelMaddeler[mt.makine_tur_adi] || [])];
            for (const mad of eklenecekMaddeler) {
                await prisma.kontrol_maddesi.create({
                    data: {
                        sablon_id: sablon.sablon_id,
                        madde_adi: mad.ad,
                        teknik_parametre: mad.alan,
                        kritiklik_durumu: false
                    }
                });
            }
        }
    }

    // 6. 100 Adet Makine ve Özellikleri
    console.log("Mevcut sahte test verileri temizleniyor...");
    
    // Bağımlı tabloları temizle (Sıralama FK kısıtlamalarına göre)
    await prisma.parca_degisim.deleteMany({});
    await prisma.bakim_kaydi.deleteMany({});
    await prisma.arizayi_tetikleyen_form.deleteMany({});
    await prisma.ariza_kaydi.deleteMany({});
    await prisma.form_madde_cevap.deleteMany({});
    await prisma.ai_ariza_tespit.deleteMany({});
    await prisma.ai_model_log.deleteMany({});
    await prisma.gunluk_kontrol_formu.deleteMany({});
    await prisma.lokasyon.deleteMany({});
    await prisma.makine_kullanim.deleteMany({});
    await prisma.risk_skoru.deleteMany({});
    await prisma.makine_ozellikleri.deleteMany({});
    await prisma.makine.deleteMany({});

    console.log("100 Adet YENİ kurallara (Sıfır/2.El, Arızalı/Aktif, 4 Haneli PIN) uygun makine üretiliyor...");
    for (let i = 1; i <= 100; i++) {
        const rndIndex = Math.floor(Math.random() * makineTurleri.length);
        const secilenTur = makineTurleri[rndIndex];
        const seri = `SNO-${uuidv4().substring(0, 8).toUpperCase()}`;

        // Yeni Kurallar Belirleniyor:
        const isSifir = Math.random() > 0.5; // %50 ihtimalle sıfır makine
        const isArizali = Math.random() < 0.2; // %20 ihtimalle cihaz arızalı (aktiflik_durumu: false)
        const satinAlmaGecmisTarih = new Date(Date.now() - Math.floor(Math.random() * 200000000000)); // Eskiyse geçmis tarih

        const m = await prisma.makine.create({
            data: {
                firma_id: firma.firma_id,
                makine_tur_id: secilenTur.makine_tur_id,
                makine_adi: `${secilenTur.makine_tur_adi} - Gövde ${i}${isSifir ? " (Sıfır)" : " (2.El)"}`,
                satin_alma_tarihi: isSifir ? new Date() : satinAlmaGecmisTarih,
                satin_alma_maliyeti: Math.floor(Math.random() * 500000) + 100000,
                aktiflik_durumu: isArizali ? false : true,
                seri_no: seri,
                garanti_suresi: isSifir ? 24 : 0, // Sıfırsa 2 yıl, 2. Else yok
                servis_pin: Math.floor(1000 + Math.random() * 9000), // Kesinlikle 4 Haneli PIN (Örn: 4215)
                toplam_calisma_saati: isSifir ? 0 : Math.floor(Math.random() * 15000) // Sıfırsa 0 saat
            }
        });

        // Makine özellikleri JSON - ayrı tabloya kaydet
        const teknikSpecs = {
            araba_kodu: seri.toLowerCase(),
            montaj_yili: isSifir ? 2024 : 2020 + (i % 5),
            periyodik_bakim_zorunlu_mu: true,
            statu: isArizali ? 'ARIZALI/PASİF' : 'AKTİF/ÇALIŞIYOR'
        };
        await prisma.makine_ozellikleri.create({
            data: {
                makine_id: m.makine_id,
                teknik_ozellikler: teknikSpecs
            }
        });
    }

    console.log("✅ Seed işlemi %100 tamamlandı! 100 sahte makine, parçalar ve kontrol şablonları eklendi.");
}

main()
    .catch((e) => {
        console.error(e);
        process.exit(1);
    })
    .finally(async () => {
        await prisma.$disconnect();
    });
