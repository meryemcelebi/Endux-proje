import React, { useState, useEffect } from "react";
import { useParams } from "react-router-dom";
import { api } from "./services/api";
import FirmModal from "./components/FirmModal";

export default function Servis() {
  const { id } = useParams();

  const [history, setHistory] = useState([]);
  const [firms, setFirms] = useState([]);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [modalType, setModalType] = useState("Servis");

  // Verileri API'den çeken useEffect
  useEffect(() => {
    const fetchData = async () => {
      try {
        const [histData, firmData] = await Promise.all([
          api.getServiceHistory(id),
          api.getFirms() // Tüm firmaları (servis/tedarikçi) getirir
        ]);
        setHistory(histData);
        setFirms(firmData);
      } catch (err) {
        console.error("Veriler yüklenemedi", err);
      }
    };
    fetchData();
  }, [id]);

  const handleRecordPuanla = async (bakimId, puan) => {
    try {
      await api.rateServiceRecord(bakimId, puan);
      setHistory(history.map(h => h.bakim_id === bakimId ? { ...h, puan: puan } : h));
      alert("Servis kaydı puanlaması başarıyla kaydedildi!");
    } catch (error) {
      alert("Puanlama sırasında hata oluştu!");
    }
  };

  const sortedHistory = [...history].sort((a,b) => (b.puan || 0) - (a.puan || 0));

  const [form, setForm] = useState({
    kullanici_id: "",
    servis_firma_id: "",
    ariza_sebebi: "",
    bakim_maliyet: "",
    aciklama: "",
    bakim_turu: ""
  });

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const addRecord = async () => {
    if (!form.kullanici_id || !form.servis_firma_id || !form.bakim_maliyet) {
      alert("Zorunlu alanları doldur!");
      return;
    }

    const payload = {
      makine_id: Number(id),
      kullanici_id: Number(form.kullanici_id),
      servis_firma_id: Number(form.servis_firma_id),
      ariza_id: 1, // Mock data for Backend compatibility
      ariza_sebebi: form.ariza_sebebi,
      bakim_maliyet: [parseFloat(form.bakim_maliyet)],
      bakim_tarihi: [new Date().toISOString()],
      aciklama: form.aciklama,
      bakim_turu: form.bakim_turu ? [form.bakim_turu] : ["Planlı Bakım"]
    };

    try {
      const savedRecord = await api.addServiceRecord(payload);
      // Backend should return the firm name, but since we're mock, let's find it
      const selectedFirm = firms.find(f => f.id === Number(form.servis_firma_id));
      const recordWithFirmName = { ...savedRecord, servis_firmasi: selectedFirm?.ad || `ID: ${form.servis_firma_id}` };
      
      setHistory([recordWithFirmName, ...history]);
      setForm({ kullanici_id: "", servis_firma_id: "", ariza_sebebi: "", bakim_maliyet: "", aciklama: "", bakim_turu: "" });
    } catch (err) {
      console.error("Kayıt eklenemedi:", err);
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

  return (
    <div style={sayfaStil}>
      <div style={containerStil}>
        {/* BAŞLIK */}
        <div style={headerStil}>
          <h2 style={{ margin: 0, color: "white", fontSize: "22px" }}>Teknik Servis Paneli</h2>
          <div style={badgeStil}>Makine ID: {id}</div>
        </div>

        <div style={icerikStil}>
          {/* SOL - GEÇMİŞ KAYITLAR */}
          <div style={{ flex: 1 }}>
            <h3 style={{ ...baslikStil, color: "white" }}>Geçmiş İşlemler</h3>
            <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
              {sortedHistory.map((item, index) => {
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
                          Firma: {item.servis_firmasi || `ID: ${item.servis_firma_id}`}
                        </div>
                        <div style={{ color: "#34495e", fontSize: "14px", marginTop: "4px" }}>
                          Sebep: {item.ariza_sebebi || "Belirtilmedi"} | Maliyet: {formatMaliyet} ₺
                        </div>
                        <p style={{ margin: 0, color: "#555", fontSize: "14px", marginTop: "8px", fontStyle: "italic" }}>"{item.aciklama}"</p>
                      </div>
                      <div style={{ textAlign: "right" }}>
                        <div style={{ fontSize: "12px", color: "#7f8c8d", marginBottom: "4px", fontWeight: "bold" }}>İşlem Puanı</div>
                        <div style={{ display: "flex", gap: "2px" }}>
                          {[1, 2, 3, 4, 5].map(star => (
                            <span key={star} 
                                  onClick={() => handleRecordPuanla(item.bakim_id, star)}
                                  style={{ 
                                    cursor: "pointer", 
                                    fontSize: "20px", 
                                    color: (item.puan || 0) >= star ? "#f39c12" : "#dfe6e9",
                                    transition: "transform 0.1s"
                                  }}
                                  onMouseOver={(e) => e.target.style.transform = "scale(1.2)"}
                                  onMouseOut={(e) => e.target.style.transform = "scale(1)"}
                            >
                               ★
                            </span>
                          ))}
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* SAĞ - YENİ BAKIM KAYDI */}
          <div style={yeniKayitAlaniStil}>
            <h3 style={baslikStil}>Yeni Bakım Kaydı</h3>

            {/* 1. İşlemi Yapan (kullanici_id) */}
            <div style={{ marginBottom: "15px" }}>
              <label style={labelStil}>İşlemi Yapan (Kullanıcı ID)</label>
              <input
                type="number"
                name="kullanici_id"
                placeholder="Kullanıcı ID giriniz"
                value={form.kullanici_id}
                onChange={handleChange}
                style={inputStil}
              />
            </div>

            {/* 2. Servis Şirketi / Firma Seçimi (Açılır Liste) */}
            <div style={{ marginBottom: "15px" }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "6px" }}>
                <label style={{ ...labelStil, marginBottom: 0 }}>Servis Şirketi / Firma</label>
                <div style={{ display: "flex", gap: "5px" }}>
                  <button onClick={() => openAddFirm("Servis")} style={miniButonStil}>+ Servis Firması Ekle</button>
                </div>
              </div>
              <select
                name="servis_firma_id"
                value={form.servis_firma_id}
                onChange={handleChange}
                style={inputStil}
              >
                <option value="">Firma Seçiniz</option>
                {firms.map(f => (
                  <option key={f.id} value={f.id}>{f.ad} ({f.tip})</option>
                ))}
              </select>
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

            {/* 3. Neden Yapıldığı (ariza_sebebi) */}
            <div style={{ marginBottom: "15px" }}>
              <label style={labelStil}>Arıza Sebebi</label>
              <input
                type="text"
                name="ariza_sebebi"
                placeholder="Örn: Sensör Hatası, Periyodik Bakım"
                value={form.ariza_sebebi}
                onChange={handleChange}
                style={inputStil}
              />
            </div>
            
            {/* Bakım Türü (bakim_turu) */}
            <div style={{ marginBottom: "15px" }}>
              <label style={labelStil}>Bakım Türü</label>
              <input
                type="text"
                name="bakim_turu"
                placeholder="Örn: Rutin, Planlı"
                value={form.bakim_turu}
                onChange={handleChange}
                style={inputStil}
              />
            </div>

            {/* 4. Maliyet (bakim_maliyet) */}
            <div style={{ marginBottom: "15px" }}>
              <label style={labelStil}>Maliyet (Bakım Maliyeti)</label>
              <input
                type="number"
                name="bakim_maliyet"
                placeholder="₺ maliyet giriniz"
                value={form.bakim_maliyet}
                onChange={handleChange}
                style={inputStil}
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

            <button onClick={addRecord} style={butonStil}>Kaydı Ekle</button>
          </div>
        </div>
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
  width: "380px",
  flexShrink: 0,
  background: "white",
  padding: "25px",
  borderRadius: "12px",
  boxShadow: "0 4px 20px rgba(0,0,0,0.1)",
  alignSelf: "flex-start",
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