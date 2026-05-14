import React, { useState, useEffect } from "react";
import { useParams } from "react-router-dom";
import { api } from "./services/api";
import FirmModal from "./components/FirmModal";

export default function Servis() {
  const { id } = useParams();

  const [arizaSecenekleri, setArizaSecenekleri] = useState([]);
  const [history, setHistory] = useState([]); // Makineye ait eski servis kayıtları
  const [firms, setFirms] = useState([]); // Sistemdeki tüm kayıtlı firmalar (Servis/Tedarikçi)
  const [bakimTurleri, setBakimTurleri] = useState([]); // Sistemdeki bakım türleri
  const [isModalOpen, setIsModalOpen] = useState(false); // Yeni firma ekleme modalı durumu
  const [modalType, setModalType] = useState("Servis"); // Eklenecek firmanın türü

  // --- QR BAKIM TAMAMLAMA STATE'LERİ ---
  const [bekleyenIs, setBekleyenIs] = useState(null); // Bu makinede ONAYLANDI durumunda bekleyen iş
  const [tamamlandiMi, setTamamlandiMi] = useState(false); // Başarılı tamamlama mesajı
  const [kaydetYukleniyor, setKaydetYukleniyor] = useState(false); // Kaydet butonu loading durumu

  const [stoklar, setStoklar] = useState([]);
  const [selectedPartId, setSelectedPartId] = useState("");


  // Bakım formu state'leri
  const [form, setForm] = useState({
    bakim_maliyet: "",
    durus_suresi: "",
    aciklama: "",
    ariza_sebebi: "",
    ariza_id: "",
    bakim_tur_id: "",
    servis_firma_id: "",
    degisen_parcalar: []
  });

  // Giriş yapmış kullanıcı bilgisini al
  const currentUser = JSON.parse(localStorage.getItem("user_payload") || "{}");

  // --- VERİ ÇEKME SÜRECİ ---
  useEffect(() => {
    const fetchData = async () => {
      try {
        // Makineye özel servis geçmişini ve genel firma listesini çek (Paralel istek)
        const [histData, firmData, stokData, makineData, bakimData] = await Promise.all([
          api.getServiceHistory(id),
          api.getFirms(),
          api.getInventory(),
          api.getMachineDetails(id),
          api.getSystemBakimTurleri()
        ]);
        setHistory(histData);
        setFirms(firmData);
        setStoklar(stokData);
        setBakimTurleri(bakimData);
        if (makineData && makineData.makine_tur_id) {
          try {
            const arizalar = await api.getSystemArizaTurleri(makineData.makine_tur_id);
            setArizaSecenekleri(arizalar);
          } catch (err) { console.error("Arızalar çekilemedi", err); }
        }

        // Bu makine için bekleyen (ONAYLANDI) iş var mı kontrol et
        try {
          const teknikServisIsler = await api.getBekleyenIsler();
          const bekleyen = teknikServisIsler.find(
            is => is.makine_id === Number(id) && is.durum === "ONAYLANDI"
          );
          if (bekleyen) {
            setBekleyenIs(bekleyen);
          }
        } catch (err) {
          console.log("Bekleyen iş kontrolü yapılamadı:", err);
        }
      } catch (err) {
        console.error("Veriler yüklenemedi", err);
      }
    };
    fetchData();
  }, [id]);

  const handleRecordPuanla = async (bakimId, puan) => {
    try {
      await api.rateMaintenance(bakimId, puan);
      setHistory(history.map(h => h.bakim_id === bakimId ? { ...h, servis_puan: { puan: puan } } : h));
      alert("Servis kaydı puanlaması başarıyla kaydedildi!");
    } catch (error) {
      alert("Puanlama sırasında hata oluştu!");
    }
  };

  const sortedHistory = [...history].sort((a, b) => new Date(b.bakim_tarihi || 0).getTime() - new Date(a.bakim_tarihi || 0).getTime());

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  // --- QR BAKIM TAMAMLAMA (YENİ ENDPOINT) ---
  const handleBakimiTamamla = async (e) => {
    if (e && e.preventDefault) {
      e.preventDefault();
    }

    if (!bekleyenIs) {
      alert("Tamamlanacak bir bakım kaydı bulunamadı!");
      return;
    }

    if (!form.bakim_maliyet) {
      alert("Lütfen maliyet alanını doldurun!");
      return;
    }

    setKaydetYukleniyor(true);

    try {
      const gonderilecekVeri = {
        bakim_id: Number(bekleyenIs.bakim_id),
        bakim_maliyet: Number(form.bakim_maliyet),
        aciklama: String(form.aciklama || form.ariza_sebebi || "").trim(),
        degisen_parcalar: form.degisen_parcalar,
        durus_suresi: form.durus_suresi ? Number(form.durus_suresi) : undefined,
        servis_firma_id: form.servis_firma_id ? Number(form.servis_firma_id) : undefined,
        bakim_tur_id: form.bakim_tur_id ? Number(form.bakim_tur_id) : undefined
      };

      console.log("Gönderilen veriler:", gonderilecekVeri);

      await api.qrBakimTamamla(gonderilecekVeri);

      setTamamlandiMi(true);
      setBekleyenIs(null);
      setForm({ bakim_maliyet: "", aciklama: "", ariza_sebebi: "", bakim_tur_id: "", degisen_parcalar: [] });

      // Geçmişi yenile
      try {
        const updatedHistory = await api.getServiceHistory(id);
        setHistory(updatedHistory);
      } catch (err) { /* ignore */ }

    } catch (err) {
      console.error("Bakım tamamlama hatası:", err);
      alert("Bakım kaydedilirken hata oluştu: " + (err.message || "Bilinmeyen hata"));
    } finally {
      setKaydetYukleniyor(false);
    }
  };

  // --- YENİ SERVİS KAYDI EKLEME (MEVCUT — Bekleyen iş yoksa) ---
  const addRecord = async () => {
    if (!form.bakim_maliyet || !form.ariza_sebebi) {
      alert("Lütfen arıza sebebi ve maliyet alanlarını doldurun!");
      return;
    }

    // API'ye gönderilecek servis kaydı objesi (Payload)
    const payload = {
      makine_id: Number(id),

      // Kural 1: Eğer kullanıcı/teknisyen ID yoksa 0 (Sıfır) GÖNDERME! null veya undefined gönder ki Prisma çökmek yerine boş geçsin.
      kullanici_id: currentUser?.userId || currentUser?.kullanici_id ? Number(currentUser.userId || currentUser.kullanici_id) : null,
      teknisyen_id: currentUser?.userId || currentUser?.kullanici_id ? Number(currentUser.userId || currentUser.kullanici_id) : null,

      // Kural 2: Eğer giriş yapan kullanıcı dış servis ise (firma_id doluysa) onu kullan, yoksa formdan seçilmiş olanı al.
      servis_firma_id: currentUser?.firma_id ? Number(currentUser.firma_id) : (form.servis_firma_id ? Number(form.servis_firma_id) : null),

      // Kural 3: Sabit 1 gönderme. Formda arıza türü seçildiyse onu al, seçilmediyse veritabanındaki (3 - Donanım Arızası) ID'sini kullan.
      ariza_id: form.ariza_id ? Number(form.ariza_id) : 3,

      ariza_sebebi: form.ariza_sebebi,
      bakim_maliyet: Number(form.bakim_maliyet) || 0,
      durus_suresi: form.durus_suresi ? Number(form.durus_suresi) : null,
      bakim_tarihi: new Date().toISOString(),
      aciklama: form.aciklama,
      bakim_tur_id: form.bakim_tur_id ? Number(form.bakim_tur_id) : undefined,
      degisen_Parcalar: form.degisen_parcalar
    };

    try {
      const savedRecord = await api.addServiceRecord(payload);
      setHistory([savedRecord, ...history]);
      setForm({ ariza_sebebi: "", bakim_maliyet: "", durus_suresi: "", aciklama: "", bakim_tur_id: "", degisen_parcalar: [] });
      setTamamlandiMi(true); // Formu kapat ve başarı mesajını göster
    } catch (err) {
      console.error("Kayıt eklenemedi:", err);
      alert("Bakım kaydedilirken hata oluştu: " + (err.message || "Bilinmeyen hata"));
    }
  };

  const handleSaveFirm = async (firmData) => {
    try {
      const newFirm = await api.addFirm(firmData);
      setFirms([...firms, newFirm]);
      setForm({ ...form, servis_firma_id: newFirm.id });
      setIsModalOpen(false);
      alert(`${firmData.tip} başarıyla eklendi!`);
    } catch (error) {
      alert("Firma eklenirken hata oluştu!");
    }
  };

  const openAddFirm = (type) => {
    setModalType(type);
    setIsModalOpen(true);
  };

  const handleAddPart = () => {
    if (!selectedPartId) return;
    const parca = stoklar.find(s => String(s.stok_id) === String(selectedPartId));
    if (!parca) return;

    const varMi = form.degisen_parcalar.find(p => p.parca_id === selectedPartId);
    if (varMi) {
      setForm(prev => ({
        ...prev,
        degisen_parcalar: prev.degisen_parcalar.map(p =>
          p.parca_id === selectedPartId ? { ...p, adet: p.adet + 1 } : p
        )
      }));
    } else {
      setForm(prev => ({
        ...prev,
        degisen_parcalar: [...prev.degisen_parcalar, { parca_id: selectedPartId, parca_adi: parca.parca_adi, adet: 1 }]
      }));
    }
    setSelectedPartId("");
  };

  const handleRemovePart = (id) => {
    setForm(prev => ({
      ...prev,
      degisen_parcalar: prev.degisen_parcalar.filter(p => p.parca_id !== id)
    }));
  };

  const renderPartSelection = () => (
    <div style={{ marginBottom: "20px", padding: "15px", background: "#f8f9fa", borderRadius: "10px", border: "1px solid #ddd" }}>
      <label style={labelStil}>Değişen Parçalar </label>
      <div style={{ display: "flex", gap: "10px", marginBottom: "10px" }}>
        <select
          value={selectedPartId}
          onChange={(e) => setSelectedPartId(e.target.value)}
          style={{ ...inputStil, flex: 1, marginBottom: 0 }}
        >
          <option value="">— Parça Seçin —</option>
          {stoklar.map(s => (
            <option key={s.stok_id} value={s.stok_id} disabled={s.miktar <= 0}>
              {s.parca_adi} (Stok: {s.miktar})
            </option>
          ))}
        </select>
        <button type="button" onClick={handleAddPart} style={{ padding: "0 20px", background: "#3498db", color: "white", border: "none", borderRadius: "8px", fontWeight: "bold", cursor: "pointer" }}>
          Ekle
        </button>
      </div>

      {form.degisen_parcalar.length > 0 && (
        <div style={{ display: "flex", flexDirection: "column", gap: "8px", marginTop: "10px" }}>
          {form.degisen_parcalar.map((p, idx) => (
            <div key={idx} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", background: "white", padding: "8px 12px", borderRadius: "6px", border: "1px solid #eee" }}>
              <span style={{ fontSize: "13px", fontWeight: "bold", color: "#2c3e50" }}>{p.parca_adi}</span>
              <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                <input
                  type="number"
                  min="1"
                  value={p.adet}
                  onChange={(e) => {
                    const val = parseInt(e.target.value) || 1;
                    setForm(prev => ({
                      ...prev,
                      degisen_parcalar: prev.degisen_parcalar.map(item => item.parca_id === p.parca_id ? { ...item, adet: val } : item)
                    }));
                  }}
                  style={{ width: "50px", padding: "4px", textAlign: "center", border: "1px solid #ddd", borderRadius: "4px" }}
                />
                <span style={{ fontSize: "12px", color: "#7f8c8d" }}>Adet</span>
                <button type="button" onClick={() => handleRemovePart(p.parca_id)} style={{ background: "none", border: "none", color: "#e74c3c", cursor: "pointer", fontSize: "16px" }}>✖</button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );

  return (
    <div className="app-container" style={sayfaStil}>
      <div className="app-content-wrapper app-content" style={containerStil}>
        {/* BAŞLIK */}
        <div className="responsive-flex-col" style={{ ...headerStil, flexWrap: "wrap", gap: "10px" }}>
          <h2 style={{ margin: 0, color: "white", fontSize: "22px" }}>Bakım Kaydı</h2>
          <div style={badgeStil}>Makine ID: {id}</div>
        </div>

        {/* BAŞARILI TAMAMLAMA MESAJI */}
        {tamamlandiMi && (
          <div style={{
            background: "linear-gradient(135deg, #27ae60 0%, #2ecc71 100%)",
            color: "white", padding: "20px", borderRadius: "12px",
            marginBottom: "20px", textAlign: "center", fontSize: "16px",
            fontWeight: "bold", boxShadow: "0 4px 15px rgba(46, 204, 113, 0.4)",
          }}>
            ✅ Bakım kaydı başarıyla eklendi! Makine aktif duruma geçirildi.
          </div>
        )}

        {/* QR BAZLI BAKIM TAMAMLAMA FORMU */}
        {bekleyenIs && (
          <div style={{
            background: "white", padding: "25px", borderRadius: "16px",
            boxShadow: "0 8px 30px rgba(0,0,0,0.15)", marginBottom: "25px",
            border: "2px solid #e94560"
          }}>
            <div className="responsive-flex-col" style={{ display: "flex", alignItems: "center", gap: "10px", marginBottom: "20px", flexWrap: "wrap" }}>

              <div>
                <h3 style={{ margin: 0, color: "#e94560", fontSize: "18px" }}>Bakımı Tamamla</h3>
                <p style={{ margin: "4px 0 0 0", color: "#7f8c8d", fontSize: "13px" }}>
                  Bu makine için onaylanmış bir bakım görevi var. Formu doldurup kaydedin.
                </p>
              </div>
            </div>

            {/* Bekleyen İş Bilgisi */}
            <div style={{
              background: "rgba(233, 69, 96, 0.05)", padding: "12px 16px",
              borderRadius: "10px", marginBottom: "20px", border: "1px solid rgba(233, 69, 96, 0.15)"
            }}>
              <div style={{ fontSize: "12px", color: "#e94560", fontWeight: "bold", textTransform: "uppercase", marginBottom: "4px" }}>Bekleyen Görev</div>
              <div style={{ fontSize: "14px", color: "#2c3e50" }}>
                {bekleyenIs.ariza_notu || "Belirtilmemiş"} — <span style={{ color: "#7f8c8d" }}>{bekleyenIs.kayit_tarihi?.split('T')[0]}</span>
              </div>
            </div>

            {/* Teknisyen Bilgisi (Salt Okunur) */}
            <div style={{ marginBottom: "15px" }}>
              <label style={labelStil}>Teknisyen / Sorumlu</label>
              <div style={{ ...inputStil, background: "#f0f0f0", color: "navy", fontWeight: "bold" }}>
                {currentUser.ad || "Bilinmeyen Teknisyen"}
              </div>
            </div>

            {/* Maliyet */}
            <div style={{ marginBottom: "15px" }}>
              <label style={labelStil}>Maliyet (₺) *</label>
              <input
                type="number"
                name="bakim_maliyet"
                placeholder="Örn: 1500"
                value={form.bakim_maliyet}
                onChange={handleChange}
                style={inputStil}
              />
            </div>



            {/* Açıklama */}
            <div style={{ marginBottom: "20px" }}>
              <label style={labelStil}>Yapılan İşlem Açıklaması</label>
              <textarea
                name="aciklama"
                placeholder="Bakım sırasında neler yapıldı, hangi parçalar değiştirildi..."
                value={form.aciklama}
                onChange={handleChange}
                style={{ ...inputStil, height: "100px", resize: "vertical" }}
              />
            </div>

            {renderPartSelection()}

            {/* KAYDET BUTONU */}
            <button
              onClick={handleBakimiTamamla}
              disabled={kaydetYukleniyor}
              style={{
                width: "100%", padding: "16px",
                background: kaydetYukleniyor
                  ? "#95a5a6"
                  : "linear-gradient(135deg, #27ae60 0%, #2ecc71 100%)",
                color: "white", border: "none", borderRadius: "10px",
                fontSize: "16px", fontWeight: "bold",
                cursor: kaydetYukleniyor ? "not-allowed" : "pointer",
                boxShadow: kaydetYukleniyor ? "none" : "0 4px 15px rgba(39, 174, 96, 0.3)",
                transition: "all 0.3s ease"
              }}
            >
              {kaydetYukleniyor ? "⏳ Kaydediliyor..." : "✅ Bakımı Kaydet ve Tamamla"}
            </button>
          </div>
        )}

        {!tamamlandiMi && (
          <div className="responsive-flex-col" style={icerikStil}>
            {/* SOL - GEÇMİŞ KAYITLAR */}
            <div style={{ flex: 1 }}>
              <h3 style={{ ...baslikStil, color: "white" }}>Geçmiş İşlemler</h3>
              <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
                {sortedHistory.slice(0, 5).map((item, index) => {
                  const isTarihArray = Array.isArray(item.bakim_tarihi) && item.bakim_tarihi.length > 0;
                  const tarihDate = isTarihArray ? item.bakim_tarihi[0] : item.bakim_tarihi;
                  const formatTarih = tarihDate ? new Date(tarihDate).toLocaleDateString("tr-TR") : "Belirtilmemiş";

                  const formatMaliyet = Array.isArray(item.bakim_maliyet) ? item.bakim_maliyet[0] : item.bakim_maliyet;

                  return (
                    <div key={index} style={kayitKartStil}>
                      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
                        <div>
                          <div style={tarihStil}>{formatTarih}</div>
                          <div style={{ fontWeight: "bold", color: "navy", fontSize: "16px", marginTop: "10px" }}>
                            İşlem: {item.bakim_turu?.bakim_tur_adi || "Bakım"}
                          </div>
                          <div style={{ color: "#34495e", fontSize: "14px", marginTop: "4px" }}>
                            Duruş Süresi: <span style={{ color: "#e74c3c", fontWeight: "bold" }}>{item.durus_suresi || 0} Saat</span>
                          </div>
                          <p style={{ margin: 0, color: "#555", fontSize: "14px", marginTop: "8px", fontStyle: "italic" }}>"{item.aciklama}"</p>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* SAĞ - YENİ BAKIM KAYDI (Bekleyen iş yoksa göster) */}
            {!bekleyenIs && (
              <div style={yeniKayitAlaniStil}>
                <h3 style={baslikStil}>Yeni Bakım Kaydı</h3>

                {/* İşlemi Yapan Kişi Bilgisi (Salt Okunur) */}
                <div style={{ marginBottom: "15px" }}>
                  <label style={labelStil}>Teknisyen / Sorumlu</label>
                  <div style={{ ...inputStil, background: "#f0f0f0", color: "navy", fontWeight: "bold" }}>
                    {currentUser.ad || "Bilinmeyen Teknisyen"}
                  </div>
                </div>

                {/* Sistem Tarafından Kaydedilen Tarih (Salt Okunur) */}
                <div style={{ marginBottom: "15px" }}>
                  <label style={labelStil}>İşlem Tarihi (Sistem Tarafından Kaydedilir)</label>
                  <input
                    type="text"
                    value={new Date().toLocaleDateString("tr-TR")}
                    readOnly
                    style={{ ...inputStil, background: "#eee", cursor: "not-allowed", color: "#666" }}
                  />
                </div>

                {/* 3. Neden Yapıldığı (ariza_sebebi / ariza_id) */}
                <div style={{ marginBottom: "15px" }}>
                  <label style={labelStil}>Arıza</label>
                  <select
                    name="ariza_id"
                    value={form.ariza_id}
                    onChange={(e) => {
                      const selectedAriza = arizaSecenekleri.find(a => String(a.ariza_tur_id) === e.target.value);
                      setForm({
                        ...form,
                        ariza_id: e.target.value,
                        ariza_sebebi: selectedAriza ? selectedAriza.ariza_tur : ""
                      });
                    }}
                    style={inputStil}
                  >
                    <option value="">— Arıza Seçin —</option>
                    {arizaSecenekleri.map((ariza) => (
                      <option key={ariza.ariza_tur_id} value={ariza.ariza_tur_id}>{ariza.ariza_tur}</option>
                    ))}
                  </select>
                </div>

                {/* Bakım Türü (bakim_turu) */}
                <div style={{ marginBottom: "15px" }}>
                  <label style={labelStil}>Bakım Türü</label>
                  <select
                    name="bakim_tur_id"
                    value={form.bakim_tur_id}
                    onChange={handleChange}
                    style={inputStil}
                  >
                    <option value="">— Bakım Türü Seçin —</option>
                    {bakimTurleri.map((tur) => (
                      <option key={tur.bakim_tur_id} value={tur.bakim_tur_id}>{tur.bakim_tur_adi}</option>
                    ))}
                  </select>
                </div>

                {/* Servis Firması (Dış servis ataması için) - Sadece kendi firma_id'si olmayanlar (iç personeller) görebilir */}
                {!currentUser?.firma_id && (
                  <div style={{ marginBottom: "15px" }}>
                    <label style={labelStil}>Servis Firması (Dış Servis)</label>
                    <select
                      name="servis_firma_id"
                      value={form.servis_firma_id}
                      onChange={handleChange}
                      style={inputStil}
                    >
                      <option value="">— İç Personel Bakımı (Firma Seçmeyin) —</option>
                      {firms.filter(f => f.tip === "Servis").map((f) => (
                        <option key={f.id} value={f.id}>{f.ad}</option>
                      ))}
                    </select>
                  </div>
                )}



                {/* 5. Maliyet (bakim_maliyet) */}
                <div style={{ marginBottom: "15px" }}>
                  <label style={labelStil}>Maliyet (₺)</label>
                  <input
                    type="number"
                    name="bakim_maliyet"
                    placeholder="Örn: 1500"
                    value={form.bakim_maliyet}
                    onChange={handleChange}
                    style={inputStil}
                  />
                </div>

                {/* 5b. Duruş Süresi */}
                <div style={{ marginBottom: "15px" }}>
                  <label style={labelStil}>Duruş Süresi (Saat)</label>
                  <input
                    type="number"
                    name="durus_suresi"
                    placeholder="Örn: 2.5"
                    value={form.durus_suresi}
                    onChange={handleChange}
                    style={inputStil}
                    step="0.5"
                    min="0"
                  />
                </div>

                {/* 5. Açıklama */}
                <div style={{ marginBottom: "20px" }}>
                  <label style={labelStil}>Açıklama</label>
                  <textarea
                    name="aciklama"
                    placeholder="Bakım hakkında açıklama yazın..."
                    value={form.aciklama}
                    onChange={handleChange}
                    style={{ ...inputStil, height: "100px", resize: "vertical" }}
                  />
                </div>

                {renderPartSelection()}

                <button onClick={addRecord} style={butonStil}>Kaydı Ekle</button>
              </div>
            )}
          </div>
        )}
      </div>

      <FirmModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        onSave={handleSaveFirm}
        initialType={modalType}
      />
    </div>
  );
}

const miniButonStil = {
  padding: "4px 8px",
  fontSize: "11px",
  background: "#eef2f3",
  border: "1px solid #ddd",
  borderRadius: "4px",
  cursor: "pointer",
  color: "#333",
  fontWeight: "bold"
};

/* STILLER */
const sayfaStil = {
  minHeight: "100vh",
  background: "linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%)",
  padding: "30px",
  boxSizing: "border-box",
};

const containerStil = {
  maxWidth: "1100px",
  margin: "0 auto",
};

const headerStil = {
  display: "flex",
  justifyContent: "space-between",
  alignItems: "center",
  marginBottom: "25px",
  padding: "20px 25px",
  background: "rgba(255,255,255,0.1)",
  borderRadius: "12px",
  backdropFilter: "blur(10px)",
};

const badgeStil = {
  padding: "6px 16px",
  background: "rgba(255,255,255,0.2)",
  color: "white",
  borderRadius: "20px",
  fontSize: "13px",
  fontWeight: "bold",
};

const icerikStil = {
  display: "flex",
  gap: "25px",
};

const baslikStil = {
  color: "navy",
  marginTop: 0,
  marginBottom: "15px",
  fontSize: "18px",
};

const kayitKartStil = {
  background: "white",
  padding: "15px 20px",
  borderRadius: "10px",
  boxShadow: "0 2px 10px rgba(0,0,0,0.08)",
  borderLeft: "4px solid navy",
};

const tarihStil = {
  fontSize: "13px",
  color: "white",
  background: "navy",
  padding: "6px 14px",
  borderRadius: "6px",
  fontWeight: "bold",
  display: "inline-block",
  letterSpacing: "0.5px",
};

const yeniKayitAlaniStil = {
  width: "100%",
  maxWidth: "380px",
  flexShrink: 0,
  background: "white",
  padding: "25px",
  borderRadius: "12px",
  boxShadow: "0 4px 20px rgba(0,0,0,0.1)",
  alignSelf: "flex-start",
  boxSizing: "border-box",
};

const labelStil = {
  display: "block",
  marginBottom: "6px",
  fontWeight: "bold",
  color: "#333",
  fontSize: "14px",
};

const inputStil = {
  width: "100%",
  padding: "12px",
  border: "2px solid #ddd",
  borderRadius: "8px",
  fontSize: "14px",
  boxSizing: "border-box",
  outline: "none",
  color: "#333",
  background: "#fafafa",
  fontFamily: "inherit",
};

const butonStil = {
  width: "100%",
  padding: "14px",
  background: "navy",
  color: "white",
  border: "none",
  borderRadius: "8px",
  fontSize: "16px",
  fontWeight: "bold",
  cursor: "pointer",
};