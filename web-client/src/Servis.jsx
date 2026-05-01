import React, { useState, useEffect } from "react";
import { useParams } from "react-router-dom";
import { api } from "./services/api";
import FirmModal from "./components/FirmModal";

export default function Servis() {
  const { id } = useParams();

  const [history, setHistory] = useState([]); // Makineye ait eski servis kayıtları
  const [firms, setFirms] = useState([]); // Sistemdeki tüm kayıtlı firmalar (Servis/Tedarikçi)
  const [isModalOpen, setIsModalOpen] = useState(false); // Yeni firma ekleme modalı durumu
  const [modalType, setModalType] = useState("Servis"); // Eklenecek firmanın türü

  // Giriş yapmış kullanıcı bilgisini al
  const currentUser = JSON.parse(localStorage.getItem("user_payload") || "{}");

  // --- VERİ ÇEKME SÜRECİ ---
  useEffect(() => {
    const fetchData = async () => {
      try {
        // Makineye özel servis geçmişini ve genel firma listesini çek (Paralel istek)
        const [histData, firmData] = await Promise.all([
          api.getServiceHistory(id),
          api.getFirms()
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
      await api.rateMaintenance(bakimId, puan);
      setHistory(history.map(h => h.bakim_id === bakimId ? { ...h, servis_puan: { puan: puan } } : h));
      alert("Servis kaydı puanlaması başarıyla kaydedildi!");
    } catch (error) {
      alert("Puanlama sırasında hata oluştu!");
    }
  };

  const sortedHistory = [...history].sort((a, b) => (b.servis_puan?.puan || 0) - (a.servis_puan?.puan || 0));

  const [form, setForm] = useState({
    ariza_sebebi: "",
    bakim_maliyet: "",
    durus_suresi: "", // Yeni alan
    aciklama: "",
    bakim_turu: ""
  });

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  // --- YENİ SERVİS KAYDI EKLEME ---
  const addRecord = async () => {
    if (!form.bakim_maliyet || !form.ariza_sebebi) {
      alert("Lütfen arıza sebebi ve maliyet alanlarını doldurun!");
      return;
    }

    // API'ye gönderilecek servis kaydı objesi (Payload)
    const payload = {
      makine_id: Number(id),
      kullanici_id: Number(currentUser.kullanici_id || 0),
      servis_firma_id: Number(currentUser.firma_id || 1),
      ariza_id: 1,
      ariza_sebebi: form.ariza_sebebi,
      bakim_maliyet: [parseFloat(form.bakim_maliyet)],
      durus_suresi: Number(form.durus_suresi), // Makinenin ne kadar süre devre dışı kaldığı
      bakim_tarihi: [new Date().toISOString()],
      aciklama: form.aciklama,
      bakim_turu: form.bakim_turu ? [form.bakim_turu] : ["Planlı Bakım"]
    };

    try {
      const savedRecord = await api.addServiceRecord(payload);
      // Yerel listeyi güncelle (UI'da anlık görünmesi için)
      setHistory([savedRecord, ...history]);
      // Formu temizle
      setForm({ ariza_sebebi: "", bakim_maliyet: "", durus_suresi: "", aciklama: "", bakim_turu: "" });
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
                          İşlem: {item.bakim_turu?.[0] || "Bakım"}
                        </div>
                        <div style={{ color: "#34495e", fontSize: "14px", marginTop: "4px" }}>
                          Duruş Süresi: <span style={{ color: "#e74c3c", fontWeight: "bold" }}>{item.durus_suresi || 0} Saat</span> | Maliyet: {formatMaliyet} ₺
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
                                color: (item.servis_puan?.puan || 0) >= star ? "#f39c12" : "#dfe6e9",
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

            {/* 4. Makine Duruş Süresi (Yeni) */}
            <div style={{ marginBottom: "15px" }}>
              <label style={labelStil}>Makine Duruş Süresi (Saat)</label>
              <input
                type="number"
                name="durus_suresi"
                placeholder="Kaç saat sürdü?"
                value={form.durus_suresi}
                onChange={handleChange}
                style={{ ...inputStil, border: "2px solid #e74c3c" }}
              />
            </div>

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