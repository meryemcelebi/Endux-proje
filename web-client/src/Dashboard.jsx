import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import Sidebar from "./Sidebar";
import Navbar from "./Navbar";
import { api } from "./services/api";

/**
 * Ana Kontrol Paneli (Dashboard)
 * Fabrika genelindeki makine durumlarını, kritik uyarıları ve 
 * performans verilerini (OEE) özetleyen ana yönetim ekranıdır.
 */
export default function Dashboard() {
  const navigate = useNavigate();

  // --- CANLI VERİLER (API'den Çekilen Makineler) ---
  const [machinesList, setMachinesList] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  React.useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        const data = await api.getMachines();
        // Verileri kategorilere göre etiketleyelim (Dashboard mantığına uygun şekilde)
        const enrichedData = data.map(m => {
          let kategori = "Aktif";
          if (m.mevcut_risk_skoru > 0.5) kategori = "Yüksek Riskli";
          else if (m.aktiflik_durumu === "Bakımda") kategori = "Bakımda Olan";
          else if (m.aktiflik_durumu === "Bakımı Yaklaşan") kategori = "Bakımı Yaklaşan";
          else if (m.aktiflik_durumu === "Arızalı") kategori = "Yüksek Riskli";
          
          return { ...m, id: m.makine_id, ad: m.makine_ad, kategori };
        });
        setMachinesList(enrichedData);
      } catch (err) {
        console.error("Dashboard verileri yüklenemedi", err);
      } finally {
        setIsLoading(false);
      }
    };
    fetchDashboardData();
  }, []);

  const riskyMachines = machinesList.filter(m => m.kategori !== "Aktif");
  const yRCount = machinesList.filter(m => m.kategori === "Yüksek Riskli").length;
  const bYCount = machinesList.filter(m => m.kategori === "Bakımı Yaklaşan").length;
  const bOCount = machinesList.filter(m => m.kategori === "Bakımda Olan").length;

  const [isAlertModalOpen, setIsAlertModalOpen] = useState(false);
  const [activeBreakdownId, setActiveBreakdownId] = useState(null);
  const [breakdownDesc, setBreakdownDesc] = useState("");
  const [activeFloor, setActiveFloor] = useState(0); // 0: Zemin, 1: 1. Kat
  const [isMapExpanded, setIsMapExpanded] = useState(false);

  const handleCreateBreakdown = (mach) => {
    alert(mach.ad + " için arıza kaydı başarıyla oluşturuldu!" + (breakdownDesc ? "\nNot: " + breakdownDesc : ""));
    setActiveBreakdownId(null);
    setBreakdownDesc("");
  };

  const getCategoryIcon = (kat) => {
    if (kat.includes("Riskli")) return "⚠️";
    if (kat.includes("Yaklaşan")) return "⏳";
    return "🔧";
  };

  const getCategoryColor = (kat) => {
    if (kat.includes("Riskli")) return "#f39c12"; // Amber/Kehribar
    if (kat.includes("Yaklaşan")) return "#34495e"; // Koyu Lacivert
    return "#7f8c8d"; // Gri
  };

  const renderFloorPlan = (isLarge = false) => (
    <div style={{ width: "100%", height: "100%", padding: isLarge ? "60px 40px" : "40px 10px 10px 10px", boxSizing: "border-box" }}>
      <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "15px" }}>
        <span style={{ fontSize: isLarge ? "24px" : "16px", fontWeight: "bold", color: "#2c3e50" }}>
          🏢 Fabrika Yerleşim Planı - {activeFloor === 0 ? "Zemin Kat" : "1. Kat"}
        </span>
      </div>
      
      <div style={{ 
        display: "grid", 
        gridTemplateColumns: "repeat(3, 1fr)", 
        gridTemplateRows: "repeat(2, 1fr)", 
        gap: isLarge ? "25px" : "15px", 
        height: isLarge ? "70%" : "200px" 
      }}>
        {activeFloor === 0 ? (
          <>
            <div style={{ ...blokStyle, background: "#f8f9fa", borderTop: "4px solid #f39c12", padding: isLarge ? "30px" : "15px" }}>
              <span style={{ ...blokTitleStyle, fontSize: isLarge ? "20px" : "14px" }}>Blok A</span>
              <span style={{ ...blokSubTitleStyle, fontSize: isLarge ? "14px" : "11px" }}>Pres Hattı</span>
            </div>
            <div style={{ ...blokStyle, background: "#f8f9fa", borderTop: "4px solid #3498db", padding: isLarge ? "30px" : "15px" }}>
              <span style={{ ...blokTitleStyle, fontSize: isLarge ? "20px" : "14px" }}>Blok B</span>
              <span style={{ ...blokSubTitleStyle, fontSize: isLarge ? "14px" : "11px" }}>Lazer Kesim</span>
            </div>
            <div style={{ ...blokStyle, background: "#f8f9fa", borderTop: "4px solid #2ecc71", padding: isLarge ? "30px" : "15px" }}>
              <span style={{ ...blokTitleStyle, fontSize: isLarge ? "20px" : "14px" }}>Blok C</span>
              <span style={{ ...blokSubTitleStyle, fontSize: isLarge ? "14px" : "11px" }}>Lojistik & Ambar</span>
            </div>
            <div style={{ ...blokStyle, gridColumn: "span 3", background: "#f1f2f6", border: "1px dashed #ccc", padding: isLarge ? "30px" : "15px" }}>
              <span style={{ ...blokTitleStyle, fontSize: isLarge ? "20px" : "14px" }}>Sevkiyat Alanı</span>
            </div>
          </>
        ) : (
          <>
            <div style={{ ...blokStyle, gridColumn: "span 2", background: "#f8f9fa", borderTop: "4px solid #9b59b6", padding: isLarge ? "30px" : "15px" }}>
              <span style={{ ...blokTitleStyle, fontSize: isLarge ? "20px" : "14px" }}>Blok D</span>
              <span style={{ ...blokSubTitleStyle, fontSize: isLarge ? "14px" : "11px" }}>Montaj Hattı</span>
            </div>
            <div style={{ ...blokStyle, background: "#f8f9fa", borderTop: "4px solid #e74c3c", padding: isLarge ? "30px" : "15px" }}>
              <span style={{ ...blokTitleStyle, fontSize: isLarge ? "20px" : "14px" }}>Blok E</span>
              <span style={{ ...blokSubTitleStyle, fontSize: isLarge ? "14px" : "11px" }}>Bakım & Teknik</span>
            </div>
            <div style={{ ...blokStyle, gridColumn: "span 1", background: "#fdfdfd", padding: isLarge ? "30px" : "15px" }}>
                <span style={{ ...blokTitleStyle, fontSize: isLarge ? "20px" : "14px" }}>Ofisler</span>
            </div>
            <div style={{ ...blokStyle, gridColumn: "span 2", background: "#f8f9fa", borderTop: "4px solid #1abc9c", padding: isLarge ? "30px" : "15px" }}>
                <span style={{ ...blokTitleStyle, fontSize: isLarge ? "20px" : "14px" }}>Blok F</span>
                <span style={{ ...blokSubTitleStyle, fontSize: isLarge ? "14px" : "11px" }}>Kalite Kontrol</span>
            </div>
          </>
        )}
      </div>
    </div>
  );

  return (
    <div style={{ display: "flex", background: "#f5f6fa", minHeight: "100vh" }}>
      {/* SOL MENÜ */}
      <Sidebar />

      {/* SAĞ TARAF (Navbar + İçerik) */}
      <div style={{ flex: 1, display: "flex", flexDirection: "column", height: "100vh", overflow: "hidden" }}>
        {/* ÜST NAVBAR */}
        <Navbar />

        {/* ANA İÇERİK YÜZEYİ */}
        <div style={{ padding: "30px", flex: 1, overflowY: "auto", display: "flex", flexDirection: "column", gap: "25px" }}>

          {/* KPI KUTULARI (DİNAMİK + SADE BAŞLIKLAR) */}
          <div style={{ display: "flex", gap: "20px", width: "100%", flex: "0 0 150px" }}>
            <div
              style={{ ...kpiBox, flexDirection: "column", alignItems: "flex-start", cursor: "pointer", transition: "all 0.2s", borderLeft: "5px solid #f39c12" }}
              onClick={() => setIsAlertModalOpen(true)}
              onMouseOver={(e) => { e.currentTarget.style.transform = "scale(1.02)"; }}
              onMouseOut={(e) => { e.currentTarget.style.transform = "scale(1)"; }}
            >
              <div style={{ fontWeight: "bold", fontSize: "16px", marginBottom: "12px", borderBottom: "2px solid #f1f2f6", paddingBottom: "8px", width: "100%", textAlign: "left", color: "#2c3e50" }}>
                🎯 Günlük Kritik Uyarılar
              </div>
              <div style={{ fontSize: "14px", fontWeight: "600", color: "#34495e", display: "flex", flexDirection: "column", gap: "8px", width: "100%" }}>
                <div style={{ display: "flex", justifyContent: "space-between" }}>
                  <span>⚠️ Yüksek Riskli:</span>
                  <strong style={{ color: "#f39c12", fontSize: "16px" }}>{yRCount}</strong>
                </div>
                <div style={{ display: "flex", justifyContent: "space-between" }}>
                  <span>⏳ Bakımı Yaklaşan:</span>
                  <strong style={{ color: "#34495e", fontSize: "16px" }}>{bYCount}</strong>
                </div>
                <div style={{ display: "flex", justifyContent: "space-between" }}>
                  <span>🔧 Bakımda Olan:</span>
                  <strong style={{ color: "#7f8c8d", fontSize: "16px" }}>{bOCount}</strong>
                </div>
              </div>
            </div>
            <div style={kpiBox}>Bekleyen Bakım Onayları</div>
            <div style={kpiBox}>Genel OEE Skoru</div>
          </div>

          {/* ALT ALAN (Geniş Kaplama) */}
          <div style={{ display: "flex", gap: "20px", width: "100%", flex: 1 }}>
            {/* FABRİKA HARİTASI (Dinamik) */}
            <div 
              onClick={() => setIsMapExpanded(true)}
              style={{ ...mapBox, position: "relative", padding: "20px", cursor: "zoom-in", transition: "transform 0.2s" }}
              onMouseOver={(e) => e.currentTarget.style.transform = "scale(1.01)"}
              onMouseOut={(e) => e.currentTarget.style.transform = "scale(1)"}
            >
              <div style={{ position: "absolute", top: "15px", right: "15px", display: "flex", gap: "10px", zIndex: 10 }} onClick={(e) => e.stopPropagation()}>
                <button 
                  onClick={() => setActiveFloor(0)} 
                  style={{ ...floorBtnStyle, background: activeFloor === 0 ? "#34495e" : "#f1f2f6", color: activeFloor === 0 ? "white" : "#333" }}
                >
                  Zemin Kat
                </button>
                <button 
                  onClick={() => setActiveFloor(1)} 
                  style={{ ...floorBtnStyle, background: activeFloor === 1 ? "#34495e" : "#f1f2f6", color: activeFloor === 1 ? "white" : "#333" }}
                >
                  1. Kat
                </button>
              </div>
              {renderFloorPlan(false)}
            </div>
            <div style={costBox}>
              Makine Alım & Bakım Masraf Oranı
            </div>
          </div>

          {/* TAM EKRAN HARİTA MODAL */}
          {isMapExpanded && (
            <div style={modalOverlayStyle} onClick={() => setIsMapExpanded(false)}>
              <div style={{ ...modalContentStyle, maxWidth: "90%", width: "1200px", height: "80vh", position: "relative" }} onClick={(e) => e.stopPropagation()}>
                <button onClick={() => setIsMapExpanded(false)} style={{ ...closeBtnStyle, position: "absolute", top: "20px", right: "20px", fontSize: "30px" }}>✕</button>
                
                <div style={{ position: "absolute", top: "25px", right: "80px", display: "flex", gap: "10px", zIndex: 10 }}>
                  <button 
                    onClick={() => setActiveFloor(0)} 
                    style={{ ...floorBtnStyle, padding: "10px 20px", background: activeFloor === 0 ? "#34495e" : "#f1f2f6", color: activeFloor === 0 ? "white" : "#333" }}
                  >
                    Zemin Kat
                  </button>
                  <button 
                    onClick={() => setActiveFloor(1)} 
                    style={{ ...floorBtnStyle, padding: "10px 20px", background: activeFloor === 1 ? "#34495e" : "#f1f2f6", color: activeFloor === 1 ? "white" : "#333" }}
                  >
                    1. Kat
                  </button>
                </div>

                {renderFloorPlan(true)}

                <div style={{ position: "absolute", bottom: "20px", left: "40px", color: "#7f8c8d", fontSize: "14px italic" }}>
                   * Blokların üzerine tıklayarak o bölgenin detaylarını ileride görebilirsiniz.
                </div>
              </div>
            </div>
          )}

          {/* ONAYLAR VE ARZA LİSTESİ MODALUI (POP-UP) */}
          {isAlertModalOpen && (
            <div style={modalOverlayStyle}>
              <div style={modalContentStyle}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "20px", borderBottom: "1px solid #eee", paddingBottom: "15px" }}>
                  <h3 style={{ margin: 0, color: "#0f3460", fontSize: "20px" }}>Riskli Makineler Tablosu</h3>
                  <button onClick={() => { setIsAlertModalOpen(false); setActiveBreakdownId(null); }} style={closeBtnStyle}>✕</button>
                </div>

                <div style={{ maxHeight: "60vh", overflowY: "auto", display: "flex", flexDirection: "column", gap: "10px", paddingRight: "10px" }}>
                  {machinesList
                    .sort((a, b) => {
                      const priority = { "Yüksek Riskli": 3, "Bakımı Yaklaşan": 2, "Bakımda Olan": 1 };
                      return (priority[b.kategori] || 0) - (priority[a.kategori] || 0);
                    })
                    .map(m => (
                    <div key={m.id} style={{ padding: "20px", background: "white", borderRadius: "8px", border: "1px solid #e1e5eb", borderLeft: `6px solid ${getCategoryColor(m.kategori)}` }}>
                      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                        <div>
                          <strong style={{ fontSize: "18px", color: "#2c3e50" }}>{m.ad}</strong>
                          <div style={{ fontSize: "14px", marginTop: "8px", fontWeight: "bold", color: getCategoryColor(m.kategori) }}>
                            {getCategoryIcon(m.kategori)} {m.kategori}
                          </div>
                        </div>
                        <div style={{ display: "flex", gap: "10px" }}>
                          <button
                            onClick={() => navigate(`/makine/${m.id}`)}
                            style={{ ...btnStyle, background: "#34495e" }}
                          >
                            🔍 Detay Gör
                          </button>
                          <button
                            onClick={() => setActiveBreakdownId(activeBreakdownId === m.id ? null : m.id)}
                            style={btnStyle}
                          >
                            {activeBreakdownId === m.id ? "Gizle" : "Arıza Kaydı"}
                          </button>
                        </div>
                      </div>

                      {/* ARIZA KAYDI FORMU */}
                      {activeBreakdownId === m.id && (
                        <div style={{ marginTop: "20px", padding: "20px", background: "white", borderRadius: "8px", border: "2px solid #e1e5eb" }}>
                          <div style={{ marginBottom: "12px", fontWeight: "bold", fontSize: "16px", color: "#333" }}>Detaylı Arıza Açıklaması:</div>
                          <textarea
                            value={breakdownDesc}
                            onChange={(e) => setBreakdownDesc(e.target.value)}
                            placeholder="Açıklama..."
                            style={{ width: "100%", padding: "15px", boxSizing: "border-box", borderRadius: "6px", border: "1px solid #ccc", outline: "none", minHeight: "100px", marginBottom: "15px", fontSize: "15px", resize: "vertical" }}
                          />
                          <div style={{ display: "flex", justifyContent: "flex-end" }}>
                            <button onClick={() => handleCreateBreakdown(m)} style={saveBtnStyle}>Kaydet ve Bildir</button>
                          </div>
                        </div>
                      )}
                    </div>
                  ))}
                </div>

              </div>
            </div>
          )}

        </div>
      </div>
    </div>
  );
}

