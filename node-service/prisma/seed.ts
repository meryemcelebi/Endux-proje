import { v4 as uuidv4 } from "uuid";
import { Prisma } from "@prisma/client";
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

    // 1.5 Rol ve Yönetici (Admin) Kullanıcısı
    const roller = ["YONETICI", "TEKNISYEN", "OPERATOR"];
    for (let i = 0; i < roller.length; i++) {
        let rol = await prisma.rol.findFirst({ where: { rol_id: i + 1 } });
        if (!rol) {
            await prisma.rol.create({ data: { rol_id: i + 1, rol_adi: roller[i] } });
        }
    }

    let admin = await prisma.kullanici.findFirst({ where: { kullanici_adi: "YON_admin" } });
    if (!admin) {
        // "admin" şifresinin bcrypt hash'i
        const hashedSifre = "$2b$10$cC4GHQEzL0f7CQvnBqmVY.dVP5rIRZCo6QEocGfSW9fo4Tb6nEKzi";
        admin = await prisma.kullanici.create({
            data: {
                firma_id: firma.firma_id,
                rol_id: 1, // YONETICI
                ad: "Sistem",
                soyad: "Yöneticisi",
                telefon: "5550000000",
                eposta: "admin@endux.com",
                kullanici_adi: "YON_admin",
                sifre: hashedSifre,
                aktiflik: true,
                baslama_tarihi: new Date()
            }
        });
        console.log("YON_admin kullanıcısı başarıyla eklendi.");
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
    let makineTurleri = [];
    for (const t of makineTurleriRaw) {
        let tur = await prisma.makine_turu.findFirst({ where: { makine_tur_adi: t.ad } });
        if (!tur) {
            tur = await prisma.makine_turu.create({ data: { makine_tur_adi: t.ad, risk_katsayisi: t.risk } });
        }
        makineTurleri.push(tur);
    }

    // 4. Parçalar (Sahte Veriler dosyasındakiler)
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

    const ozelMaddeler = {
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
            // @ts-ignore
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

    // 6. Garanti Firması ve Servis Firması Tanımlama
    let iletisim = await prisma.iletisim.findFirst({ where: { mail: "destek@genelyedekparca.com" } });
    if (!iletisim) {
        iletisim = await prisma.iletisim.create({
            data: {
                telefon: "+90 555 123 4567",
                mail: "destek@genelyedekparca.com",
                acik_adres: "Endüstri Sanayi Sitesi, 1. Blok No:4, İstanbul"
            }
        });
    }

    let garantiFirma = await prisma.garanti_firma.findFirst();
    if (!garantiFirma) {
        garantiFirma = await prisma.garanti_firma.create({
            data: {
                firma_adi: "Genel Makine İthalat İhracat A.Ş.",
                iletisim_id: iletisim.iletisim_id
            }
        });
    }

    let servisFirma = await prisma.servis_firma.findFirst();
    if (!servisFirma) {
        servisFirma = await prisma.servis_firma.create({
            data: { firma_adi: "Güvenilir Servis A.Ş.", aktiflik: true, iletisim_id: iletisim.iletisim_id }
        });
    }

    let bakimTuru = await prisma.bakim_turu.findFirst();
    if (!bakimTuru) {
        bakimTuru = await prisma.bakim_turu.create({ data: { bakim_tur_adi: "Ağır Bakım" } });
    }

    let operator = await prisma.kullanici.findFirst({ where: { rol_id: 3 } });
    if (!operator) operator = await prisma.kullanici.findFirst();

    // 7. 100 Adet Makine ve Özellikleri
    console.log("Mevcut sahte test verileri temizleniyor...");
    await prisma.oee_raporlari.deleteMany({});
    await prisma.uretim_kaydi.deleteMany({});
    await prisma.durus_kaydi.deleteMany({});
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

    console.log("100 Adet YENİ kurallara uygun makine (Geçmiş servis/kontrol kayıtlarıyla) üretiliyor...");
    for (let i = 1; i <= 100; i++) {
        const rndIndex = Math.floor(Math.random() * makineTurleri.length);
        const secilenTur = makineTurleri[rndIndex];
        const seri = `SNO-${uuidv4().substring(0, 8).toUpperCase()}`;

        const isSifir = Math.random() > 0.6; // %40 ihtimalle ikinci el
        const isArizali = Math.random() < 0.2; // %20 ihtimalle cihaz arızalı
        const satinAlmaGecmisTarih = new Date(Date.now() - Math.floor(Math.random() * 200000000000));

        const m = await prisma.makine.create({
            data: {
                firma_id: firma.firma_id,
                makine_tur_id: secilenTur.makine_tur_id,
                makine_adi: `${secilenTur.makine_tur_adi} - Ünite ${i}${isSifir ? " (Sıfır)" : " (2.El)"}`,
                satin_alma_tarihi: isSifir ? new Date() : satinAlmaGecmisTarih,
                satin_alma_maliyeti: Math.floor(Math.random() * 500000) + 100000,
                aktiflik_durumu: isArizali ? false : true,
                seri_no: seri,
                garanti_suresi: isSifir ? 24 : 0,
                garanti_firma_id: garantiFirma.garanti_firma_id,
                servis_pin: Math.floor(1000 + Math.random() * 9000),
                toplam_calisma_saati: isSifir ? 0 : Math.floor(Math.random() * 15000)
            }
        });

        // Risk skoru
        await prisma.risk_skoru.create({
            data: {
                makine_id: m.makine_id,
                risk_skoru: isArizali ? 0.9 : Math.random() * 0.4,
                risk_seviyesi: isArizali ? 'YUKSEK' : 'DUSUK',
                hesaplama_tarihi: new Date()
            }
        });

        let teknikSpecs = {
            kimlikBilgileri: {
                makineModel: `${secilenTur.makine_tur_adi} - ${seri.substring(4, 7)} Serisi`,
                uretici: "Endux Endüstriyel Makine Sistemleri A.Ş.",
                uretimYili: isSifir ? 2024 : 2018 + (i % 6)
            },
            teknikSpesifikasyonlar: {
                gucTuketimi_kW: parseFloat((Math.random() * (100 - 15) + 15).toFixed(1)),
                calismaGerilimi_V: Math.random() > 0.5 ? 380 : 220,
                kapasite_BirimSaat: Math.floor(Math.random() * 500) + 50,
                agirlik_kg: Math.floor(Math.random() * 10000) + 500,
                boyutlar_mm: {
                    en: Math.floor(Math.random() * 3000) + 1000,
                    boy: Math.floor(Math.random() * 5000) + 1500,
                    yukseklik: Math.floor(Math.random() * 2500) + 1200
                }
            },
            operasyonelDurum: {
                kritiklikSeviyesi: isArizali ? "A" : (Math.random() > 0.5 ? "B" : "C"),
                departmanHatti: `Üretim Hattı - ${Math.floor(Math.random() * 5) + 1}`
            },
            dokumantasyon: {
                kilavuzLinkleri: [
                    { baslik: "Kullanım Kılavuzu", url: `https://endux.com/docs/${seri}-kullanim.pdf` },
                    { baslik: "Periyodik Bakım Prosedürü", url: `https://endux.com/docs/${seri}-bakim.pdf` }
                ],
                isoStandartlari: ["ISO 9001", "ISO 45001"]
            }
        };
        await prisma.makine_ozellikleri.create({
            data: { makine_id: m.makine_id, teknik_ozellikler: teknikSpecs }
        });

        // LOKASYON EKLEME (Harita için kritik)
        const kat = (i % 5 < 3) ? "Zemin" : "1.Kat";
        const alanlar = kat === "Zemin"
            ? ["BÖLGE 1", "BÖLGE 2", "BÖLGE 3", "DEPO"]
            : ["BÖLGE D", "TEKNİK", "OFİS", "KALİTE"];
        const secilenAlan = alanlar[Math.floor(Math.random() * alanlar.length)];

        await prisma.lokasyon.create({
            data: {
                makine_id: m.makine_id,
                firma_id: firma.firma_id,
                kat: kat,
                fabrika_alani: secilenAlan,
                x_koor: new Prisma.Decimal(Math.floor(Math.random() * 80) + 10), // %10-90 arası
                y_koor: new Prisma.Decimal(Math.floor(Math.random() * 80) + 10),
                guncelleme_tarihi: new Date()
            }
        });

        // ARIZALI ise veya eski makine ise Bakım Kayıtları Oluştur
        if (isArizali || (!isSifir && Math.random() > 0.5)) {
            const bakimSayisi = isArizali ? 3 : 1;
            for (let k = 0; k < bakimSayisi; k++) {
                await prisma.bakim_kaydi.create({
                    data: {
                        makine_id: m.makine_id,
                        servis_firma_id: servisFirma.servis_firma_id,
                        bakim_tur_id: bakimTuru.bakim_tur_id,
                        bakim_maliyet: new Prisma.Decimal(Math.floor(Math.random() * 15000) + 1500),
                        aciklama: (isArizali && k === 0) ? "Makine arızaya geçti, motor sürücüleri yandı." : "Periyodik genel bakım tamamlandı.",
                        bakim_tarihi: new Date(Date.now() - Math.floor(Math.random() * 10000000000)),
                    }
                });
            }
        }

        // Günlük Kontrol Formu
        if (!isSifir && operator) {
            const sablon = await prisma.kontrol_sablonu.findFirst({ where: { makine_tur_id: secilenTur.makine_tur_id } });
            if (sablon) {
                const formSayisi = 3;
                const maddeler = await prisma.kontrol_maddesi.findMany({ where: { sablon_id: sablon.sablon_id } });
                for (let c = 0; c < formSayisi; c++) {
                    const form = await prisma.gunluk_kontrol_formu.create({
                        data: {
                            makine_id: m.makine_id,
                            kullanici_id: operator.kullanici_id,
                            sablon_id: sablon.sablon_id,
                            kontrol_tarihi: new Date(Date.now() - (c * 86400000)),
                            genel_not: (isArizali && c === 0) ? "Ciddi titreşim ve ses var, makineyi kapattım!" : "Her şey normal.",
                            ai_on_risk_durumu: (isArizali && c === 0) ? 0.95 : Math.random() * 0.2,
                        }
                    });

                    if (maddeler.length > 0) {
                        await prisma.form_madde_cevap.createMany({
                            data: maddeler.map(madde => ({
                                form_id: form.form_id,
                                soru_referans_id: madde.madde_id,
                                girilen_deger: (isArizali && c === 0 && (madde.madde_adi?.includes("Anomalisi") || madde.madde_adi?.includes("Ses"))) ? "EVET" : "HAYIR"
                            }))
                        });
                    }
                }
            }
        }
    }

    console.log("✅ 100 Adet makine üretimi tamamlandı. Şimdi senaryo bazlı mock veriler ekleniyor...");

    // --- SENARYO BAZLI EKLEMELER ---
    const allMachines = await prisma.makine.findMany();
    const arizaTuru = await prisma.ariza_turu.findFirst() || await prisma.ariza_turu.create({ data: { ariza_tur: "Donanım Arızası" } });

    // 1. DIŞ SERVİS FİRMALARI VE PUANLAMALAR
    const serviceFirmsData = [
        { name: "ProMekanik Genel Bakım", expertise: "Genel Mekanik", targetAvg: 4.8 },
        { name: "FixIt Elektronik & PCB", expertise: "Elektronik & PCB", targetAvg: 2.1 },
        { name: "Robotix Otomasyon", expertise: "Robotik", targetAvg: 4.2 },
        { name: "SpindleMaster Revizyon", expertise: "Motor & Spindle", targetAvg: 3.8 }
    ];

    for (const item of serviceFirmsData) {
        let sFirma = await prisma.servis_firma.findFirst({ where: { firma_adi: item.name } });
        if (!sFirma) {
            sFirma = await prisma.servis_firma.create({
                data: {
                    firma_adi: item.name,
                    aktiflik: true,
                    servis_firma_uzmanlik: { create: { uzmanlik_adi: item.expertise } }
                }
            });
        }
        for (let i = 0; i < 10; i++) {
            let score = item.targetAvg > 4 ? (Math.random() > 0.1 ? 5 : 4) : (item.targetAvg < 2.5 ? (Math.random() > 0.2 ? 2 : 1) : Math.floor(Math.random() * 3) + 2);
            await prisma.servis_puan.create({
                data: {
                    servis_firma_id: sFirma.servis_firma_id,
                    puanlayan_kullanici_id: admin.kullanici_id,
                    puan: score,
                    yorum: score >= 4 ? "Zamanında ve kaliteli hizmet." : "Teknik destek zayıf.",
                    tarih: new Date(Date.now() - Math.floor(Math.random() * 30 * 24 * 60 * 60 * 1000))
                }
            });
        }
    }

    // 2. TEDARİKÇİ VE KRİTİK PARÇA SENARYOSU
    let kaanSup = await prisma.tedarikci.findFirst({ where: { firma_adi: "Kaan Sensör Teknolojileri" } });
    if (!kaanSup) {
        kaanSup = await prisma.tedarikci.create({
            data: { firma_adi: "Kaan Sensör Teknolojileri", aktiflik: true, guvenilirlik_skoru: 45, vergi_no: "VN123456" }
        });
    }

    let badPart = await prisma.parca.findFirst({ where: { parca_adi: "Pto Sensör X-V2" } });
    if (!badPart) {
        badPart = await prisma.parca.create({
            data: {
                parca_adi: "Pto Sensör X-V2",
                tahmini_omur_saati: 1500,
                parca_maliyeti: 2450,
                tedarik_gun_suresi: 12,
                stok_miktari: 5,
                min_stok_seviyesi: 15,
                tedarikci_id: kaanSup.tedarikci_id
            }
        });
    }

    for (let i = 0; i < 4; i++) {
        const bk = await prisma.bakim_kaydi.create({
            data: {
                makine_id: allMachines[0].makine_id,
                servis_firma_id: (await prisma.servis_firma.findFirst())!.servis_firma_id,
                bakim_maliyet: new Prisma.Decimal(3500),
                bakim_tarihi: new Date(Date.now() - (i * 15 * 24 * 60 * 60 * 1000)),
                aciklama: `Hatalı okuma nedeniyle ${badPart.parca_adi} değişimi.`
            }
        });
        await prisma.parca_degisim.create({ data: { bakim_id: bk.bakim_id, parca_id: badPart.parca_id, adet: 1 } });
    }

    // 3. BAKIM DASHBOARD DURUMLARI (Açık, Devam Eden, Planlı ve Maliyet)
    for (let i = 1; i <= 4; i++) { // Açık Arızalar
        await prisma.ariza_kaydi.create({
            data: { makine_id: allMachines[i].makine_id, ariza_tespit_kaynagi: "AI Tahmin", ariza_aciklama: "Vibrasyon hatası.", baslangic_zamani: new Date(), ariza_tur_id: arizaTuru.ariza_tur_id }
        });
        await prisma.makine.update({ where: { makine_id: allMachines[i].makine_id }, data: { aktiflik_durumu: false } });
    }
    const currentServis = (await prisma.servis_firma.findFirst())!.servis_firma_id;
    for (let i = 5; i <= 6; i++) { // Devam Eden
        await prisma.bakim_kaydi.create({ data: { makine_id: allMachines[i].makine_id, servis_firma_id: currentServis, bakim_maliyet: new Prisma.Decimal(0), bakim_tarihi: new Date(), aciklama: "Bakım devam ediyor." } });
    }
    for (let i = 7; i <= 10; i++) { // Planlı
        await prisma.bakim_kaydi.create({ data: { makine_id: allMachines[i].makine_id, servis_firma_id: currentServis, bakim_maliyet: new Prisma.Decimal(0), bakim_tarihi: new Date(Date.now() + (10 * 24 * 60 * 60 * 1000)), aciklama: "Planlı Bakım" } });
    }
    const costM = [18500, 12400, 14100]; // Bu Ay Maliyeti
    for (let i = 0; i < costM.length; i++) {
        await prisma.bakim_kaydi.create({ data: { makine_id: allMachines[15 + i].makine_id, servis_firma_id: currentServis, bakim_maliyet: new Prisma.Decimal(costM[i]), bakim_tarihi: new Date(new Date().getFullYear(), new Date().getMonth(), 5 + i), aciklama: "Ağır bakım maliyeti." } });
    }

    console.log("OEE, Üretim ve Duruş verileri üretiliyor...");

    for (const makine of allMachines) {
        for (let j = 0; j < 30; j++) {
            const date = new Date();
            date.setDate(date.getDate() - j);
            date.setHours(0, 0, 0, 0);

            const planlanan_sure_dk = 480;
            const durus_sure_dk = Math.floor(Math.random() * 61); // 0-60 dk arası
            const fiili_sure_dk = planlanan_sure_dk - durus_sure_dk;
            const teorik_uretim = 1000;

            // %80 ile %98 arası
            const percentGercek = 0.8 + Math.random() * 0.18;
            const gercek_uretim = Math.floor(teorik_uretim * percentGercek);

            // %1 ile %5 arası
            const percentHatali = 0.01 + Math.random() * 0.04;
            const hatali_uretim = Math.floor(gercek_uretim * percentHatali);

            await prisma.uretim_kaydi.create({
                data: {
                    makine_id: makine.makine_id,
                    vardiya_tarihi: date,
                    vardiya_turu: "Gündüz",
                    planlanan_sure_dk,
                    fiili_sure_dk,
                    durus_sure_dk,
                    teorik_uretim,
                    gercek_uretim,
                    hatali_uretim
                }
            });

            if (durus_sure_dk > 0) {
                const nedenler = ["Mekanik Arıza", "Ayar", "Parça Bekleme"];
                const neden = nedenler[Math.floor(Math.random() * nedenler.length)];

                await prisma.durus_kaydi.create({
                    data: {
                        makine_id: makine.makine_id,
                        vardiya_tarihi: date,
                        baslangic_saati: new Date(date.getTime() + 8 * 60 * 60 * 1000), // Gündüz 08:00
                        bitis_saati: new Date(date.getTime() + 8 * 60 * 60 * 1000 + durus_sure_dk * 60 * 1000),
                        durus_sure_dk,
                        durus_nedeni: neden
                    }
                });
            }

            const kullanilabilirlik_orani = (fiili_sure_dk / planlanan_sure_dk) * 100;
            const performans_orani = (gercek_uretim / teorik_uretim) * 100;
            const saglam_uretim = gercek_uretim - hatali_uretim;
            const kalite_orani = (saglam_uretim / gercek_uretim) * 100;
            const oee_skoru = (kullanilabilirlik_orani / 100) * (performans_orani / 100) * (kalite_orani / 100) * 100;

            await prisma.oee_raporlari.create({
                data: {
                    makine_id: makine.makine_id,
                    tarih: date,
                    kullanilabilirlik_orani: parseFloat(kullanilabilirlik_orani.toFixed(2)),
                    performans_orani: parseFloat(performans_orani.toFixed(2)),
                    kalite_orani: parseFloat(kalite_orani.toFixed(2)),
                    oee_skoru: parseFloat(oee_skoru.toFixed(2))
                }
            });
        }
    }

    console.log("✅ Seed işlemi %100 tamamlandı! Tüm senaryo verileri eklendi.");
}

main()
    .catch((e) => {
        console.error(e);
        process.exit(1);
    })
    .finally(async () => {
        await prisma.$disconnect();
    });
