import React, { useState, useEffect } from "react";
import Sidebar from "./Sidebar";
import Navbar from "./Navbar";
import { api } from "./services/api";
import FirmModal from "./components/FirmModal";

export default function ServisMerkezi() {
  // --- STATE TANIMLAMALARI ---
  const [tasks, setTasks] = useState([]); // Teknik servis görev listesi (Bekleyen/Tamamlanan)
  const [firms, setFirms] = useState([]); // Sistemde kayıtlı servis firmaları ve tedarikçiler
  const [loading, setLoading] = useState(true); // Veri yükleme durumu
  const [activeTab, setActiveTab] = useState("gorevler"); // Aktif sekme kontrolü (gorevler, firmalar, onay-merkezi, disServis)
  const [isModalOpen, setIsModalOpen] = useState(false); // Firma ekleme modali durumu
  const [modalType, setModalType] = useState("Servis"); // Modal tipi (Servis Firması mı yoksa Parça Tedarikçisi mi?)
  const [allHistory, setAllHistory] = useState([]); // Tüm servis geçmişi (Onay merkezi puanlamaları için)

  // --- DIŞ SERVİS PUANLAMA STATE'LERİ ---
  const [disRatingId, setDisRatingId] = useState(null); // Puanlanan dış servis ID'si
  const [disRatingValue, setDisRatingValue] = useState(0); // Verilen yıldız puanı
  const [disRatingComment, setDisRatingComment] = useState(""); // Servis hakkında yorum
  
  // Statik dış servis listesi (Simüle edilmiş veriler)
  const [disServisler, setDisServisler] = useState([
    { id: 1, firma: "Alfa Teknik Servis", uzmanlik: "Genel Mekanik", telefon: "0216 111 2233", email: "info@alfateknik.com", sorumlu_ad: "Hasan", sorumlu_soyad: "Demir", sorumlu_tel: "0532 111 2233", islem: 15, puan: 4.8, yorum: "" },
    { id: 2, firma: "Beta Endüstriyel Tamir", uzmanlik: "Elektronik & PCB", telefon: "0212 444 5566", email: "destek@beta.com", sorumlu_ad: "Kemal", sorumlu_soyad: "Yıldız", sorumlu_tel: "0544 555 6677", islem: 4, puan: 3.2, yorum: "" },
    { id: 3, firma: "Gama Otomasyon", uzmanlik: "Robotik Eğitim", telefon: "0232 555 6677", email: "info@gama.com", sorumlu_ad: "Zeynep", sorumlu_soyad: "Aydın", sorumlu_tel: "0505 999 8877", islem: 29, puan: 4.9, yorum: "" },
    { id: 4, firma: "Delta Motor Revizyon", uzmanlik: "Motor & Spindle", telefon: "0312 222 3344", email: "servis@delta.com", sorumlu_ad: "Murat", sorumlu_soyad: "Kaya", sorumlu_tel: "0533 444 5566", islem: 1, puan: 2.0, yorum: "" },
  ]);

  const payloadStr = localStorage.getItem("user_payload");
  const userPayload = payloadStr ? JSON.parse(payloadStr) : { ad: "Bilinmeyen", rol_id: 2 };
  const isAdmin = userPayload.rol_id === 0 || userPayload.rol_id === 1;

  // --- VERİ ÇEKME (API) ---
  useEffect(() => {
    const fetchData = async () => {
      try {
        // Görevler, firmalar ve servis geçmişini eşzamanlı olarak çek
        const [taskData, firmData, historyData] = await Promise.all([
          api.getTechTasks(),
          api.getFirms(),
          api.getAllServiceHistory()
        ]);
        setTasks(taskData);
        setFirms(firmData);
        setAllHistory(historyData);
      } catch (err) {
        console.error("Servis verileri yüklenirken hata oluştu:", err);
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, []);

  const handlePuanla = async (firmaId, puan) => {
    try {
      await api.rateFirm(firmaId, puan);
      setFirms(firms.map(f => f.id === firmaId ? { ...f, ortalama_puan: puan } : f));
    } catch (error) {
      alert("Puanlama sırasında hata oluştu!");
    }
  };



  const handleDisRateSave = (id) => {
    setDisServisler(disServisler.map(s => s.id === id ? { ...s, puan: disRatingValue, yorum: disRatingComment } : s));
    setDisRatingId(null);
    setDisRatingValue(0);
    setDisRatingComment("");
    alert("Puanlama ve yorum kaydedildi!");
  };

  const handleSaveFirm = async (firmData) => {
    try {
      await api.addFirm(firmData);
      setIsModalOpen(false);
      const updatedFirms = await api.getFirms();
      setFirms(updatedFirms);
      alert(`${firmData.tip} başarıyla eklendi!`);
    } catch (error) {
      alert("Firma eklenirken hata oluştu!");
    }
  };

  // RENDER: GÖREV LİSTESİ
  const renderGorevListesi = () => (
    <div style={{ overflowX: "auto" }}>
      <table style={tableStyle}>
        <thead>
          <tr>
            <th style={thStyle}>Makine</th>
            <th style={thStyle}>Durum</th>
            <th style={thStyle}>Arıza Notu</th>
            <th style={thStyle}>Kayıt Tarihi</th>
          </tr>
        </thead>
        <tbody>
          {tasks.length === 0 ? (
            <tr><td colSpan="4" style={{ textAlign: "center", padding: "40px", color: "#95a5a6" }}>Bekleyen iş kaydı bulunamadı.</td></tr>
          ) : (
            tasks.map(t => (
              <tr key={t.id} style={trStyle}>
                <td style={{ ...tdStyle, fontWeight: "bold", color: "#0f3460" }}>{t.makine_ad}</td>
                <td style={tdStyle}>
                  <span style={t.durum === "TAMAMLANDI" ? badgeActive : { ...badgeInactive, background: "rgba(241, 196, 15, 0.15)", color: "#f39c12", border: "1px solid rgba(241, 196, 15, 0.3)" }}>
                    {t.durum}
                  </span>
                </td>
                <td style={{ ...tdStyle, maxWidth: "300px", whiteSpace: "normal" }}>{t.ariza_notu}</td>
                <td style={tdStyle}>
                  <div style={{ fontSize: "14px", color: "#555" }}>📅 {t.tarih}</div>
                </td>
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  );

  // RENDER: SİSTEM FIRMALARI (Servis Firmaları)



  // RENDER: SİSTEM FIRMALARI (Servis Firmaları)
  const [firmRatingId, setFirmRatingId] = useState(null);
  const [firmRatingValue, setFirmRatingValue] = useState(0);
  const [firmRatingComment, setFirmRatingComment] = useState("");

  const handleFirmRateSave = (id) => {
    setFirms(firms.map(f => f.id === id ? { ...f, ortalama_puan: firmRatingValue, yorum: firmRatingComment } : f));
    setFirmRatingId(null);
    setFirmRatingValue(0);
    setFirmRatingComment("");
    alert("Firma puanlaması ve yorumu kaydedildi!");
  };

  const renderFirmalar = () => {
    const servisFirms = firms.filter(f => f.tip === "Servis");
    return (
      <div style={{ overflowX: "auto" }}>
        <table style={tableStyle}>
          <thead>
            <tr>
              <th style={thStyle}>Firma Adı & Türü</th>
              <th style={thStyle}>İletişim</th>
              <th style={thStyle}>Adres</th>
              <th style={thStyle}>Ortalama Puan</th>
              <th style={thStyle}>Durum</th>
            </tr>
          </thead>
          <tbody>
            {servisFirms.length > 0 ? (
              servisFirms.map((f) => (
                <React.Fragment key={f.id}>
                  <tr style={trStyle}>
                    <td style={{ ...tdStyle, fontWeight: "bold", color: "#0f3460" }}>
                      {f.ad || f.firma_adi}
                      <div style={{ fontSize: "11px", color: "#95a5a6", fontWeight: "normal", marginTop: "4px" }}>{f.tip}</div>
                    </td>
                    <td style={tdStyle}>
                      <div style={{ fontSize: "13px" }}>📞 {f.telefon}</div>
                      <div style={{ fontSize: "12px", color: "#7f8c8d" }}>✉️ {f.email}</div>
                    </td>
                    <td style={tdStyle}>
                      <div style={{ fontSize: "13px", color: "#555" }}>{f.adres || "-"}</div>
                    </td>
                    <td style={tdStyle}>
                      <div style={{ display: "flex", gap: "2px", alignItems: "center" }}>
                        {[1, 2, 3, 4, 5].map((star) => (
                          <span key={star} style={{ fontSize: "18px", color: star <= Math.round(f.ortalama_puan || 0) ? "#f39c12" : "#dfe6e9" }}>
                            ★
                          </span>
                        ))}
                        {f.ortalama_puan > 0 && <strong style={{ marginLeft: "6px", color: "#0f3460", fontSize: "13px" }}>{f.ortalama_puan}</strong>}
                      </div>
                      {f.yorum && <div style={{ fontSize: "12px", color: "#7f8c8d", marginTop: "4px", fontStyle: "italic" }}>💬 {f.yorum}</div>}
                    </td>
                    <td style={tdStyle}>
                      <span style={f.aktif !== false ? badgeActive : badgeInactive}>
                        {f.aktif !== false ? "Aktif" : "Pasif"}
                      </span>
                    </td>
                  </tr>
                </React.Fragment>
              ))
            ) : (
              <tr>
                <td colSpan="6" style={{ padding: "40px", textAlign: "center", color: "#95a5a6" }}>
                  Servis firması bulunamadı.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    );
  };

  // RENDER: DIŞ SERVİS PUANLAMALARI
  const renderDisServis = () => (
    <div style={{ overflowX: "auto" }}>
      <table style={tableStyle}>
        <thead>
          <tr>
            <th style={thStyle}>Servis Firması & Uzmanlık</th>
            <th style={thStyle}>Firma İletişim</th>
            <th style={thStyle}>Sorumlu Teknisyen</th>
            <th style={thStyle}>İşlemler</th>
            <th style={thStyle}>Ortalama Puan</th>
            <th style={thStyle}>Performans Durumu</th>
            <th style={thStyle}>İşlem</th>
          </tr>
        </thead>
        <tbody>
          {disServisler.map((s) => (
            <React.Fragment key={s.id}>
              <tr style={trStyle}>
                <td style={tdStyle}>
                  <div style={{ color: "#0f3460", fontWeight: "bold", fontSize: "16px" }}>{s.firma}</div>
                  <div style={{ fontSize: "12px", color: "white", background: "#f39c12", padding: "3px 8px", borderRadius: "10px", display: "inline-block", marginTop: "4px", fontWeight: "bold" }}>{s.uzmanlik}</div>
                </td>
                <td style={tdStyle}>
                  <div style={{ fontSize: "13px", color: "#333", marginBottom: "4px" }}>📞 {s.telefon}</div>
                  <div style={{ fontSize: "13px", color: "#666" }}>✉️ {s.email}</div>
                </td>
                <td style={tdStyle}>
                  <div style={{ fontSize: "14px", fontWeight: "bold", color: "#2c3e50" }}>{s.sorumlu_ad} {s.sorumlu_soyad}</div>
                  <div style={{ fontSize: "12px", color: "#7f8c8d", marginTop: "4px" }}>📱 {s.sorumlu_tel}</div>
                </td>
                <td style={tdStyle}>
                  <span style={{ fontWeight: "bold", color: "#2980b9", fontSize: "15px" }}>{s.islem}</span> <span style={{ fontSize: "13px", color: "#7f8c8d" }}>Kayıt</span>
                </td>
                <td style={tdStyle}>
                  <div style={{ display: "flex", gap: "2px", fontSize: "20px" }}>
                    {[1, 2, 3, 4, 5].map((star) => (
                      <span key={star} style={{ color: star <= Math.round(s.puan) ? "#f39c12" : "#dfe6e9", textShadow: star <= Math.round(s.puan) ? "0 0 5px rgba(243, 156, 18, 0.4)" : "none" }}>
                        ★
                      </span>
                    ))}
                    <span style={{ fontSize: "16px", marginLeft: "12px", alignSelf: "center", color: "#0f3460", fontWeight: "bold" }}>{s.puan.toFixed(1)}</span>
                  </div>
                </td>
                <td style={tdStyle}>
                  {s.puan >= 4.0 ? (
                    <span style={{ color: "#2ecc71", fontWeight: "bold", background: "rgba(46, 204, 113, 0.15)", padding: "5px 12px", borderRadius: "15px" }}>Mükemmel Performans</span>
                  ) : s.puan >= 3.0 ? (
                    <span style={{ color: "#f1c40f", fontWeight: "bold", background: "rgba(241, 196, 15, 0.15)", padding: "5px 12px", borderRadius: "15px" }}>Ortalama Üstü</span>
                  ) : (
                    <span style={{ color: "#e74c3c", fontWeight: "bold", background: "rgba(231, 76, 60, 0.15)", padding: "5px 12px", borderRadius: "15px" }}>Zayıf (Dikkate Alınmalı)</span>
                  )}
                </td>
                <td style={tdStyle}>
                  {s.yorum && <div style={{ fontSize: "12px", color: "#7f8c8d", marginTop: "4px", fontStyle: "italic" }}>💬 {s.yorum}</div>}
                  <button onClick={() => { setDisRatingId(disRatingId === s.id ? null : s.id); setDisRatingValue(Math.round(s.puan)); setDisRatingComment(s.yorum || ""); }} style={{ padding: "8px 18px", color: "white", border: "none", borderRadius: "8px", fontWeight: "bold", cursor: "pointer", fontSize: "13px", background: disRatingId === s.id ? "#e74c3c" : "#e94560" }}>
                    {disRatingId === s.id ? "Kapat" : "⭐ Puanla"}
                  </button>
                </td>
              </tr>
              {disRatingId === s.id && (
                <tr>
                  <td colSpan="7" style={{ padding: "0 16px 20px 16px", background: "#f8f9fa", borderBottom: "2px solid #e1e5eb" }}>
                    <div style={{ padding: "20px", background: "white", borderRadius: "12px", border: "1px solid #e1e5eb", marginTop: "10px" }}>
                      <div style={{ marginBottom: "12px", fontWeight: "bold", color: "#0f3460", fontSize: "15px" }}>Firma Puanlaması - {s.firma}</div>
                      <div style={{ display: "flex", gap: "6px", marginBottom: "15px" }}>
                        {[1, 2, 3, 4, 5].map(star => (
                          <span key={star} onClick={() => setDisRatingValue(star)} style={{ cursor: "pointer", fontSize: "28px", color: disRatingValue >= star ? "#f39c12" : "#dfe6e9", transition: "0.2s" }}>★</span>
                        ))}
                        {disRatingValue > 0 && <span style={{ alignSelf: "center", marginLeft: "10px", fontWeight: "bold", color: "#f39c12", fontSize: "18px" }}>{disRatingValue}/5</span>}
                      </div>
                      <textarea value={disRatingComment} onChange={(e) => setDisRatingComment(e.target.value)} placeholder="Yorum yazınız..." style={{ width: "100%", padding: "12px", borderRadius: "8px", border: "1px solid #ddd", outline: "none", minHeight: "70px", fontSize: "14px", resize: "vertical", boxSizing: "border-box" }} />
                      <div style={{ display: "flex", justifyContent: "flex-end", marginTop: "12px" }}>
                        <button onClick={() => handleDisRateSave(s.id)} disabled={disRatingValue === 0} style={{ padding: "10px 25px", background: "#27ae60", color: "white", border: "none", borderRadius: "8px", fontWeight: "bold", cursor: "pointer", fontSize: "14px", opacity: disRatingValue === 0 ? 0.5 : 1 }}>Kaydet</button>
                      </div>
                    </div>
                  </td>
                </tr>
              )}
            </React.Fragment>
          ))}
        </tbody>
      </table>
    </div>
  );

  return (
    <div style={{ display: "flex", background: "#f5f6fa", minHeight: "100vh" }}>
      <Sidebar />
      <div style={{ flex: 1, display: "flex", flexDirection: "column", height: "100vh", overflow: "hidden" }}>
        <Navbar />
        <div style={{ padding: "30px", flex: 1, overflowY: "auto" }}>

          <div style={{ marginBottom: "25px", display: "flex", justifyContent: "space-between", alignItems: "flex-end" }}>
            <div>
              <h2 style={{ margin: 0, color: "#0f3460", fontSize: "28px", fontWeight: "bold" }}>Teknik Servis Paneli</h2>
              <p style={{ margin: "5px 0 0 0", color: "#7f8c8d" }}>
                Aşağıdaki seçenekleri kullanarak servis süreçlerini ve firma detaylarını yönetin.
              </p>
            </div>
            {activeTab === "firmalar" && isAdmin && (
              <button onClick={() => { setModalType("Servis"); setIsModalOpen(true); }} style={ekleButonStil}>
                + Yeni Firma Ekle
              </button>
            )}
          </div>

          {/* YATAY SEÇENEKLER MENÜSÜ */}
          <div style={tabContainerStyle}>
            <button
              onClick={() => setActiveTab("gorevler")}
              style={activeTab === "gorevler" ? activeTabStyle : inactiveTabStyle}
              onMouseOver={(e) => { if (activeTab !== "gorevler") e.target.style.background = "rgba(255,255,255,0.15)"; }}
              onMouseOut={(e) => { if (activeTab !== "gorevler") e.target.style.background = "rgba(255,255,255,0.05)"; }}
            >
              İş Listesi
            </button>
            <button
              onClick={() => setActiveTab("firmalar")}
              style={activeTab === "firmalar" ? activeTabStyle : inactiveTabStyle}
              onMouseOver={(e) => { if (activeTab !== "firmalar") e.target.style.background = "rgba(255,255,255,0.15)"; }}
              onMouseOut={(e) => { if (activeTab !== "firmalar") e.target.style.background = "rgba(255,255,255,0.05)"; }}
            >
              Servis Firmaları
            </button>

            <button
              onClick={() => setActiveTab("disServis")}
              style={activeTab === "disServis" ? activeTabStyle : inactiveTabStyle}
              onMouseOver={(e) => { if (activeTab !== "disServis") e.target.style.background = "rgba(255,255,255,0.15)"; }}
              onMouseOut={(e) => { if (activeTab !== "disServis") e.target.style.background = "rgba(255,255,255,0.05)"; }}
            >
              Dış Servis Puanlamaları
            </button>
          </div>

          {loading ? (
            <div style={{ textAlign: "center", marginTop: "50px", color: "#95a5a6", fontSize: "18px" }}>Yükleniyor...</div>
          ) : (
            <div style={contentCardStyle} className="glass-card-animation" key={activeTab}>
              {activeTab === "gorevler" && renderGorevListesi()}
              {activeTab === "firmalar" && renderFirmalar()}
              {activeTab === "disServis" && renderDisServis()}
            </div>
          )}

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

// STILLER
const tabContainerStyle = {
  display: "flex",
  gap: "12px",
  marginBottom: "25px",
  borderBottom: "1px solid #e1e5eb",
  paddingBottom: "15px"
};

const activeTabStyle = {
  background: "linear-gradient(135deg, #e94560 0%, #c0392b 100%)",
  color: "white",
  border: "none",
  padding: "14px 28px",
  borderRadius: "10px",
  fontSize: "15px",
  fontWeight: "bold",
  cursor: "pointer",
  transition: "all 0.3s ease",
  boxShadow: "0 6px 20px rgba(233, 69, 96, 0.4)",
  transform: "translateY(-2px)"
};

const inactiveTabStyle = {
  background: "#eee",
  color: "#7f8c8d",
  border: "1px solid #ddd",
  padding: "14px 28px",
  borderRadius: "10px",
  fontSize: "15px",
  fontWeight: "bold",
  cursor: "pointer",
  transition: "all 0.3s ease",
};

const contentCardStyle = {
  background: "white",
  padding: "30px",
  borderRadius: "20px",
  boxShadow: "0 10px 40px 0 rgba(0, 0, 0, 0.05)",
  border: "1px solid #eee",
  overflowX: "auto"
};

const tableStyle = { width: "100%", borderCollapse: "collapse", minWidth: "900px" };

const thStyle = {
  textAlign: "left",
  padding: "16px",
  background: "#f8f9fa",
  color: "#34495e",
  fontWeight: "bold",
  fontSize: "13px",
  textTransform: "uppercase",
  letterSpacing: "1px",
  borderBottom: "2px solid #e1e5eb",
  borderTopLeftRadius: "8px",
  borderTopRightRadius: "8px"
};

const tdStyle = {
  padding: "18px 16px",
  fontSize: "14px",
  color: "#555",
  borderBottom: "1px solid #f1f2f6",
  verticalAlign: "middle"
};

const trStyle = {
  transition: "background 0.2s ease"
};

const ekleButonStil = {
  padding: "12px 25px",
  background: "#27ae60",
  color: "white",
  border: "none",
  borderRadius: "10px",
  fontWeight: "bold",
  cursor: "pointer",
  boxShadow: "0 4px 15px rgba(39, 174, 96, 0.3)"
};

const baslikStil = {
  color: "#0f3460",
  marginTop: 0,
  fontSize: "20px",
  fontWeight: "bold",
  borderBottom: "2px solid #f1f2f6",
  paddingBottom: "15px",
  marginBottom: "20px"
};

const listeOgeStil = {
  background: "#fdfdfd",
  padding: "20px",
  borderRadius: "12px",
  border: "1px solid #e1e5eb"
};

const uzmanlikBadgeStil = { display: "inline-block", padding: "2px 8px", background: "rgba(243, 156, 18, 0.12)", color: "#e67e22", borderRadius: "4px", fontSize: "11px", fontWeight: "bold", marginTop: "5px" };
const badgeActive = { padding: "6px 14px", background: "rgba(46, 204, 113, 0.15)", color: "#2ecc71", borderRadius: "20px", fontSize: "12px", fontWeight: "bold", boxShadow: "0 0 10px rgba(46, 204, 113, 0.2)", border: "1px solid rgba(46, 204, 113, 0.3)" };
const badgeInactive = { padding: "6px 14px", background: "rgba(231, 76, 60, 0.15)", color: "#e74c3c", borderRadius: "20px", fontSize: "12px", fontWeight: "bold", border: "1px solid rgba(231, 76, 60, 0.3)" };

// --- ONAY MERKEZİ YENİ STİLLER ---
const graphPanelStyle = {
  display: "flex",
  gap: "30px",
  background: "rgba(15, 52, 96, 0.03)",
  padding: "30px",
  borderRadius: "20px",
  border: "1px solid rgba(15, 52, 96, 0.1)",
  alignItems: "center"
};

const chartCenterTextStyle = {
  position: "absolute",
  top: "0",
  left: "0",
  width: "100%",
  height: "100%",
  display: "flex",
  flexDirection: "column",
  justifyContent: "center",
  alignItems: "center"
};

const legendItemStyle = {
  display: "flex",
  alignItems: "center",
  gap: "12px",
  padding: "8px 15px",
  background: "white",
  borderRadius: "8px",
  boxShadow: "0 2px 5px rgba(0,0,0,0.05)"
};

const approvalSummaryCard = {
  width: "250px",
  padding: "20px",
  background: "white",
  borderRadius: "16px",
  boxShadow: "0 4px 15px rgba(0,0,0,0.05)",
  border: "1px solid #f1f2f6"
};

const onayBolumBaslikStyle = {
  fontSize: "16px",
  fontWeight: "800",
  color: "#0f3460",
  display: "flex",
  alignItems: "center",
  gap: "10px",
  marginBottom: "15px"
};

const onayKartStil = {
  background: "white",
  padding: "15px 20px",
  borderRadius: "12px",
  border: "1px solid #e1e5eb",
  display: "flex",
  justifyContent: "space-between",
  alignItems: "center",
  gap: "15px",
  transition: "transform 0.2s"
};

const onayButonStil = {
  padding: "8px 15px",
  background: "#e94560",
  color: "white",
  border: "none",
  borderRadius: "8px",
  fontSize: "12px",
  fontWeight: "bold",
  cursor: "pointer",
  whiteSpace: "nowrap"
};

const emptyListStil = {
  textAlign: "center",
  padding: "30px",
  color: "#95a5a6",
  fontSize: "14px",
  fontStyle: "italic",
  background: "#f8f9fa",
  borderRadius: "12px",
  border: "1px dashed #ddd"
};

if (typeof document !== "undefined") {
  const style = document.createElement("style");
  style.innerHTML = `
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(10px); }
      to { opacity: 1; transform: translateY(0); }
    }
    .glass-card-animation {
      animation: fadeIn 0.4s ease-out;
    }
    tr:hover {
      background: rgba(255, 255, 255, 0.03) !important;
    }
    .onay-kart:hover {
      transform: translateY(-3px);
      box-shadow: 0 5px 15px rgba(0,0,0,0.08);
      border-color: #e94560;
    }
  `;
  document.head.appendChild(style);
}