/* STILLER */
const kpiBox = {
  flex: 1,
  background: "white",
  padding: "20px",
  textAlign: "center",
  borderRadius: "12px",
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  boxSizing: "border-box",
  boxShadow: "0 4px 15px rgba(0,0,0,0.05)",
  fontSize: "20px",
  fontWeight: "bold",
  color: "#34495e",
  border: "2px solid transparent"
};

const modalOverlayStyle = { position: "absolute", top: 0, left: 0, right: 0, bottom: 0, background: "rgba(0,0,0,0.6)", display: "flex", justifyContent: "center", alignItems: "flex-start", paddingTop: "50px", zIndex: 100, backdropFilter: "blur(4px)" };
const modalContentStyle = { background: "white", padding: "30px", borderRadius: "12px", width: "100%", maxWidth: "600px", boxShadow: "0 10px 40px rgba(0,0,0,0.2)" };
const closeBtnStyle = { background: "transparent", border: "none", fontSize: "20px", cursor: "pointer", color: "#999" };
const btnStyle = { padding: "10px 15px", background: "#e94560", color: "white", border: "none", borderRadius: "6px", cursor: "pointer", fontWeight: "bold", fontSize: "13px", transition: "0.2s" };
const saveBtnStyle = { padding: "10px 20px", background: "#2ecc71", color: "white", border: "none", borderRadius: "6px", cursor: "pointer", fontWeight: "bold" };

