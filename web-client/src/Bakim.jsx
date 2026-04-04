import React, { useState } from "react";
import Sidebar from "./Sidebar";
import Navbar from "./Navbar";

/**
 * Bakım Yönetimi Sayfası
 * Makinelerin bakım durumlarını, maliyetlerini ve yaklaşan bakımları takip eder.
 */
export default function Bakim() {
  // --- MOCK VERİLER (API Entegrasyonu Öncesi Temsili Veriler) ---
  
  // Toplam açık arıza sayısı
  const [acikArizaSayisi] = useState(3);
  
  // Şu an aktif olarak bakımda olan makineler
  const [bakimdakiMakineler] = useState([
    { id: 1, ad: "Pres Makinesi - A101", baslangic: "2026-03-25" },
    { id: 2, ad: "CNC Lazer Kesim - L202", baslangic: "2026-03-28" }
  ]);

  // Takvimdeki yaklaşan periyodik veya ağır bakımlar
  const [yaklasanBakimlar] = useState([
    { id: 3, ad: "Enjeksiyon Makinesi - E500", tarih: "2026-04-05", tur: "Periyodik" },
    { id: 4, ad: "Robotik Kol - R10", tarih: "2026-04-10", tur: "Ağır Bakım" }
  ]);

  // Makine bazında yıllık birikmiş maliyet verileri
  const [maliyetler] = useState([
    { makine: "Pres Makinesi - A101", toplamMaliyet: 15000, sonBakim: "2026-02-15" },
    { makine: "CNC Lazer Kesim - L202", toplamMaliyet: 32000, sonBakim: "2026-01-20" },
    { makine: "Enjeksiyon Makinesi - E500", toplamMaliyet: 8500, sonBakim: "2025-11-10" }
  ]);

  // Yeni bakım kaydı formu için state (Şu an bu sayfada render edilmiyor, Servis.jsx'de kullanılıyor)
  const [form, setForm] = useState({
    makineId: "",
    kullaniciId: "",
    firmaId: "",
    bakimTuru: "",
    maliyet: "",
    aciklama: ""
  });

  // Form alanlarındaki değişiklikleri yakalar
  const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

  // Yeni bakım ekleme fonksiyonu (Mock işlem)
  const addBakim = () => {
    if (!form.makineId) return alert("Alanları doldurun.");
    alert("Bakım başarıyla eklendi! (Mock)");
    setForm({ makineId: "", kullaniciId: "", firmaId: "", bakimTuru: "", maliyet: "", aciklama: "" });
  };

  return (
    <div style={{ display: "flex", background: "#f5f6fa", minHeight: "100vh" }}>
      <Sidebar />
      
      <div style={{ flex: 1, display: "flex", flexDirection: "column", height: "100vh", overflow: "hidden" }}>
        <Navbar />
        
        <div style={{ padding: "25px", flex: 1, overflowY: "auto" }}>
          
          {/* --- KPI ALANI (Özet İstatistikler) --- */}
          <div style={kpiContainer}>
            <div style={kpiBox}>
              <span style={kpiTitle}>Açık Arıza Sayısı</span>
              <span style={{ fontSize: "36px", color: "#e94560", fontWeight: "bold" }}>{acikArizaSayisi}</span>
            </div>
            <div style={kpiBox}>
              <span style={kpiTitle}>Bakımdaki Makine</span>
              <span style={{ fontSize: "36px", color: "#f39c12", fontWeight: "bold" }}>{bakimdakiMakineler.length}</span>
            </div>
            <div style={kpiBox}>
              <span style={kpiTitle}>Bu Ay Bakım Maliyeti</span>
              <span style={{ fontSize: "36px", color: "#27ae60", fontWeight: "bold" }}>₺45.000</span>
            </div>
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: "25px", marginTop: "25px" }}>
            
            {/* --- MALİYET ANALİZ TABLOSU --- */}
            <div style={cardStyle}>
              <h3 style={cardTitle}>Makine Bazlı Bakım Maliyetleri</h3>
              <table style={tableStyle}>
                <thead>
                  <tr>
                    <th style={thStyle}>Makine Adı</th>
                    <th style={thStyle}>Son Bakım</th>
                    <th style={thStyle}>Toplam Maliyet (Yıllık)</th>
                  </tr>
                </thead>
                <tbody>
                  {maliyetler.map((m, i) => (
                    <tr key={i} style={{ borderBottom: "1px solid #eee" }}>
                      <td style={tdStyle}>{m.makine}</td>
                      <td style={tdStyle}>{m.sonBakim}</td>
                      <td style={{ ...tdStyle, fontWeight: "bold", color: "navy" }}>₺{m.toplamMaliyet.toLocaleString()}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {/* --- ALT LİSTELER (Yaklaşan ve Mevcut Bakımlar) --- */}
            <div style={{ display: "flex", gap: "25px" }}>
              {/* Yaklaşan Bakımlar Kartı */}
              <div style={{ ...cardStyle, flex: 1 }}>
                <h3 style={cardTitle}>Yaklaşan Bakımlar</h3>
                <div style={{ display: "flex", flexDirection: "column", gap: "10px" }}>
                  {yaklasanBakimlar.map(yb => (
                    <div key={yb.id} style={listItemStyle}>
                      <div><strong style={{ color: "#333"}}>{yb.ad}</strong></div>
                      <div style={{ fontSize: "12px", color: "gray", marginTop: "4px" }}>{yb.tarih} - {yb.tur}</div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Şu An Bakımda Olanlar Kartı */}
              <div style={{ ...cardStyle, flex: 1 }}>
                <h3 style={cardTitle}>Şu An Bakımda</h3>
                <div style={{ display: "flex", flexDirection: "column", gap: "10px" }}>
                  {bakimdakiMakineler.map(bm => (
                    <div key={bm.id} style={{ ...listItemStyle, borderLeftColor: "#f39c12" }}>
                      <div><strong style={{ color: "#333"}}>{bm.ad}</strong></div>
                      <div style={{ fontSize: "12px", color: "gray", marginTop: "4px" }}>Başlama: {bm.baslangic}</div>
                    </div>
                  ))}
                </div>
              </div>
            </div>

          </div>
        </div>
      </div>
    </div>
  );
}

// --- GÖRSEL STİLLER (CSS-in-JS) ---
const kpiContainer = { display: "flex", gap: "25px", flexWrap: "wrap" };
const kpiBox = { flex: 1, minWidth: "200px", background: "white", padding: "20px", borderRadius: "10px", boxShadow: "0 2px 10px rgba(0,0,0,0.05)", display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "center" };
const kpiTitle = { color: "#7f8c8d", fontSize: "13px", fontWeight: "bold", textTransform: "uppercase", marginBottom: "8px", letterSpacing: "0.5px" };

const cardStyle = { background: "white", padding: "25px", borderRadius: "10px", boxShadow: "0 2px 10px rgba(0,0,0,0.05)" };
const cardTitle = { margin: "0 0 20px 0", color: "#0f3460", fontSize: "18px", borderBottom: "1px solid #eee", paddingBottom: "12px" };

const tableStyle = { width: "100%", borderCollapse: "collapse" };
const thStyle = { textAlign: "left", padding: "12px", background: "#f8f9fa", color: "#2c3e50", fontWeight: "bold", fontSize: "14px", borderBottom: "2px solid #ddd" };
const tdStyle = { padding: "12px", fontSize: "14px", color: "#555" };

const listItemStyle = { background: "#f8f9fa", padding: "15px", borderRadius: "8px", borderLeft: "4px solid #3498db", transition: "transform 0.2s" };

const inputStyle = { padding: "14px", border: "1px solid #e1e5eb", borderRadius: "8px", fontSize: "14px", outline: "none", width: "100%", boxSizing: "border-box", background: "#fafafa", color: "#333" };
const buttonStyle = { padding: "14px", background: "#0f3460", color: "white", border: "none", borderRadius: "8px", fontSize: "16px", fontWeight: "bold", cursor: "pointer", transition: "0.2s", marginTop: "10px" };
