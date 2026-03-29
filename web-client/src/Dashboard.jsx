import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import Sidebar from "./Sidebar";
import Navbar from "./Navbar";

export default function Dashboard() {
  const navigate = useNavigate();

  const [machinesList] = useState([
    { id: 1, ad: "Press Makinesi A", kategori: "🔴 Yüksek Riskli Makine" },
    { id: 2, ad: "CNC Lazer Kesim", kategori: "🔴 Yüksek Riskli Makine" },
    { id: 3, ad: "Paketleme Robotu B", kategori: "🔵 Bakımı Yaklaşan" },
    { id: 4, ad: "Enjeksiyon Makinesi", kategori: "🔵 Bakımı Yaklaşan" },
    { id: 5, ad: "Taşıma Bandı", kategori: "🔵 Bakımı Yaklaşan" },
    { id: 6, ad: "Torna Makinesi 3", kategori: "🟢 Bakımda Olan" },
  ]);

  const yRCount = machinesList.filter(m => m.kategori.includes("Yüksek Riskli")).length;
  const bYCount = machinesList.filter(m => m.kategori.includes("Bakımı Yaklaşan")).length;
  const bOCount = machinesList.filter(m => m.kategori.includes("Bakımda Olan")).length;

  const [isAlertModalOpen, setIsAlertModalOpen] = useState(false);
  const [activeBreakdownId, setActiveBreakdownId] = useState(null);
  const [breakdownDesc, setBreakdownDesc] = useState("");

  const handleCreateBreakdown = (mach) => {
    if (!breakdownDesc) return alert("Lütfen arıza açıklamasını yazın!");
    alert(mach.ad + " için arıza kaydı başarıyla oluşturuldu!\nNot: " + breakdownDesc);
    setActiveBreakdownId(null);
    setBreakdownDesc("");
  };

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
              style={{ ...kpiBox, flexDirection: "column", alignItems: "flex-start", cursor: "pointer", transition: "all 0.2s" }}
              onClick={() => setIsAlertModalOpen(true)}
              onMouseOver={(e) => { e.currentTarget.style.transform = "scale(1.02)"; e.currentTarget.style.borderColor = "#e94560"; }}
              onMouseOut={(e) => { e.currentTarget.style.transform = "scale(1)"; e.currentTarget.style.borderColor = "transparent"; }}
            >
              <div style={{ fontWeight: "bold", fontSize: "16px", marginBottom: "12px", borderBottom: "2px solid #f1f2f6", paddingBottom: "8px", width: "100%", textAlign: "left", color: "#c0392b" }}>
                Günlük Kritik Uyarılar
              </div>
              <div style={{ fontSize: "14px", fontWeight: "600", color: "#34495e", display: "flex", flexDirection: "column", gap: "8px", width: "100%" }}>
                <div style={{ display: "flex", justifyContent: "space-between" }}>
                  <span>🔴 Yüksek Riskli Makine:</span>
                  <strong style={{ color: "#e74c3c", fontSize: "16px" }}>{yRCount}</strong>
                </div>
                <div style={{ display: "flex", justifyContent: "space-between" }}>
                  <span>🔵 Bakımı Yaklaşan:</span>
                  <strong style={{ color: "#3498db", fontSize: "16px" }}>{bYCount}</strong>
                </div>
                <div style={{ display: "flex", justifyContent: "space-between" }}>
                  <span>🟢 Bakımda Olan:</span>
                  <strong style={{ color: "#2ecc71", fontSize: "16px" }}>{bOCount}</strong>
                </div>
              </div>
            </div>
            <div style={kpiBox}>Bekleyen Bakım Onayları</div>
            <div style={kpiBox}>Genel OEE Skoru</div>
          </div>

          {/* ALT ALAN (Geniş Kaplama) */}
          <div style={{ display: "flex", gap: "20px", width: "100%", flex: 1 }}>
            <div style={mapBox}>
              Fabrika Haritası
            </div>
            <div style={costBox}>
              Makine Alım & Bakım Masraf Oranı
            </div>
          </div>

          {/* ONAYLAR VE ARZA LİSTESİ MODALUI (POP-UP) */}
          {isAlertModalOpen && (
            <div style={modalOverlayStyle}>
              <div style={modalContentStyle}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "20px", borderBottom: "1px solid #eee", paddingBottom: "15px" }}>
                  <h3 style={{ margin: 0, color: "#0f3460", fontSize: "20px" }}>Riskli Makineler Tablosu</h3>
                  <button onClick={() => { setIsAlertModalOpen(false); setActiveBreakdownId(null); }} style={closeBtnStyle}>✕</button>
                </div>

                <div style={{ maxHeight: "60vh", overflowY: "auto", display: "flex", flexDirection: "column", gap: "10px", paddingRight: "10px" }}>
                  {machinesList.map(m => (
                    <div key={m.id} style={{ padding: "20px", background: "#f8f9fa", borderRadius: "8px", border: "1px solid #dcdde1" }}>
                      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                        <div>
                          <strong style={{ fontSize: "18px", color: "#2c3e50" }}>{m.ad}</strong>
                          <div style={{ fontSize: "15px", marginTop: "8px", fontWeight: "bold", color: "#34495e" }}>{m.kategori}</div>
                        </div>
                        <button
                          onClick={() => setActiveBreakdownId(activeBreakdownId === m.id ? null : m.id)}
                          style={btnStyle}
                        >
                          {activeBreakdownId === m.id ? "Gizle" : "Arıza Kaydı Oluştur"}
                        </button>
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