const mapBox = {
  flex: 2,
  background: "white",
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  borderRadius: "12px",
  fontWeight: "bold",
  boxSizing: "border-box",
  boxShadow: "0 4px 15px rgba(0,0,0,0.05)",
  fontSize: "24px",
  color: "#34495e"
};

const costBox = {
  flex: 1,
  background: "white",
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  borderRadius: "12px",
  fontWeight: "bold",
  textAlign: "center",
  padding: "20px",
  boxSizing: "border-box",
  boxShadow: "0 4px 15px rgba(0,0,0,0.05)",
  fontSize: "24px",
  color: "#34495e"
};

const floorBtnStyle = {
  padding: "6px 12px",
  borderRadius: "6px",
  border: "none",
  fontSize: "12px",
  fontWeight: "bold",
  cursor: "pointer",
  transition: "0.2s"
};

const blokStyle = {
  borderRadius: "8px",
  padding: "15px",
  display: "flex",
  flexDirection: "column",
  justifyContent: "center",
  alignItems: "center",
  boxShadow: "0 2px 8px rgba(0,0,0,0.04)",
  transition: "0.2s"
};

const blokTitleStyle = {
  fontSize: "14px",
  fontWeight: "bold",
  color: "#2c3e50"
};

const blokSubTitleStyle = {
  fontSize: "11px",
  color: "#7f8c8d",
  marginTop: "4px",
  textTransform: "uppercase"
};
