Sen "Endux Kestirimci Bakım (TPM)" projesinde çalışan Kıdemli bir Yazılım Mimarıısın. Node.js, Express.js, TypeScript ve Prisma ORM (PostgreSQL) kullanıyoruz. Frontend (React) ekibiyle entegrasyon aşamasındayız. Aşağıda listelediğim 8 farklı görevi/sorunu incelemeni ve her biri için bana çözüm mimarisi, güncellenmiş kodlar ve API test örnekleri sunmanı istiyorum.

Lütfen cevaplarını madde numaralarına göre sırayla ve modüler olarak ver:

[GÖREV 1: SERVİS MİSAFİR GİRİŞİ (AUTH) MANTIK HATASI]
- Sorun: Dışarıdan gelen servis elemanları sisteme `telefon`, `ad`, `soyad`, `firma` ve makineye özel `servis_pin` ile giriyorlar. Kayıt ekranları yok, ilk girişte tabloya ekleniyorlar. Ancak aylar sonra tekrar geldiklerinde aynı verilerle girerlerse veritabanında "Veri Tekrarı (Duplication)" oluyor. 
- İkinci Sorun: `oturumYonetici.ts` middleware'inde `!servisSorumlusu` ise giriş reddediliyor. Bu da misafir mantığıyla çelişiyor.
- İstenen Çözüm: Misafir servis girişinde Prisma ile "FindOrCreate (Upsert)" mantığı kur. Kişi varsa ID'sini al, yoksa yeni kayıt oluştur. Middleware'i bu esnekliğe göre düzelt.

[GÖREV 2: FRONTEND 'api.js' DOSYASININ GÜNCELLENMESİ]
Frontend'in tamamını mock'tan gerçek HTTP isteklerine çeviren güncel `api.js`:

### `web-client/src/services/api.js` (TAM DEĞİŞTİR)

