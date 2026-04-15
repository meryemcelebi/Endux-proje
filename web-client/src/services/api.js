const API_BASE = "/api"; // Vite proxy ile backend'e yönlendirilir

const getHeaders = () => ({
  "Content-Type": "application/json",
  Authorization: `Bearer ${localStorage.getItem("auth_token")}`,
});

const handleResponse = async (res) => {
  const json = await res.json();
  if (!res.ok) throw new Error(json.message || json.hata || json.error || "İstek başarısız");
  return json;
};

export const api = {

  // ═══════════════ 1. LOGIN ═══════════════
  // POST /api/auth/login
  login: async (credentials) => {
    const res = await fetch(`${API_BASE}/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(credentials),
    });
    const json = await handleResponse(res);
    const rolMap = { YONETICI: 1, TEKNISYEN: 2, OPERATOR: 3 };
    return {
      success: json.success,
      token: json.token,
      user: {
        kullanici_id: json.data.kullanici_id,
        ad: json.data.ad,
        rol_id: rolMap[json.data.rol] ?? json.data.rol_id ?? 3,
        firma_id: json.data.firma_id,
      },
    };
  },

  // ═══════════════ 2. MAKİNE LİSTELE ═══════════════
  // GET /api/makineler
  getMachines: async () => {
    const res = await fetch(`${API_BASE}/makineler`, { headers: getHeaders() });
    const json = await handleResponse(res);
    return (json.data || []).map((m) => ({
      ...m,
      aktiflik_durumu: m.aktiflik_durumu === true ? "Aktif" : "Pasif",
      mevcut_risk_skoru: Number(m.mevcut_risk_skoru || 0),
      satin_alma_maliyeti: Number(m.satin_alma_maliyeti || 0),
      top_calisma_saati: Number(m.toplam_calisma_saati || 0),
    }));
  },

  // ═══════════════ 3. MAKİNE DETAY ═══════════════
  // GET /api/makineler/:id
  getMachineDetails: async (makine_id) => {
    const res = await fetch(`${API_BASE}/makineler/${makine_id}`, { headers: getHeaders() });
    const json = await handleResponse(res);
    const m = json.data;
    return {
      ...m,
      aktiflik_durumu: m.aktiflik_durumu === true ? "Aktif" : "Pasif",
      mevcut_risk_skoru: Number(m.mevcut_risk_skoru || 0),
      satin_alma_maliyeti: Number(m.satin_alma_maliyeti || 0),
      top_calisma_saati: Number(m.toplam_calisma_saati || 0),
      tedarikci: m.firma ? { firma_id: m.firma.firma_id, firma_adi: m.firma.firma_adi } : null,
    };
  },

  // ═══════════════ 4. MAKİNE EKLE ═══════════════
  // POST /api/makineler
  addMachine: async (machineData) => {
    const res = await fetch(`${API_BASE}/makineler`, {
      method: "POST", headers: getHeaders(),
      body: JSON.stringify({
        makine_adi: machineData.makine_ad || machineData.makine_adi,
        firma_id: Number(machineData.firma_id),
        makine_tur_id: Number(machineData.m_tur_id || machineData.makine_tur_id),
        seri_no: String(machineData.seri_no),
        satin_alma_tarihi: machineData.satin_alma_tarihi,
        satin_alma_maliyeti: Number(machineData.satin_alma_maliyeti),
        aktiflik_durumu: machineData.aktiflik_durumu === "Aktif" || machineData.aktiflik_durumu === true,
        garanti_firma_id: machineData.garanti_firma_id ? Number(machineData.garanti_firma_id) : undefined,
        lokasyon_id: machineData.lokasyon_id ? Number(machineData.lokasyon_id) : undefined,
      }),
    });
    return handleResponse(res);
  },

  // ═══════════════ 5. CHECKLIST SORULARI ═══════════════
  // GET /api/checklist/sablon/:sablon_id
  getChecklistQuestions: async (sablon_id) => {
    const res = await fetch(`${API_BASE}/checklist/sablon/${sablon_id}`, { headers: getHeaders() });
    const json = await handleResponse(res);
    return json.data?.kontrol_maddesi || [];
  },

  // ═══════════════ 6. CHECKLIST KAYDET ═══════════════
  // POST /api/checklist/form
  submitChecklist: async (formData) => {
    const res = await fetch(`${API_BASE}/checklist/form`, {
      method: "POST", headers: getHeaders(),
      body: JSON.stringify({
        makine_id: Number(formData.makine_id),
        sablon_id: Number(formData.sablon_id),
        genel_not: formData.genel_not || "",
        cevaplar: formData.cevaplar || formData.form_madde_cevap || [],
      }),
    });
    return handleResponse(res);
  },

  // ═══════════════ 7. BAKIM KAYDI EKLEME ═══════════════
  // POST /api/bakimlar
  addServiceRecord: async (recordData) => {
    const res = await fetch(`${API_BASE}/bakimlar`, {
      method: "POST", headers: getHeaders(),
      body: JSON.stringify({
        makine_id: Number(recordData.makine_id),
        bakim_tur_id: recordData.bakim_tur_id ? Number(recordData.bakim_tur_id) : undefined,
        aciklama: recordData.aciklama || "",
        durus_suresi: recordData.durus_suresi || null,
        servis_firma_id: Number(recordData.servis_firma_id),
        ariza_id: recordData.ariza_id ? Number(recordData.ariza_id) : undefined,
        bakim_maliyet: Number(recordData.bakim_maliyet),
        teknisyen_id: Number(recordData.teknisyen_id),
        degisen_Parcalar: recordData.degisen_Parcalar || [],
      }),
    });
    return handleResponse(res);
  },

  // ═══════════════ 8. BAKIM GEÇMİŞİ (TEK MAKİNE) ═══════════════
  // GET /api/bakimlar?makine_id=:id
  getServiceHistory: async (makine_id) => {
    const res = await fetch(`${API_BASE}/bakimlar?makine_id=${makine_id}`, { headers: getHeaders() });
    const json = await handleResponse(res);
    return (json.data || []).map((b) => ({
      ...b,
      bakim_maliyet: Number(b.bakim_maliyet || 0),
      servis_firmasi: b.servis_firma?.firma_adi || `Firma #${b.servis_firma_id}`,
    }));
  },

  // ═══════════════ 9. TÜM BAKIM GEÇMİŞİ (DASHBOARD) ═══════════════
  getAllServiceHistory: async () => {
    try {
      const makineler = await api.getMachines();
      const tumBakimlar = [];
      for (const m of makineler) {
        try {
          const bakimlar = await api.getServiceHistory(m.makine_id);
          bakimlar.forEach((b) => {
            tumBakimlar.push({ ...b, makine_ad: m.makine_adi || m.makine_ad });
          });
        } catch { /* Tek bir makinenin bakımı yoksa devam et */ }
      }
      return tumBakimlar;
    } catch { return []; }
  },

  // ═══════════════ 10. PERSONEL EKLE ═══════════════
  // POST /api/kullanicilar
  addUser: async (userData) => {
    const rolIdToStr = { 1: "YONETICI", 2: "TEKNISYEN", 3: "OPERATOR" };
    const res = await fetch(`${API_BASE}/kullanicilar`, {
      method: "POST", headers: getHeaders(),
      body: JSON.stringify({
        ad: userData.ad, soyad: userData.soyad,
        rol: rolIdToStr[userData.rol_id] || "OPERATOR",
        sifre: userData.sifre,
        telefon: userData.telefon,
        eposta: userData.eposta || null,
        firma_id: Number(userData.firma_id),
      }),
    });
    return handleResponse(res);
  },

  // ═══════════════ 11. TÜM KULLANICILARI GETİR ═══════════════
  // GET /api/kullanicilar
  getUsers: async () => {
    const res = await fetch(`${API_BASE}/kullanicilar`, { headers: getHeaders() });
    const json = await handleResponse(res);
    return json.kullanicilar || [];
  },

  // ═══════════════ 12. SİSTEM DROPDOWN VERİLERİ ═══════════════
  getSystemFirms: async () => {
    const res = await fetch(`${API_BASE}/sistem/firmalar`, { headers: getHeaders() });
    return (await handleResponse(res)).firmalar || [];
  },
  getSystemRoles: async () => {
    const res = await fetch(`${API_BASE}/sistem/roller`, { headers: getHeaders() });
    return (await handleResponse(res)).roller || [];
  },
  getSystemMachineTypes: async () => {
    const res = await fetch(`${API_BASE}/sistem/makine-turleri`, { headers: getHeaders() });
    return (await handleResponse(res)).makineTurleri || [];
  },

  // ═══════════════ 13. TEDARİKÇİLER ═══════════════
  // GET /api/tedarikciler
  getSuppliers: async () => {
    const res = await fetch(`${API_BASE}/tedarikciler`, { headers: getHeaders() });
    const json = await handleResponse(res);
    return json.data || [];
  },
  // POST /api/tedarikciler
  addSupplier: async (supplierData) => {
    const res = await fetch(`${API_BASE}/tedarikciler`, {
      method: "POST", headers: getHeaders(),
      body: JSON.stringify({
        firma_adi: supplierData.firma_adi || supplierData.ad,
        aktiflik: supplierData.aktiflik !== undefined ? supplierData.aktiflik : true,
        yetkili_kisi: supplierData.yetkili_kisi || null,
        vergi_no: supplierData.vergi_no || null,
        telefon: supplierData.telefon || null,
        email: supplierData.email || null,
        adres: supplierData.adres || null,
        il: supplierData.il || null,
        ilce: supplierData.ilce || null,
      }),
    });
    return handleResponse(res);
  },

  // ═══════════════ 14. SERVİS FİRMALARI ═══════════════
  // GET /api/servis-firmalari
  getServiceFirms: async () => {
    const res = await fetch(`${API_BASE}/servis-firmalari`, { headers: getHeaders() });
    const json = await handleResponse(res);
    return json.data || [];
  },
  // POST /api/servis-firmalari
  addServiceFirm: async (firmData) => {
    const res = await fetch(`${API_BASE}/servis-firmalari`, {
      method: "POST", headers: getHeaders(),
      body: JSON.stringify({
        firma_adi: firmData.firma_adi || firmData.ad,
        telefon: firmData.telefon || null,
        email: firmData.email || null,
        adres: firmData.adres || null,
        il: firmData.il || null,
        ilce: firmData.ilce || null,
        uzmanlik_alani: firmData.uzmanlik_alani || null,
      }),
    });
    return handleResponse(res);
  },

  // ═══════════════ 15. TÜM FİRMALAR (BİRLEŞİK) ═══════════════
  getFirms: async () => {
    try {
      const [servisFirmalari, tedarikciler] = await Promise.all([
        api.getServiceFirms(),
        api.getSuppliers(),
      ]);
      const mapped = [];
      for (const sf of servisFirmalari) {
        mapped.push({
          id: sf.servis_firma_id, ad: sf.firma_adi, tip: "Servis",
          telefon: sf.iletisim?.telefon || null,
          email: sf.iletisim?.email || null,
          adres: sf.iletisim?.acik_adres || null,
          uzmanlik_alani: sf.servis_firma_uzmanlik?.uzmanlik_adi || null,
          sorumlu_ad: sf.servis_sorumlusu?.[0]?.ad || null,
          sorumlu_soyad: sf.servis_sorumlusu?.[0]?.soyad || null,
          aktiflik: sf.aktiflik,
        });
      }
      for (const t of tedarikciler) {
        mapped.push({
          id: t.tedarikci_id, ad: t.firma_adi, tip: "Tedarikçi",
          telefon: t.iletisim?.telefon || null,
          email: t.iletisim?.email || null,
          adres: t.iletisim?.acik_adres || null,
          aktiflik: t.aktiflik,
          guvenilirlik_skoru: t.guvenilirlik_skoru ? Number(t.guvenilirlik_skoru) : null,
          vergi_no: t.vergi_no || null,
          yetkili_kisi: t.yetkili_kisi || null,
        });
      }
      return mapped;
    } catch { return []; }
  },

  // ═══════════════ 16. FİRMA EKLE (TİP BAZLI) ═══════════════
  addFirm: async (firmData) => {
    if (firmData.tip === "Tedarikçi" || firmData.tip === "tedarikci") {
      return api.addSupplier(firmData);
    } else {
      return api.addServiceFirm(firmData);
    }
  },

  // ═══════════════ 17. SERVİS PUANlama ═══════════════
  // POST /api/servis-puan
  rateFirm: async (firmaId, puanData) => {
    const puan = typeof puanData === "object" ? puanData.puan : puanData;
    const yorum = typeof puanData === "object" ? puanData.yorum : undefined;
    const res = await fetch(`${API_BASE}/servis-puan`, {
      method: "POST", headers: getHeaders(),
      body: JSON.stringify({
        servis_firma_id: Number(firmaId),
        puan: Number(puan),
        yorum: yorum || null,
      }),
    });
    return handleResponse(res);
  },

  // ═══════════════ 18. TEDARİKÇİ PUANlama ═══════════════
  // POST /api/tedarikci-puan
  rateSupplier: async (tedarikciId, puanData) => {
    const puan = typeof puanData === "object" ? puanData.puan : puanData;
    const yorum = typeof puanData === "object" ? puanData.yorum : undefined;
    const res = await fetch(`${API_BASE}/tedarikci-puan`, {
      method: "POST", headers: getHeaders(),
      body: JSON.stringify({
        tedarikci_id: Number(tedarikciId),
        puan: Number(puan),
        yorum: yorum || null,
      }),
    });
    return handleResponse(res);
  },

  // ═══════════════ 19. BAKIM KAYDI PUANlama ═══════════════
  rateServiceRecord: async (servis_firma_id, puan, yorum) => {
    const res = await fetch(`${API_BASE}/servis-puan`, {
      method: "POST", headers: getHeaders(),
      body: JSON.stringify({
        servis_firma_id: Number(servis_firma_id),
        puan: Number(puan),
        yorum: yorum || null,
      }),
    });
    return handleResponse(res);
  },

  // ═══════════════ 20. TEKNİSYEN GÖREVLERİ ═══════════════
  // GET /api/gorevler
  getTechTasks: async () => {
    const res = await fetch(`${API_BASE}/gorevler`, { headers: getHeaders() });
    const json = await handleResponse(res);
    return json.data || [];
  },

  // ═══════════════ 21. PUANLANACAK FİRMALAR ═══════════════
  getFirmsToRate: async () => {
    try {
      const firmalar = await api.getFirms();
      return firmalar.map((f) => ({
        id: f.id, ad: f.ad, tip: f.tip, aktiflik: f.aktiflik,
      }));
    } catch { return []; }
  },

  // ═══════════════ 22. SERVİS GİRİŞ (PIN + TELEFON) ═══════════════
  // POST /api/auth/servis-giris
  checkServiceLogin: async (data) => {
    const res = await fetch(`${API_BASE}/auth/servis-giris`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        telefon: data.telefon,
        servis_pin: data.pin || data.servis_pin,
        ad: data.ad || data.ad_soyad?.split(" ")[0],
        soyad: data.soyad || data.ad_soyad?.split(" ").slice(1).join(" "),
        unvan: data.unvan || null,
        servis_firma_id: data.firma_id || data.servis_firma_id,
      }),
    });
    const json = await handleResponse(res);
    return {
      success: json.success,
      isNew: json.yeniKayit,
      user: {
        kullanici_id: json.data.sorumlu_id,
        ad: `${json.data.ad} ${json.data.soyad}`,
        rol_id: 2,
        firma_id: json.data.servis_firma?.servis_firma_id,
      },
      token: json.token,
      makine: json.data.makine,
    };
  },

  // ═══════════════ 23. MALİYET ANALİZİ ═══════════════
  // GET /api/makineler/:id/maliyet-analizi
  getMachineCostAnalysis: async (makine_id) => {
    const res = await fetch(`${API_BASE}/makineler/${makine_id}/maliyet-analizi`, { headers: getHeaders() });
    const json = await handleResponse(res);
    return json.data;
  },
};

