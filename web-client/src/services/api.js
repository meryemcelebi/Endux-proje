// Mock API Service for adapting Frontend to Prisma schema
// This file simulates backend HTTP requests.

const delay = (ms) => new Promise((res) => setTimeout(res, ms));

export const api = {
  // --- AUTHENTICATION ---
  login: async (credentials) => {
    await delay(500);
    const { kullanici_adi, sifre } = credentials;
    const cleanUser = kullanici_adi?.trim().toLowerCase();

    // Mock authentication logic
    if (cleanUser === "admin" && sifre === "1234") {
      return {
        success: true,
        token: "mock-jwt-token-admin",
        user: { kullanici_id: 0, ad: "Sistem Yöneticisi", rol_id: 1, firma_id: 1 }
      };
    } else if ((cleanUser === "yönetici" || cleanUser === "yonetici") && sifre === "1234") {
      return {
        success: true,
        token: "mock-jwt-token-12345",
        user: { kullanici_id: 1, ad: "yönetici", rol_id: 1, firma_id: 1 }
      };
    } else if ((cleanUser === "operatör" || cleanUser === "operator") && sifre === "1111") {
      return {
        success: true,
        token: "mock-jwt-token-operator",
        user: { kullanici_id: 2, ad: "operatör", rol_id: 3, firma_id: 1 }
      };
    } else if (cleanUser === "servis" && sifre === "2222") {
      return {
        success: true,
        token: "mock-jwt-token-servis",
        user: { kullanici_id: 3, ad: "servis", rol_id: 2, firma_id: 2 }
      };
    }
    throw new Error("Geçersiz kullanıcı adı veya şifre!");
  },
  // --- KULLANICILAR (Kişi Ekle) ---
  getUsers: async () => {
    await delay(300);
    return [
      {
        kullanici_id: 1,
        firma_id: 1,
        rol_id: 1,
        ad: "Ali",
        soyad: "Yılmaz",
        telefon: "5551234567",
        eposta: "ali@example.com",
        kullanici_adi: "ali.yilmaz",
        baslama_tarihi: "2023-01-15",
      }
    ];
  },
  addUser: async (userData) => {
    await delay(500);
    // Prisma modeline uyan veri alınıyor:
    console.log("POST /api/kullanicilar", userData);
    return { ...userData, kullanici_id: Math.floor(Math.random() * 1000) + 100 };
  },

  // --- MAKİNELER (Merkezi Mock Veri) ---
  mockMachines: [
    {
      makine_id: 1,
      firma_id: 1,
      m_tur_id: 1,
      makine_ad: "Pres Makinesi - A101",
      seri_no: ["SN-A101"],
      satin_alma_tarihi: "2022-05-12",
      satin_alma_maliyeti: 50000,

      top_cal_sma_saati: [1200],
      makine_ozellikleri: ["Kapasite: 50 Ton", "Hız: 60 Devir/dk"],
      mevcut_risk_skoru: 0.82, // Yüksek Riskli yapıldı
      aktiflik_durumu: "Aktif",
      makine_qr: "UUID-1001",
      pin: "1234",
      tedarikci: {
        firma_id: 1,
        firma_adi: "Kaan Makine ve Otomasyon A.Ş.",
        telefon: "0850 123 4567",
        email: "iletisim@kaanmakine.com",
        adres: "Ostim OSB, Maltepe Sok. No:5 Ankara"
      }
    },
    {
      makine_id: 2,
      firma_id: 1,
      m_tur_id: 2,
      makine_ad: "CNC Lazer Kesim - L202",
      seri_no: ["SN-B202-X"],
      satin_alma_tarihi: "2023-11-20",
      satin_alma_maliyeti: 85000,
      garanti_suresi: 36,
      top_cal_sma_saati: [450],
      makine_ozellikleri: ["Hassasiyet: 0.001mm", "Güç: 15kW"],
      mevcut_risk_skoru: 0.95, // Yüksek Riskli yapıldı
      aktiflik_durumu: "Aktif",
      makine_qr: "UUID-2002",
      pin: "2222",
      tedarikci: {
        firma_id: 1,
        firma_adi: "Kaan Makine ve Otomasyon A.Ş.",
        telefon: "0850 123 4567",
        email: "iletisim@kaanmakine.com",
        adres: "Ostim OSB, Maltepe Sok. No:5 Ankara"
      }
    },
    {
      makine_id: 3,
      firma_id: 2,
      m_tur_id: 3,
      makine_ad: "Enjeksiyon Makinesi - E500",
      seri_no: ["SN-ENJ-500"],
      satin_alma_tarihi: "2021-02-15",
      satin_alma_maliyeti: 120000,
      garanti_suresi: 48,
      top_cal_sma_saati: [8900],
      makine_ozellikleri: ["Kalıp Kapama: 500 Ton"],
      mevcut_risk_skoru: 0.85,
      aktiflik_durumu: "Arızalı", // Tekrar Arızalı yapıldı
      makine_qr: "UUID-3003",
      pin: "3333",
      tedarikci: {
        firma_id: 2,
        firma_adi: "Marmara Endüstriyel Yağlar",
        telefon: "0216 444 8899",
        email: "satis@marmarayag.com",
        adres: "Gebze OSB, Kocaeli"
      }
    },
    {
      makine_id: 4,
      firma_id: 1,
      m_tur_id: 1,
      makine_ad: "Robotik Kol - R10",
      seri_no: ["SN-ROB-10"],
      satin_alma_tarihi: "2024-01-05",
      satin_alma_maliyeti: 45000,

      top_cal_sma_saati: [200],
      makine_ozellikleri: ["Taşıma: 10kg", "Erişim: 1100mm"],
      mevcut_risk_skoru: 0.02,
      aktiflik_durumu: "Bakımda",
      makine_qr: "UUID-4004",
      pin: "4444",
      tedarikci: {
        firma_id: 1,
        firma_adi: "Kaan Makine ve Otomasyon A.Ş.",
        telefon: "0850 123 4567",
        email: "iletisim@kaanmakine.com",
        adres: "Ostim OSB, Maltepe Sok. No:5 Ankara"
      }
    },
    {
      makine_id: 5,
      firma_id: 3,
      m_tur_id: 2,
      makine_ad: "Hidrolik Güç Ünitesi - H05",
      seri_no: ["SN-5X-001", "SN-5X-001-MOD"],
      satin_alma_tarihi: "2023-06-10",
      satin_alma_maliyeti: 250000,
      garanti_suresi: 60,
      top_cal_sma_saati: [1500],
      makine_ozellikleri: ["X Ekseni: 800mm", "Y Ekseni: 600mm", "Z Ekseni: 500mm", "İş Mili Hızı: 18000 rpm"],
      mevcut_risk_skoru: 0.15,
      aktiflik_durumu: "Bakımda", // Kategoriyle eşleşti
      makine_qr: "UUID-5005",
      pin: "5555",
      tedarikci: {
        firma_id: 3,
        firma_adi: "Gama Otomasyon",
        telefon: "0312 333 4455",
        email: "destek@gamaotomasyon.com",
        adres: "Kemalpaşa, İzmir"
      }
    }
  ],

  getMachines: async () => {
    await delay(300);
    return api.mockMachines;
  },
  getMachineDetails: async (makine_id) => {
    await delay(400);
    const mId = parseInt(makine_id);
    return api.mockMachines.find(m => m.makine_id === mId) || api.mockMachines[0];
  },
  addMachine: async (machineData) => {
    await delay(500);
    console.log("POST /api/makineler", machineData);
    return {
      ...machineData,
      makine_id: Math.floor(Math.random() * 1000) + 100,
      makine_qr: "UUID-" + Date.now(),
      mevcut_risk_skoru: 0
    };
  },

  // --- CHECKLIST / OPERATOR FORMU (gunluk_kontrol_formu) ---
  getChecklistQuestions: async (sablon_id) => {
    await delay(300);
    // Mock kontrol_maddesi entries
    return [
      { madde_id: 101, madde_adi: ["Makine çalışıyor mu?"], veri_tipi: ["Boolean"] },
      { madde_id: 102, madde_adi: ["Yağ seviyesi yeterli mi?"], veri_tipi: ["Boolean"] },
      { madde_id: 103, madde_adi: ["Basınç değeri (Bar)"], veri_tipi: ["Number"], birim: ["Bar"] },
    ];
  },
  submitChecklist: async (formData) => {
    await delay(500);
    console.log("POST /api/kontrol-formu", formData);
    // formData expected format matching Prisma 'gunluk_kontrol_formu':
    // { makine_id: X, kullanici_id: Y, sablon_id: Z, kontrol_tarihi: [...], genel_not: [...], 
    //   cevaplar: [ { madde_id: X, girilen_deger: [...], durum: [...] } ] }
    return { success: true, form_id: Math.floor(Math.random() * 1000) + 100 };
  },

  // --- BAKIM / TEKNIK SERVIS KAYDI ---
  getServiceHistory: async (makine_id) => {
    await delay(300);
    return [
      {
        bakim_id: 2,
        makine_id: makine_id || 1,
        kullanici_id: 3,
        servis_firma_id: 2,
        bakim_turu: ["Ağır Bakım"],
        bakim_tarihi: ["2026-03-25T00:00:00.000Z"],
        bakim_maliyet: [3200],
        aciklama: "Ana motor rulman değişimi yapıldı.",
        ariza_id: 2,
        ariza_sebebi: "Gürültülü Çalışma",
        servis_firmasi: "Marmara Endüstriyel",
        degisen_parcalar: ["Motor Rulmanı Seti", "Dişli Yağı (5L)"],
        puan: 5
      },
      {
        bakim_id: 1,
        makine_id: makine_id || 1,
        kullanici_id: 1,
        servis_firma_id: 2,
        bakim_turu: ["Planlı Bakım"],
        bakim_tarihi: ["2026-01-20T00:00:00.000Z"],
        bakim_maliyet: [1500],
        aciklama: "Yağ değişimi ve genel kontrol tamamlandı",
        ariza_id: 1,
        ariza_sebebi: "Genel Bakım",
        servis_firmasi: "ABC Makine Parçaları",
        degisen_parcalar: ["Hava Filtresi", "Sızdırmazlık Contası"],
        puan: 3
      }
    ];
  },
  // --- TEKNİK SERVİS MERKEZİ (DASHBOARD) ---
  getAllServiceHistory: async () => {
    await delay(300);
    // Temsili tüm makinelerin bakım geçmişi (Dashboard için)
    return [
      {
        bakim_id: 2,
        makine_id: 1,
        makine_ad: "Pres Makinesi - A101",
        bakim_turu: ["Ağır Bakım"],
        bakim_tarihi: ["2026-03-25T00:00:00.000Z"],
        bakim_maliyet: [3200],
        servis_firmasi: "Marmara Endüstriyel",
        ariza_sebebi: "Gürültülü Çalışma",
        aciklama: "Ana motor rulman değişimi yapıldı.",
        puan: 5
      },
      {
        bakim_id: 1,
        makine_id: 2,
        makine_ad: "CNC Lazer Kesim - L202",
        bakim_turu: ["Planlı Bakım"],
        bakim_tarihi: ["2026-01-20T00:00:00.000Z"],
        bakim_maliyet: [1500],
        servis_firmasi: "ABC Makine Parçaları",
        ariza_sebebi: "Genel Bakım",
        aciklama: "Yağ değişimi ve genel kontrol tamamlandı",
        puan: 0
      },
      {
        bakim_id: 3,
        makine_id: 1,
        makine_ad: "Pres Makinesi - A101",
        bakim_turu: ["Acil Müdahale"],
        bakim_tarihi: ["2026-04-01T10:00:00.000Z"],
        bakim_maliyet: [850],
        servis_firmasi: "Kaan Makine",
        ariza_sebebi: "Sensör Arızası",
        aciklama: "Basınç sensörü yenisi ile değiştirildi.",
        puan: 4
      }
    ];
  },

  getTechTasks: async () => {
    await delay(300);
    // Teknisyene atanmış aktif veya tamamlanmış bekleyen işler
    return [
      { id: 101, makine_ad: "Pres Makinesi - A101", ariza_notu: "Basınç sensörü geç okuyor, kontrol edilecek.", durum: "BEKLEYEN", tarih: "2026-04-01" },
      { id: 102, makine_ad: "CNC Lazer Kesim - L202", ariza_notu: "Periyodik yağlama zamanı geldi.", durum: "TAMAMLANDI", tarih: "2026-03-29" },
    ];
  },

  // Puanlanacak firmaları getiren fonksiyon (Dashboard'daki puanlama kartı için)
  getFirmsToRate: async () => {
    await delay(300);
    return [
      { id: 1, ad: "Marmara Endüstriyel", islem_sayisi: 5, ort_puan: 4.2, tip: "Servis" },
      { id: 2, ad: "Kaan Makine", islem_sayisi: 2, ort_puan: 3.0, tip: "Tedarikçi" },
      { id: 3, ad: "ABC Makine Parçaları", islem_sayisi: 3, ort_puan: 1.5, tip: "Servis" },
    ];
  },

  // Tüm kayıtlı servis ve tedarikçi firmalarını getiren fonksiyon (Dropdown listeleri için)
  getFirms: async () => {
    await delay(300);
    // Farklı mock verilerden gelen firmaları birleştirerek döner
    return [
      {
        id: 1,
        ad: "Alfa Teknik Servis",
        tip: "Servis",
        telefon: "0216 111 2233",
        email: "info@alfateknik.com",
        adres: "İstanbul, Kartal",
        uzmanlik_alani: "CNC Mekaniği ve Robotik",
        sorumlu_ad: "Hasan",
        sorumlu_soyad: "Demir",
        sorumlu_tel: "0532 111 2233",
        aktiflik: true,
        ortalama_puan: 4.8,
        kayit_tarihi: "2024-01-10T09:00:00Z"
      },
      {
        id: 2,
        ad: "Beta Endüstriyel Tamir",
        tip: "Servis",
        telefon: "0212 444 5566",
        email: "destek@beta.com",
        adres: "Gebze, Kocaeli",
        uzmanlik_alani: "Elektronik & PCB Tamiri",
        sorumlu_ad: "Kemal",
        sorumlu_soyad: "Yıldız",
        sorumlu_tel: "0544 555 6677",
        aktiflik: true,
        ortalama_puan: 3.2,
        kayit_tarihi: "2024-02-15T11:30:00Z"
      },
      {
        id: 3,
        ad: "Kaan Makine",
        tip: "Tedarikçi",
        telefon: "0850 123 4567",
        email: "info@kaan.com",
        adres: "İzmir, Kemalpaşa",
        aktiflik: true,
        ortalama_puan: 4.2,
        guvenilirlik_skoru: 95,
        veri_no: "TR9876543210",
        yetkili_kisi: "Kaan Demir",
        kayit_tarihi: "2023-05-20T14:45:00Z"
      },
      {
        id: 4,
        ad: "ABC Makine Parçaları",
        tip: "Servis",
        telefon: "0312 333 4455",
        email: "info@abc.com",
        adres: "Ankara, Ostim",
        uzmanlik_alani: "Pres Makineleri Bakımı",
        sorumlu_ad: "Ayhan",
        sorumlu_soyad: "Can",
        sorumlu_tel: "0555 333 4455",
        aktiflik: true,
        ortalama_puan: 4.5,
        kayit_tarihi: "2024-03-01T10:00:00Z"
      },
      {
        id: 5,
        ad: "Gama Otomasyon",
        tip: "Tedarikçi",
        telefon: "0232 555 6677",
        email: "info@gama.com",
        adres: "Bursa, Nilüfer",
        aktiflik: true,
        ortalama_puan: 3.8,
        guvenilirlik_skoru: 82,
        veri_no: "TR1122334455",
        yetkili_kisi: "Zeynep Aydın",
        kayit_tarihi: "2023-11-12T16:20:00Z"
      }
    ];
  },

  // Sisteme yeni bir firma (tedarikçi veya servis) ekleyen fonksiyon
  addFirm: async (firmData) => {
    await delay(500);
    // Simüle edilen POST isteği
    console.log("POST /api/firmalar", firmData);
    return { ...firmData, id: Math.floor(Math.random() * 1000) + 100, islem_sayisi: 0, ort_puan: 0 };
  },

  // Bir bakım kaydı ekleyen fonksiyon
  addServiceRecord: async (recordData) => {
    await delay(500);
    console.log("POST /api/bakim-kaydi", recordData);
    return {
      ...recordData,
      bakim_id: Math.floor(Math.random() * 1000) + 100,
    };
  },

  // Bir firmaya puan veren fonksiyon
  rateFirm: async (firmaId, puan) => {
    await delay(400);
    console.log(`Firma ${firmaId} için ${puan} yıldız verildi.`);
    return { success: true, yeni_puan: puan };
  },

  // Spesifik bir bakım kaydını puanlayan fonksiyon
  rateServiceRecord: async (bakim_id, puan) => {
    await delay(300);
    console.log(`Bakım Kaydı ${bakim_id} için ${puan} puan verildi.`);
    return { success: true, yeni_puan: puan };
  },

  // --- YENİ SERVİS GİRİŞ AKIŞI (PIN + TELEFON) ---
  mockServisSorumlulari: [
    { id: 1, ad_soyad: "Ahmet Usta", telefon: "05321112233", unvan: "Mekanikçi", firma_id: 1 }
  ],

  checkServiceLogin: async (data) => {
    await delay(800);
    const { makine_id, telefon, ad_soyad, unvan, firma_id, pin } = data;

    // 1. ADIM: PIN Kontrolü
    const makine = api.mockMachines.find(m => m.makine_id === parseInt(makine_id));
    if (!makine) throw new Error("Makine bulunamadı!");
    if (makine.pin !== pin) throw new Error("Geçersiz Makine PIN Kodu!");

    // 2. ADIM: Telefon Numarası Kontrolü
    let kisi = api.mockServisSorumlulari.find(s => s.telefon === telefon);
    let isNew = false;

    if (!kisi) {
      // (A) Kayıt yoksa: Yeni kayıt oluştur (INSERT)
      isNew = true;
      kisi = {
        id: Math.floor(Math.random() * 1000) + 100,
        ad_soyad,
        telefon,
        unvan,
        firma_id: parseInt(firma_id)
      };
      api.mockServisSorumlulari.push(kisi);
      console.log("Yeni Servis Sorumlusu Kaydedildi:", kisi);
    }

    // 3. ADIM: Giriş Başarılı (Mock Token ve User verisi)
    return {
      success: true,
      isNew: isNew,
      user: {
        kullanici_id: kisi.id,
        ad: kisi.ad_soyad,
        rol_id: 2, // Misafir Servis/Teknisyen rolü
        firma_id: kisi.firma_id
      },
      token: "mock-jwt-service-guest-" + Date.now()
    };
  }
};
