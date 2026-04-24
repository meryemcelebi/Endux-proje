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
    .reduce((sum, h) => sum + (h.bakim_maliyet || 0), 0);

  // 4. Makine Bazlı Maliyet Tablosu (Aggregated)
  const maliyetOzet = machines.map(m => {
    const mHistory = history.filter(h => h.makine_id === m.makine_id);
    const totalCost = mHistory.reduce((sum, h) => sum + (h.bakim_maliyet || 0), 0);
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
    .filter(m => m.aktiflik_durumu !== "Pasif" && m.aktiflik_durumu !== "Bakımda" && m.mevcut_risk_skoru > 40)
    .sort((a, b) => b.mevcut_risk_skoru - a.mevcut_risk_skoru)
    .slice(0, 5);

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
              <div style={{ ...kpiBox, flex: 1, display: "flex", flexDirection: "column", justifyContent: "center" }}>
                <span style={kpiTitle}>Aylık Bakım Maliyeti</span>
                <span style={{ fontSize: "42px", color: "#27ae60", fontWeight: "bold", margin: "10px 0" }}>₺{thisMonthMaliyet.toLocaleString()}</span>
                <p style={{ color: "#7f8c8d", fontSize: "13px", textAlign: "center", maxWidth: "200px" }}>Bu ay içerisinde tamamlanan işlemler toplamı.</p>
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
