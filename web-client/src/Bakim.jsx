import React, { useState, useEffect } from "react";
import Sidebar from "./Sidebar";
import Navbar from "./Navbar";
import { api } from "./services/api";

/**
 * Bakım Yönetimi Sayfası
 * Makinelerin bakım durumlarını, maliyetlerini ve yaklaşan bakımları takip eder.
 */
export default function Bakim() {
  const [loading, setLoading] = useState(true);
  const [machines, setMachines] = useState([]);
  const [history, setHistory] = useState([]);
  const [isCostModalOpen, setIsCostModalOpen] = useState(false);

  // --- VERİ ÇEKME ---
  useEffect(() => {
    const fetchData = async () => {
      try {
        const [mList, hList] = await Promise.all([
          api.getMachines(),
          api.getAllServiceHistory()
        ]);
        setMachines(mList);
        setHistory(hList);
      } catch (error) {
        console.error("Bakım verileri çekilirken hata:", error);
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, []);

  // --- HESAPLAMALAR ---

  // 1. Planlı Bakımlar (Risk skoru 50-80 arası olanlar yaklaşıyor kabul edilir)
  const planliBakimlar = machines.filter(m => m.mevcut_risk_skoru >= 50 && m.mevcut_risk_skoru < 80);

  // 2. Şu an aktif olarak bakımda olanlar
  const bakimdakiMakineler = machines.filter(m => m.aktiflik_durumu === "Bakımda");

  // 3. Bu ayki toplam maliyet
  const currentMonth = new Date().getMonth();
  const currentYear = new Date().getFullYear();
  const thisMonthMaliyet = history
    .filter(h => {
      const d = new Date(h.bakim_tarihi);
      return d.getMonth() === currentMonth && d.getFullYear() === currentYear;
    })
    .reduce((sum, h) => sum + (Number(h.bakim_maliyet) || 0), 0);

  // 4. Makine Bazlı Maliyet Tablosu (Aggregated)
  const maliyetOzet = machines.map(m => {
    const mHistory = history.filter(h => h.makine_id === m.makine_id);
    const totalCost = mHistory.reduce((sum, h) => sum + (Number(h.bakim_maliyet) || 0), 0);
    const lastMaint = mHistory.length > 0
      ? new Date(Math.max(...mHistory.map(h => new Date(h.bakim_tarihi)))).toLocaleDateString("tr-TR")
      : "Yok";
    return {
      makine: m.makine_adi || m.ad,
      toplamMaliyet: totalCost,
      sonBakim: lastMaint
    };
  }).filter(item => item.toplamMaliyet > 0).sort((a, b) => b.toplamMaliyet - a.toplamMaliyet);

  // 5. Yaklaşan Bakımlar (Risk skoru en yüksek olan ilk 5)
  const yaklasanBakimTablosu = machines
    .filter(m => m.aktiflik_durumu !== "Pasif" && m.aktiflik_durumu !== "Bakımda" && m.mevcut_risk_skoru >= 50)
    .sort((a, b) => b.mevcut_risk_skoru - a.mevcut_risk_skoru)
    .slice(0, 5);

  // 6. Son 3 ayın maliyet verileri (Grafik için)
  const last3Months = [];
  for (let i = 2; i >= 0; i--) {
    const targetDate = new Date();
    targetDate.setMonth(targetDate.getMonth() - i);
    const m = targetDate.getMonth();
    const y = targetDate.getFullYear();
    const monthName = targetDate.toLocaleString("tr-TR", { month: "short" });

    const cost = history
      .filter(h => {
        const d = new Date(h.bakim_tarihi);
        return d.getMonth() === m && d.getFullYear() === y;
      })
      .reduce((sum, h) => sum + (Number(h.bakim_maliyet) || 0), 0);

    last3Months.push({ name: monthName, cost });
  }

  const maxCost = Math.max(...last3Months.map(d => d.cost), 1000);

  // Yeni bakım kaydı formu için state (Şu an bu sayfada render edilmiyor, Servis.jsx'de kullanılıyor)
  const [form, setForm] = useState({
    makineId: "",
    kullaniciId: "", // İşlemi yapan personel
    firmaId: "", // Servis firması
    bakimTuru: "", // Periyodik, Acil vb.
    maliyet: "", // İşlem bedeli
    aciklama: "" // Teknik detaylar
  });

  // Form alanlarındaki değişiklikleri yakalar
  const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

  // Yeni bakım ekleme fonksiyonu
  const addBakim = () => {
    if (!form.makineId) return alert("Alanları doldurun.");
    alert("Bakım başarıyla eklendi!");
    setForm({ makineId: "", kullaniciId: "", firmaId: "", bakimTuru: "", maliyet: "", aciklama: "" });
  };

  return (
    <div style={{ display: "flex", background: "#f5f6fa", minHeight: "100vh" }}>
      <Sidebar />

      <div style={{ flex: 1, display: "flex", flexDirection: "column", height: "100vh", overflow: "hidden" }}>
        <Navbar />

        <div style={{ padding: "25px", flex: 1, overflowY: "auto" }}>

          {/* --- ÜST ALAN (Yaklaşan Bakımlar ve Özet) --- */}
          {loading ? (
            <div style={{ textAlign: "center", padding: "50px", color: "#666" }}>Veriler Yükleniyor...</div>
          ) : (
            <div style={{ display: "flex", gap: "25px", alignItems: "stretch" }}>
              {/* --- YAKLAŞAN / PLANLANAN BAKIMLAR --- */}
              <div style={{ ...cardStyle, flex: 2, display: "flex", flexDirection: "column" }}>
                <h3 style={cardTitle}>Sistem Tarafından Öngörülen Yaklaşan Bakımlar</h3>
                <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))", gap: "12px", flex: 1 }}>
                  {yaklasanBakimTablosu.length > 0 ? yaklasanBakimTablosu.map((m) => (
                    <div key={m.id} style={{ ...listItemStyle, display: "flex", flexDirection: "column", justifyContent: "space-between" }}>
                      <div>
                        <div style={{ fontWeight: "bold", color: "#2c3e50", fontSize: "14px" }}>{m.makine_adi || m.ad}</div>
                        <div style={{ color: "#7f8c8d", fontSize: "12px", marginTop: "4px" }}>
                          Risk Skoru: <span style={{ color: "#e74c3c", fontWeight: "bold" }}>{m.mevcut_risk_skoru}</span>
                        </div>
                      </div>
                      <div style={{ fontSize: "10px", background: "#f39c12", color: "white", padding: "2px 6px", borderRadius: "4px", display: "inline-block", marginTop: "8px", width: "fit-content" }}>
                        Öncelikli Bakım Gerekli
                      </div>
                    </div>
                  )) : (
                    <div style={{ ...listItemStyle, textAlign: "center", color: "#999", gridColumn: "1 / -1", display: "flex", alignItems: "center", justifyContent: "center" }}>
                      Yakın zamanda planlanan bakım bulunmuyor.
                    </div>
                  )}
                </div>
              </div>

              {/* --- MALİYET ÖZETİ --- */}
              <div
                style={{ ...kpiBox, flex: 1, display: "flex", flexDirection: "column", justifyContent: "center", cursor: "pointer", transition: "all 0.2s" }}
                onClick={() => setIsCostModalOpen(true)}
                onMouseOver={(e) => { e.currentTarget.style.transform = "scale(1.02)"; e.currentTarget.style.boxShadow = "0 8px 16px rgba(0, 0, 0, 0.1)"; }}
                onMouseOut={(e) => { e.currentTarget.style.transform = "scale(1)"; e.currentTarget.style.boxShadow = "0 2px 10px rgba(0,0,0,0.05)"; }}
              >
                <span style={kpiTitle}>Aylık Bakım Maliyeti</span>
                <span style={{ fontSize: "42px", color: "#27ae60", fontWeight: "bold", margin: "10px 0" }}>₺{thisMonthMaliyet.toLocaleString()}</span>
                <p style={{ color: "#7f8c8d", fontSize: "13px", textAlign: "center", maxWidth: "200px" }}>Geçmiş maliyet analizini görmek için tıklayın.</p>
              </div>
            </div>
          )}

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
                  {maliyetOzet.length > 0 ? maliyetOzet.map((m, i) => (
                    <tr key={i} style={{ borderBottom: "1px solid #eee" }}>
                      <td style={tdStyle}>{m.makine}</td>
                      <td style={tdStyle}>{m.sonBakim}</td>
                      <td style={{ ...tdStyle, fontWeight: "bold", color: "navy" }}>₺{m.toplamMaliyet.toLocaleString()}</td>
                    </tr>
                  )) : (
                    <tr>
                      <td colSpan="3" style={{ ...tdStyle, textAlign: "center", color: "#999" }}>Kayıtlı maliyet verisi bulunamadı.</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>


          </div>

          {/* --- MALİYET ANALİZ MODAL (Son 3 Ay Grafiği) --- */}
          {isCostModalOpen && (
            <div style={modalOverlayStyle}>
              <div style={modalContentStyle}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "30px", borderBottom: "1px solid #eee", paddingBottom: "15px" }}>
                  <div>
                    <h3 style={{ margin: 0, color: "#0f3460", fontSize: "20px" }}>Bakım Maliyeti Analizi</h3>
                  </div>
                  <button onClick={() => setIsCostModalOpen(false)} style={closeBtnStyle}>✕</button>
                </div>

                {/* Sütun Grafik Alanı */}
                <div style={{ display: "flex", justifyContent: "space-around", alignItems: "flex-end", height: "250px", padding: "20px", background: "#f8fafc", borderRadius: "12px", border: "1px solid #e2e8f0" }}>
                  {last3Months.map((data, idx) => {
                    const barHeight = (data.cost / maxCost) * 200;
                    return (
                      <div key={idx} style={{ display: "flex", flexDirection: "column", alignItems: "center", width: "80px", gap: "10px" }}>
                        <div style={{ fontSize: "12px", fontWeight: "bold", color: "#27ae60" }}>₺{data.cost.toLocaleString()}</div>
                        <div style={{
                          width: "45px",
                          height: `${barHeight}px`,
                          background: idx === 2 ? "linear-gradient(to top, #27ae60, #2ecc71)" : "#cbd5e0",
                          borderRadius: "6px 6px 0 0",
                          transition: "height 0.5s ease-out",
                          boxShadow: idx === 2 ? "0 4px 10px rgba(39, 174, 96, 0.3)" : "none"
                        }}></div>
                        <div style={{ fontSize: "13px", fontWeight: "800", color: "#1e293b", textTransform: "capitalize" }}>{data.name}</div>
                      </div>
                    );
                  })}
                </div>



                <div style={{ display: "flex", justifyContent: "flex-end", marginTop: "25px" }}>
                  <button onClick={() => setIsCostModalOpen(false)} style={{ ...saveBtnStyle, background: "#1e293b" }}>Kapat</button>
                </div>
              </div>
            </div>
          )}
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

const modalOverlayStyle = { position: "fixed", top: 0, left: 0, right: 0, bottom: 0, background: "rgba(0,0,0,0.5)", display: "flex", justifyContent: "center", alignItems: "center", zIndex: 1000, backdropFilter: "blur(4px)" };
const modalContentStyle = { background: "white", padding: "30px", borderRadius: "16px", width: "90%", maxWidth: "500px", boxShadow: "0 20px 50px rgba(0,0,0,0.2)" };
const closeBtnStyle = { background: "transparent", border: "none", fontSize: "20px", cursor: "pointer", color: "#999" };
const saveBtnStyle = { padding: "12px 24px", background: "#27ae60", color: "white", border: "none", borderRadius: "8px", fontWeight: "bold", cursor: "pointer" };