```js
// ============================================================
// ENDUX API Service — Gerçek Backend Bağlantısı (V2)
// Güncellenmiş veritabanı şemasına uyumlu
// ============================================================

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
  // Backend yanıtı: { success, token, data: { kullanici_id, ad, soyad, rol_id, firma_id, rol: "YONETICI" } }
  login: async (credentials) => {
    const res = await fetch(`${API_BASE}/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(credentials),
    });
    const json = await handleResponse(res);
    // Backend "rol" string döner ("YONETICI"). Frontend rol_id (number) bekliyor.
    // Mapping yapıyoruz:
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
  // Backend: { success, data: [{ makine_id, makine_ad, aktiflik_durumu (boolean), ... }] }
  getMachines: async () => {
    const res = await fetch(`${API_BASE}/makineler`, { headers: getHeaders() });
    const json = await handleResponse(res);
    return (json.data || []).map((m) => ({
      ...m,
      // Boolean → String mapping (frontend string bekliyor)
      aktiflik_durumu: m.aktiflik_durumu === true ? "Aktif" : "Pasif",
      // Prisma Decimal → JS Number
      mevcut_risk_skoru: Number(m.mevcut_risk_skoru || 0),
      satin_alma_maliyeti: Number(m.satin_alma_maliyeti || 0),
      top_calisma_saati: Number(m.top_calisma_saati || 0),
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
      top_calisma_saati: Number(m.top_calisma_saati || 0),
      // firma relation'ını tedarikci olarak map'le (frontend uyumluluğu)
      tedarikci: m.firma ? { firma_id: m.firma.firma_id, firma_adi: m.firma.firma_adi } : null,
    };
  },

  // ═══════════════ 4. MAKİNE EKLE ═══════════════
  // POST /api/makineler
  addMachine: async (machineData) => {
    const res = await fetch(`${API_BASE}/makineler`, {
      method: "POST", headers: getHeaders(),
      body: JSON.stringify({
        makine_ad: machineData.makine_ad,
        firma_id: Number(machineData.firma_id),
        m_tur_id: Number(machineData.m_tur_id),
        seri_no: String(machineData.seri_no),
        satin_alma_tarihi: machineData.satin_alma_tarihi,
        satin_alma_maliyeti: Number(machineData.satin_alma_maliyeti),
        aktiflik_durumu: machineData.aktiflik_durumu === "Aktif" || machineData.aktiflik_durumu === true,
        garanti_firma_id: Number(machineData.garanti_firma_id),
        lokasyon_id: Number(machineData.lokasyon_id),
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
  // Backend: { makine_id, sablon_id, genel_not, cevaplar: [{madde_id, girilen_deger, durum}] }
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
        bakim_turu: String(recordData.bakim_turu || "Planlı Bakım"),
        aciklama: recordData.aciklama || "",
        durus_suresi: recordData.durus_suresi || null,
        servis_firma_id: Number(recordData.servis_firma_id),
        ariza_id: Number(recordData.ariza_id || 1),
        bakim_maliyet: Number(recordData.bakim_maliyet),
        teknisyen_id: Number(recordData.teknisyen_id),
        degisen_Parcalar: recordData.degisen_Parcalar || [],
      }),
    });
    return handleResponse(res);
  },

  // ═══════════════ 8. BAKIM GEÇMİŞİ ═══════════════
  // GET /api/bakimlar/:makine_id
  getServiceHistory: async (makine_id) => {
    const res = await fetch(`${API_BASE}/bakimlar/${makine_id}`, { headers: getHeaders() });
    const json = await handleResponse(res);
    return (json.data || []).map((b) => ({
      ...b,
      bakim_maliyet: Number(b.bakim_maliyet || 0),
      servis_firmasi: b.servis_firma?.firma_adi || `Firma #${b.servis_firma_id}`,
    }));
  },

  // ═══════════════ 9. PERSONEL EKLE ═══════════════
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

  // ═══════════════ 10. SİSTEM DROPDOWN VERİLERİ ═══════════════
  getSystemFirms: async () => {
    const res = await fetch(`${API_BASE}/sistem/firmalar`);
    return (await handleResponse(res)).firmalar || [];
  },
  getSystemRoles: async () => {
    const res = await fetch(`${API_BASE}/sistem/roller`);
    return (await handleResponse(res)).roller || [];
  },
  getSystemMachineTypes: async () => {
    const res = await fetch(`${API_BASE}/sistem/makine-turleri`);
    return (await handleResponse(res)).makineTurleri || [];
  },

  // ═══════════════ 11. HENÜZ BACKEND'DE OLMAYAN ENDPOINT'LER ═══════════════
  // Bu fonksiyonlar backend hazır olunca gerçek isteklerle değiştirilecek

  getUsers: async () => {
    console.warn("getUsers: Backend endpoint yok"); return [];
  },
  getAllServiceHistory: async () => {
    console.warn("getAllServiceHistory: Backend endpoint yok"); return [];
  },
  getFirms: async () => {
    // Geçici: sistem firmalarını döndür
    try {
      const firms = await api.getSystemFirms();
      return firms.map(f => ({ id: f.firma_id, ad: f.firma_adi, tip: "Firma" }));
    } catch { return []; }
  },
  addFirm: async (d) => { console.warn("addFirm: Endpoint yok", d); return { ...d, id: Date.now() }; },
  rateFirm: async () => ({ success: true }),
  rateServiceRecord: async () => ({ success: true }),
  getTechTasks: async () => { console.warn("getTechTasks: Endpoint yok"); return []; },
  getFirmsToRate: async () => [],
  checkServiceLogin: async () => { throw new Error("Servis giriş endpoint'i hazır değil."); },
};
```

- Sorun: Frontend ekibinin kullandığı `api.js` dosyasının sonunda `// HENÜZ BACKEND'DE OLMAYAN ENDPOINT'LER` adında geçici (mock) fonksiyonlar var (`getUsers`, `getAllServiceHistory`, `addFirm`, `rateFirm` vb.).
- İstenen Çözüm: Sana daha önce verdiğim P1, P2, P3 öncelikli yeni yazdığımız rotaları (Tedarikçiler, Servis Firmaları, Puanlama vb.) kullanarak bu `api.js` dosyasındaki sahte fonksiyonları GERÇEK fetch istekleriyle değiştir ve tüm dosyayı bana eksiksiz yeniden yaz.

[GÖREV 3 & 4: SİSTEM KONTROLÜ VE POSTMAN TESTLERİ]
- İstenen Çözüm: Yeni yazdığımız bu CRUD servislerinde (Tedarikçi ekleme, Puan verme vb.) açık bir mantık hatası var mı gözden geçir. Ardından, Frontend'in test edebilmesi için bu yeni API'lerin hepsine ait örnek JSON Body'lerini (Postman formatında) yaz.

[GÖREV 5: QR KOD GİRİŞİ TUTARSIZLIK KONTROLÜ]
- Sorun: Operatör ve Teknisyenlerin QR kod (UUID) okutarak login olma ve ilgili makine detayına yönlendirilme kurgusunda içime sinmeyen şeyler var. (Örn: Token süresi dolarsa ne olur? Yanlış QR okutursa ne olur?)
- İstenen Çözüm: QR kod akışımızı "Sıfır Güven (Zero Trust)" mantığıyla analiz et ve olası 3 güvenlik/yönlendirme açığını tespit edip çözüm öner.

[GÖREV 6: KAT PLANI VE DİNAMİK MALİYET GÖRSELLEŞTİRME (YENİ ÖZELLİK)]
- Senaryo: Fabrikada 2 kat ve toplam 100 makine var. Yönetici lokasyon ekranına (Harita/Grid) baktığında makinelerin rengi maliyet oranına göre dinamik değişecek:
  * (Toplam Onarım Maliyeti / Satın Alma Maliyeti) > %10 ise KIRMIZI
  * > %5 ise SARI
  * < %2 ise YEŞİL
- Eylem: Tıklanan makinenin tüm detayları ekranda açılacak.
- İstenen Çözüm: Bu hesaplamayı Frontend'e yüklememek için Backend'de nasıl bir DTO (Data Transfer Object) veya servis yazmalıyız? 100 makinenin verisini sistemi yormadan çekecek Prisma sorgusunu ve harita render mantığını tasarla.

[GÖREV 7: DURUŞ SÜRESİ VE STOK MANTIĞI KONTROLÜ]
- İstenen Çözüm: Bakım kayıtlarında teknisyenin girdiği `durus_suresi` ile değiştirilen parçaların (`parca_degisim`) stoktan düşme mantığı arasında bir kopukluk var mı kontrol et. Eğer stok tablomuz yoksa, bu ilişkiyi en basit haliyle nasıl kurmalıyız?

[GÖREV 8: FİRMA İSİMLERİNDE BÜYÜK HARF STANDARDI]
- Sorun: Veri bütünlüğü için `firma_adi` gibi alanların veritabanına her zaman BÜYÜK HARFLE kaydedilmesi gerekiyor.
- İstenen Çözüm: Bunu Prisma Middleware / Extension seviyesinde veya Controller'da en temiz (Clean Code) şekilde nasıl uygularız? Kodu göster.