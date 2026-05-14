const API_BASE = "/api"; // Vite proxy ile backend'e yönlendirilir

const getHeaders = () => ({
  "Content-Type": "application/json",
  Authorization: `Bearer ${localStorage.getItem("auth_token")}`,
});

const handleResponse = async (res) => {
  const json = await res.json();
  if (!res.ok) throw new Error(json.hata_detayi || json.message || json.hata || json.error || "İstek başarısız");
  return json;
};

const hasActiveMaintenance = (machine) => {
  const activeMaintenanceStatuses = ["Teknik Serviste", "Bakımda", "ONAYLANDI"];
  return (machine.bakim_kaydi || []).some((record) =>
    activeMaintenanceStatuses.includes(record?.durum)
  );
};

const getMachineDisplayStatus = (machine) => {
  if (hasActiveMaintenance(machine)) return "Bakımda";
  if (typeof machine.aktiflik_durumu === "boolean") {
    return machine.aktiflik_durumu ? "Aktif" : "Pasif";
  }
  return machine.aktiflik_durumu || "Bilinmiyor";
};

const parseLocaleNumber = (value) => {
  if (typeof value === "number") return value;
  return Number(String(value ?? "").trim().replace(/\./g, "").replace(",", "."));
};

const normalizeRiskScore = (value) => {
  const score = Number(value || 0);
  return Number((score <= 1 ? score * 100 : score).toFixed(2));
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
    return (json.data || []).map((m) => {
      const sonRisk = m.risk_skoru?.[0] || null;
      const riskScore = normalizeRiskScore(sonRisk?.risk_skoru);
      return {
        ...m,
        id: m.makine_id,
        ad: m.makine_adi,
        aktiflik_durumu: getMachineDisplayStatus(m),
        mevcut_risk_skoru: riskScore,
        risk_seviyesi: sonRisk?.risk_seviyesi || (riskScore >= 80 ? "YUKSEK" : riskScore >= 50 ? "ORTA" : "DUSUK"),
        kategori: riskScore >= 80 ? "Yüksek Riskli" : riskScore >= 50 ? "Bakımı Yaklaşan" : "Normal",
        satin_alma_maliyeti: Number(m.satin_alma_maliyeti || 0),
        top_calisma_saati: Number(m.toplam_calisma_saati || 0),
        lo_id: m.lokasyon?.[0]?.lokasyon_adi || "-",
        m_tur_id: m.makine_turu?.makine_tur_adi || "-",
        satin_alma_tarihi: m.satin_alma_tarihi ? String(m.satin_alma_tarihi).split('T')[0] : "-",
        pin: m.servis_pin,
        tedarikci: m.garanti_firma ? {
          firma_adi: m.garanti_firma.firma_adi,
          telefon: m.garanti_firma.iletisim?.telefon || "-",
          email: m.garanti_firma.iletisim?.mail || "-",
          adres: m.garanti_firma.iletisim?.acik_adres || "Adres bilgisi yok"
        } : null,
      };
    });
  },
  // PATCH /api/makineler/:id/durum
  updateMachineStatus: async (makine_id, yeniDurum) => {
    const res = await fetch(`${API_BASE}/makineler/${makine_id}/durum`, {
      method: "PATCH",
      headers: getHeaders(),
      body: JSON.stringify({ aktiflik_durumu: yeniDurum }),
    });
    return handleResponse(res);
  },

  // ═══════════════ 3. MAKİNE DETAY ═══════════════
  // GET /api/makineler/:id
  getMachineDetails: async (makine_id) => {
    const res = await fetch(`${API_BASE}/makineler/${makine_id}`, { headers: getHeaders() });
    const json = await handleResponse(res);
    const m = json.data;
    const sonRisk = m.risk_skoru?.[0] || null;
    const riskScore = normalizeRiskScore(m.mevcut_risk_skoru ?? sonRisk?.risk_skoru);
    return {
      ...m,
      aktiflik_durumu: getMachineDisplayStatus(m),
      mevcut_risk_skoru: riskScore,
      risk_seviyesi: m.risk_seviyesi || sonRisk?.risk_seviyesi || (riskScore >= 80 ? "YUKSEK" : riskScore >= 50 ? "ORTA" : "DUSUK"),
      kategori: riskScore >= 80 ? "Yüksek Riskli" : riskScore >= 50 ? "Bakımı Yaklaşan" : "Normal",
      satin_alma_maliyeti: Number(m.satin_alma_maliyeti || 0),
      top_calisma_saati: Number(m.toplam_calisma_saati || 0),
      lo_id: m.lokasyon?.[0]?.lokasyon_adi || "-",
      m_tur_id: m.makine_turu?.makine_tur_adi || "-",
      satin_alma_tarihi: m.satin_alma_tarihi ? String(m.satin_alma_tarihi).split('T')[0] : "-",
      pin: m.servis_pin,
      tedarikci: m.garanti_firma ? {
        firma_adi: m.garanti_firma.firma_adi,
        telefon: m.garanti_firma.iletisim?.telefon || "-",
        email: m.garanti_firma.iletisim?.mail || "-",
        adres: m.garanti_firma.iletisim?.acik_adres || "Adres bilgisi yok"
      } : null,
    };
  },

  // ═══════════════ 3.5. MAKİNE QR GETİR ═══════════════
  // GET /api/makineler/qr/:qr_uuid
  getMachineByQR: async (qr_uuid) => {
    const res = await fetch(`${API_BASE}/makineler/qr/${qr_uuid}`, { headers: getHeaders() });
    const json = await handleResponse(res);
    return json;
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
        garanti_suresi: machineData.garanti_suresi ? Number(machineData.garanti_suresi) : undefined,
        tedarikci: machineData.tedarikci || null,
        lokasyon_id: machineData.lokasyon_id || undefined,
        // TPM: Yapılandırılmış teknik özellik alanları
        kapasite: machineData.kapasite || undefined,
        guc_tuketimi: machineData.guc_tuketimi || undefined,
        max_rpm: machineData.max_rpm ? Number(machineData.max_rpm) : undefined,
        max_basinc_ton: machineData.max_basinc_ton ? Number(machineData.max_basinc_ton) : undefined,
        enjeksiyon_hacmi: machineData.enjeksiyon_hacmi || undefined,
        tabla_boyutu: machineData.tabla_boyutu || undefined,
        guncel_calisma_saati: machineData.guncel_calisma_saati ? Number(machineData.guncel_calisma_saati) : 0,
      }),
    });
    return handleResponse(res);
  },
  updateMachineStatus: async (makine_id, status) => {
    const res = await fetch(`${API_BASE}/makineler/${makine_id}/durum`, {
      method: "PATCH",
      headers: getHeaders(),
      body: JSON.stringify({ aktiflik_durumu: status }),
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

  // ═══════════════ 6. CHECKLIST KAYDET VE GEÇMİŞ ═══════════════
  getChecklistHistory: async (makine_id) => {
    try {
      const res = await fetch(`${API_BASE}/makineler/${makine_id}`, { headers: getHeaders() });
      const json = await handleResponse(res);
      const m = json.data || {};

      if (!m.gunluk_kontrol_formu || !Array.isArray(m.gunluk_kontrol_formu)) return [];

      return m.gunluk_kontrol_formu.map(form => {
        // Tarih, Not ve Soru/Cevap verileri dizide veya nesne içinde sarmalanmış olabilir.
        const extractVal = (v) => {
          if (Array.isArray(v)) v = v[0];
          if (typeof v === 'object' && v !== null) return v.val || v.text || v.value || JSON.stringify(v);
          return v;
        };

        const aiRisk = normalizeRiskScore(extractVal(form.ai_on_risk_durumu ?? form.AI_on_risk_durumu));
        const riskSebebi = aiRisk >= 80
          ? `Yüksek AI riski (${aiRisk.toFixed(2)})`
          : aiRisk >= 50
            ? `Bakım riski izlenmeli (${aiRisk.toFixed(2)})`
            : "Her şey normal.";

        return {
          tarih: extractVal(form.kontrol_tarihi) || form.istek_tarihi_saati,
          tespit_eden: aiRisk > 0 ? "AI" : "Operatör",
          risk_sebebi: aiRisk > 0 ? riskSebebi : (extractVal(form.genel_not) || riskSebebi),
          cevaplar: (form.form_madde_cevap || []).map(c => ({
            soru: extractVal(c.kontrol_maddesi?.madde_adi) || "Bilinmeyen Soru",
            cevap: extractVal(c.girilen_deger) || "-"
          }))
        };
      });
    } catch {
      return [];
    }
  },

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
        teknisyen_id: recordData.teknisyen_id ? Number(recordData.teknisyen_id) : null,
        degisen_Parcalar: recordData.degisen_Parcalar || [],
        puan: recordData.puan ? Number(recordData.puan) : null,
      }),
    });
    return handleResponse(res);
  },

  // ═══════════════ 8. BAKIM GEÇMİŞİ (TEK MAKİNE) ═══════════════
  // GET /api/bakimlar/:makine_id
  getServiceHistory: async (makine_id) => {
    const res = await fetch(`${API_BASE}/bakimlar/${makine_id}`, { headers: getHeaders() });
    const json = await handleResponse(res);

    const extractVal = (v) => {
      if (Array.isArray(v)) v = v[0];
      if (typeof v === 'object' && v !== null) return v.val || v.text || v.value || v.ad || v.bakim_tur_adi || JSON.stringify(v);
      return v;
    };

    return (json.data || []).map((b) => {
      return {
        ...b,
        bakim_maliyet: Number(extractVal(b.bakim_maliyet) || 0),
        bakim_tarihi: extractVal(b.bakim_tarihi),
        bakim_turu: extractVal(b.bakim_turu),
        servis_firmasi: b.servis_firma?.firma_adi || `Firma #${b.servis_firma_id}`,
      };
    });
  },

  // ═══════════════ 9. TÜM BAKIM GEÇMİŞİ (DASHBOARD) ═══════════════
  getAllServiceHistory: async () => {
    try {
      // Artık 104 istek yok! Sadece 1 istek var.
      const res = await fetch(`${API_BASE}/bakimlar/tum-bakimlar`, { headers: getHeaders() });
      const json = await handleResponse(res);
      return json.data || [];
    } catch {
      return [];
    }
  },

  // ═══════════════ 10. PERSONEL EKLE ═══════════════
  addUser: async (userData) => {
    const res = await fetch(`${API_BASE}/kullanicilar`, {
      method: "POST", headers: getHeaders(),
      body: JSON.stringify({
        ad: userData.ad, soyad: userData.soyad,
        rol: userData.rol, // Doğrudan string alınıyor (örn: "YONETICI")
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

  deleteUser: async (kullanici_id) => {
    const res = await fetch(`${API_BASE}/kullanicilar/${kullanici_id}`, {
      method: "DELETE",
      headers: getHeaders(),
    });
    return handleResponse(res);
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
        sorumlu_ad: firmData.sorumlu_ad || null,
        sorumlu_telefon: firmData.sorumlu_telefon || firmData.telefon || null,
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
          uzmanlik_alani: Array.isArray(sf.servis_firma_uzmanlik)
            ? sf.servis_firma_uzmanlik?.[0]?.uzmanlik_adi || null
            : sf.servis_firma_uzmanlik?.uzmanlik_adi || null,
          sorumlu_ad: sf.servis_sorumlusu?.[0]?.ad || null,
          sorumlu_soyad: sf.servis_sorumlusu?.[0]?.soyad || null,
          aktiflik: sf.aktiflik,
          ortalama_puan: sf.ortalama_puan || 0,
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
          ortalama_puan: t.ortalama_puan,
          yorum: t.yorum
        });
      }
      return mapped;
    } catch { return []; }
  },

  deleteSupplier: async (id) => {
    const res = await fetch(`${API_BASE}/tedarikciler/${id}`, {
      method: "DELETE",
      headers: getHeaders(),
    });
    return handleResponse(res);
  },

  deleteServiceFirm: async (id) => {
    const res = await fetch(`${API_BASE}/servis-firmalari/${id}`, {
      method: "DELETE",
      headers: getHeaders(),
    });
    return handleResponse(res);
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

  // ═══════════════ 20. BAKIM İŞLEMİ PUANlama (Yeni) ═══════════════
  rateMaintenance: async (bakimId, puan) => {
    const res = await fetch(`${API_BASE}/bakimlar/${bakimId}/puan`, {
      method: "PATCH", headers: getHeaders(),
      body: JSON.stringify({ puan: Number(puan) }),
    });
    return handleResponse(res);
  },

  // ═══════════════ 21. BAKIM İŞLEMİNİ ONAYLA (LİSTEDEN KALDIR) ═══════════════
  approveMaintenance: async (bakimId) => {
    const res = await fetch(`${API_BASE}/bakimlar/${bakimId}/onayla`, {
      method: "PATCH", headers: getHeaders(),
    });
    return handleResponse(res);
  },

  // ═══════════════ 22. TEKNİSYEN GÖREVLERİ ═══════════════
  // GET /api/bakimlar/onay-bekleyenler
  getTechTasks: async () => {
    const res = await fetch(`${API_BASE}/bakimlar/onay-bekleyenler`, { headers: getHeaders() });
    const json = await handleResponse(res);
    return json.data || [];
  },
  updateTaskStatus: async (taskId, status) => {
    const res = await fetch(`${API_BASE}/gorevler/${taskId}/durum`, {
      method: "PATCH", headers: getHeaders(),
      body: JSON.stringify({ durum: status }),
    });
    return handleResponse(res);
  },
  sendTasksToTechnicalService: async (bakimIdler) => {
    const res = await fetch(`${API_BASE}/bakimlar/onayla`, {
      method: "PUT",
      headers: getHeaders(),
      body: JSON.stringify({ bakim_idler: bakimIdler.map(Number) }),
    });
    return handleResponse(res);
  },
  createEmergencyMaintenance: async ({ makine_id, aciklama }) => {
    const res = await fetch(`${API_BASE}/bakimlar/acil-bildir`, {
      method: "POST",
      headers: getHeaders(),
      body: JSON.stringify({
        makine_id: Number(makine_id),
        aciklama,
      }),
    });
    return handleResponse(res);
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
        qr_uuid: data.qr_uuid,
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

  // ═══════════════ 24. DİNAMİK CHECKLIST (Makine ID ile) ═══════════════
  // Makine bilgisini ve o türe ait şablon sorularını birlikte getirir
  getChecklistByMachine: async (makine_id) => {
    // 1. Makine bilgisini al (tür bilgisi dahil)
    const makineRes = await fetch(`${API_BASE}/makineler/${makine_id}`, { headers: getHeaders() });
    const makineJson = await handleResponse(makineRes);
    const makine = makineJson.data;

    if (!makine) throw new Error("Makine bulunamadı.");

    // 2. Makine türü bilgisi
    const makineTuru = makine.makine_turu?.makine_tur_adi || "Bilinmiyor";
    const makineTurId = makine.makine_tur_id;

    // 3. Makine türüne bağlı şablon sorularını getir - tüm şablonları deneyerek doğru olanı bul
    let sorular = [];
    let sablonId = null;
    let sablonAdi = null;

    // Şablonları sırayla dene (1, 2, 3...)
    for (let tryId = 1; tryId <= 10; tryId++) {
      try {
        const sablonRes = await fetch(`${API_BASE}/checklist/sablon/${tryId}`, { headers: getHeaders() });
        const sablonJson = await handleResponse(sablonRes);
        const sablon = sablonJson.data;

        if (sablon && sablon.makine_tur_id === makineTurId) {
          sablonId = sablon.sablon_id;
          sablonAdi = sablon.sablon_adi;
          sorular = sablon.kontrol_maddesi || [];
          break;
        }
      } catch {
        // Bu şablon yok, devam et
      }
    }

    return {
      makine_id: makine.makine_id,
      makine_adi: makine.makine_adi,
      makine_turu: makineTuru,
      makine_tur_id: makineTurId,
      sablon_id: sablonId,
      sablon_adi: sablonAdi,
      sorular: sorular
    };
  },

  // ═══════════════ 25. SATIN ALMA ═══════════════
  // POST /api/satin-alma
  addPurchase: async (purchaseData) => {
    const res = await fetch(`${API_BASE}/satin-alma`, {
      method: "POST", headers: getHeaders(),
      body: JSON.stringify({
        tedarikci_id: Number(purchaseData.tedarikci_id),
        parca_adi: purchaseData.parca_adi,
        adet: parseLocaleNumber(purchaseData.adet),
        birim_fiyat: parseLocaleNumber(purchaseData.birim_fiyat),
        tedarik_suresi: purchaseData.tedarik_suresi ? parseLocaleNumber(purchaseData.tedarik_suresi) : null,
        tarih: purchaseData.tarih || new Date().toISOString(),
        puan: parseLocaleNumber(purchaseData.puan),
        makine_tur_id: purchaseData.makine_tur_id ? Number(purchaseData.makine_tur_id) : null,
        tahmini_omur: purchaseData.tahmini_omur ? parseLocaleNumber(purchaseData.tahmini_omur) : null,
      }),
    });
    return handleResponse(res);
  },

  // GET /api/satin-alma
  getPurchases: async () => {
    const res = await fetch(`${API_BASE}/satin-alma`, { headers: getHeaders() });
    const json = await handleResponse(res);
    return json.data || [];
  },

  getPartCategories: async () => {
    const res = await fetch(`${API_BASE}/satin-alma/kategoriler`, { headers: getHeaders() });
    const json = await handleResponse(res);
    return json.data || [];
  },

  // ═══════════════ 26. STOK ═══════════════
  // GET /api/satin-alma/stok
  getInventory: async () => {
    const res = await fetch(`${API_BASE}/satin-alma/stok`, { headers: getHeaders() });
    const json = await handleResponse(res);
    return json.data || [];
  },

  deleteInventoryPart: async (partId) => {
    const res = await fetch(`${API_BASE}/satin-alma/stok/${partId}`, {
      method: "DELETE",
      headers: getHeaders(),
    });
    return handleResponse(res);
  },

  // ═══════════════ 27. TEDARİKÇİ SATIN ALMA PUAN ORTALAMASI ═══════════════
  // GET /api/satin-alma/:id/ortalama-puan
  getSupplierAvgScore: async (tedarikciId) => {
    const res = await fetch(`${API_BASE}/satin-alma/${tedarikciId}/ortalama-puan`, { headers: getHeaders() });
    const json = await handleResponse(res);
    return json.data;
  },

  // PATCH /api/satin-alma/:id/puan
  ratePurchase: async (satinAlmaId, puan) => {
    const res = await fetch(`${API_BASE}/satin-alma/${satinAlmaId}/puan`, {
      method: "PATCH", headers: getHeaders(),
      body: JSON.stringify({ puan: Number(puan) }),
    });
    return handleResponse(res);
  },

  // ═══════════════ 28. QR KOD YAZDIR ═══════════════
  // GET /api/makineler/:id/qr-yazdir
  getMachineQrPrintData: async (makine_id) => {
    const res = await fetch(`${API_BASE}/makineler/${makine_id}/qr-yazdir`, {
      headers: getHeaders()
    });
    const json = await handleResponse(res);
    return json.data;
  },

  // ═══════════════ 29. OEE (VERİMLİLİK) VERİLERİ ═══════════════
  // GET /api/oee/toplu
  // Tüm fabrikanın ortalama OEE skorunu ve haftalık OEE trendini döner
  getFactoryOee: async (baslangic, bitis) => {
    const query = `?baslangic=${baslangic}&bitis=${bitis}`;
    const res = await fetch(`${API_BASE}/oee/toplu${query}`, { headers: getHeaders() });
    const json = await handleResponse(res);
    return json.data;
  },

  // GET /api/oee/:id
  // Tekil bir makinenin OEE detaylarını ve duruş pasta grafiği verilerini döner
  getMachineOee: async (makine_id, baslangic, bitis) => {
    const query = `?baslangic=${baslangic}&bitis=${bitis}`;
    const res = await fetch(`${API_BASE}/oee/${makine_id}${query}`, { headers: getHeaders() });
    const json = await handleResponse(res);
    return json.data;
  },


  getDashboardOzet: async () => {
    const res = await fetch(`${API_BASE}/dashboard/ozet`, {
      headers: getHeaders(),
    });
    const json = await handleResponse(res);
    return json.data;
  },

  // ═══════════════ 30. QR BAZLI BAKIM TAMAMLAMA ═══════════════
  // POST /api/bakimlar/qr-tamamla
  // Teknisyen sahada QR okutup formu doldurduktan sonra çağrılır
  qrBakimTamamla: async (formData) => {
    const res = await fetch(`${API_BASE}/bakimlar/qr-tamamla`, {
      method: "POST",
      headers: getHeaders(),
      body: JSON.stringify({
        bakim_id: Number(formData.bakim_id),
        bakim_maliyet: formData.bakim_maliyet ? Number(formData.bakim_maliyet) : undefined,
        aciklama: formData.aciklama || undefined,
        durus_suresi: formData.durus_suresi ? Number(formData.durus_suresi) : undefined,
        degisen_parcalar: formData.degisen_parcalar || [],
      }),
    });
    return handleResponse(res);
  },

  // ═══════════════ 31. BEKLEYENİŞLERİ GETİR (ONAYLANDI durumunda) ═══════════════
  // GET /api/bakimlar/teknik-servis
  // Makineye ait ONAYLANDI durumundaki bekleyen bakım görevlerini getirir
  getBekleyenIsler: async () => {
    const res = await fetch(`${API_BASE}/bakimlar/teknik-servis`, {
      headers: getHeaders(),
    });
    const json = await handleResponse(res);
    return json.data || [];
  },


  // ═══════════════ 32. VARDİYA SAATLERİ (SİSTEM) ═══════════════
  // GET /api/sistem/vardiya-saatleri
  getVardiyaSaatleri: async () => {
    const res = await fetch(`${API_BASE}/sistem/vardiya-saatleri`, { headers: getHeaders() });
    const json = await handleResponse(res);
    return json.vardiyalar || [];
  },

  // POST /api/sistem/vardiya-saatleri
  updateVardiyaSaatleri: async (vardiyalar) => {
    const res = await fetch(`${API_BASE}/sistem/vardiya-saatleri`, {
      method: "POST",
      headers: getHeaders(),
      body: JSON.stringify({ vardiyalar }),
    });
    return handleResponse(res);
  },

  getMakineTuruDurusMaliyetleri: async () => {
    const res = await fetch(`${API_BASE}/sistem/makine-turu-durus-maliyetleri`, { headers: getHeaders() });
    const json = await handleResponse(res);
    return json.makineTurleri || [];
  },

  updateMakineTuruDurusMaliyetleri: async (makineTurleri) => {
    const res = await fetch(`${API_BASE}/sistem/makine-turu-durus-maliyetleri`, {
      method: "POST",
      headers: getHeaders(),
      body: JSON.stringify({ makineTurleri }),
    });
    return handleResponse(res);
  },

};
