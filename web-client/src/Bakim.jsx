import React, { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import Sidebar from "./Sidebar";
import Navbar from "./Navbar";
import { api } from "./services/api";

export default function Bakim() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [machines, setMachines] = useState([]);
  const [history, setHistory] = useState([]);
  const [isCostModalOpen, setIsCostModalOpen] = useState(false);
  const [currentDate, setCurrentDate] = useState(new Date());

  // --- VERİ ÇEKME ---
  useEffect(() => {
    const fetchData = async () => {
      try {
        const [mList, hList] = await Promise.all([
          api.getMachines(),
          api.getAllServiceHistory()
        ]);
        setMachines(mList || []);
        setHistory(hList || []);
      } catch (error) {
        console.error("Bakım verileri çekilirken hata:", error);
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, []);

  // --- HESAPLAMALAR ---

  // 2. Şu an aktif olarak bakımda olanlar
  const bakimdakiMakineler = machines.filter(m => m.aktiflik_durumu === "Bakımda");

  // 3. Bu ayki toplam maliyet
  const currentMonth = new Date().getMonth();
  const currentYear = new Date().getFullYear();
  const thisMonthMaliyet = history
    .filter(h => {
      if (!h.bakim_tarihi) return false;
      const d = new Date(h.bakim_tarihi);
      return d.getMonth() === currentMonth && d.getFullYear() === currentYear;
    })
    .reduce((sum, h) => sum + (Number(h.bakim_maliyet) || 0), 0);

  // 4. Makine Bazlı Maliyet Tablosu (Aggregated)
  const maliyetOzet = machines.map(m => {
    const mHistory = history.filter(h => h.makine_id === m.makine_id);
    const totalCost = mHistory.reduce((sum, h) => sum + (Number(h.bakim_maliyet) || 0), 0);
    const validDates = mHistory.map(h => new Date(h.bakim_tarihi).getTime()).filter(t => !isNaN(t));
    const lastMaint = validDates.length > 0
      ? new Date(Math.max(...validDates)).toLocaleDateString("tr-TR")
      : "Yok";
    return {
      id: m.makine_id,
      makine: m.makine_adi || m.ad || `Makine ${m.makine_id}`,
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
        if (!h.bakim_tarihi) return false;
        const d = new Date(h.bakim_tarihi);
        return d.getMonth() === m && d.getFullYear() === y;
      })
      .reduce((sum, h) => sum + (Number(h.bakim_maliyet) || 0), 0);

    last3Months.push({ name: monthName, cost });
  }

  const maxCost = Math.max(...last3Months.map(d => d.cost), 1000);

  // --- MAKİNE SAYAÇLARI HESAPLAMA ---
  const machineCounters = machines.map(m => {
    const periyodik = m.makine_turu?.periyodik_bakim_saati || 500;
    const calisan = Number(m.toplam_calisma_saati) || 0;
    const kalan = periyodik - (calisan % periyodik);
    const progress = Math.min(((periyodik - kalan) / periyodik) * 100, 100);
    return {
      ...m,
      name: m.makine_adi || m.ad || `Makine ${m.makine_id}`,
      kalan,
      periyodik,
      progress,
      isKritik: kalan < 50
    };
  }).sort((a, b) => a.kalan - b.kalan);

  // --- TAKVİM HESAPLAMA ---
  const daysInMonth = new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 0).getDate();
  const firstDayIndex = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1).getDay();
  const adjustedFirstDay = firstDayIndex === 0 ? 6 : firstDayIndex - 1;

  const days = [];
  for (let i = 0; i < adjustedFirstDay; i++) days.push(null);
  for (let i = 1; i <= daysInMonth; i++) days.push(i);

  const getDayEvents = (day) => {
    if (!day) return [];

    // O güne ait bakım kayıtlarını filtrele
    const dayEvents = history.filter(h => {
      if (!h.bakim_tarihi) return false;
      const d = new Date(h.bakim_tarihi);
      return (
        d.getDate() === day &&
        d.getMonth() === currentDate.getMonth() &&
        d.getFullYear() === currentDate.getFullYear()
      );
    });

    return dayEvents.map(ev => {
      // ariza_id varsa ARIZA, yoksa PLANLI kabul ediyoruz (veya bakim_tur_id'ye göre)
      const isAriza = ev.ariza_id || (ev.aciklama && ev.aciklama.toLowerCase().includes("arıza"));
      return {
        ...ev,
        type: isAriza ? "ARIZA" : "PLANLI",
        text: ev.makine_ad || "Makine",
        id: ev.bakim_id
      };
    });
  };

  const monthNames = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];

  return (
    <div className="app-container" style={{ display: "flex", background: "#f5f6fa", minHeight: "100vh" }}>
      <Sidebar />

      <div className="app-content-wrapper" style={{ flex: 1, display: "flex", flexDirection: "column", height: "100vh", overflow: "hidden" }}>
        <Navbar />

        <div style={{ padding: "15px 20px", flex: 1, overflowY: "auto" }}>

          {loading ? (
            <div style={{ textAlign: "center", padding: "50px", color: "#666" }}>Veriler Yükleniyor...</div>
          ) : (
            <div style={{ display: "flex", flexDirection: "column", gap: "15px" }}>

              {/* --- ÜST ALAN (Eski Veriler) --- */}
              <div style={{ display: "flex", gap: "15px", alignItems: "stretch", flexWrap: "wrap" }}>

                {/* YAKLAŞAN / PLANLANAN BAKIMLAR */}
                <div style={{ ...cardStyle, flex: 2, display: "flex", flexDirection: "column", minWidth: "300px", padding: "10px 15px" }}>
                  <h3 style={{ ...cardTitle, fontSize: "14px", marginBottom: "8px", paddingBottom: "5px" }}>Sistem Tarafından Öngörülen Yaklaşan Bakımlar</h3>
                  <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(150px, 1fr))", gap: "8px", flex: 1 }}>
                    {yaklasanBakimTablosu.length > 0 ? yaklasanBakimTablosu.map((m, i) => (
                      <div key={i} onClick={() => navigate(`/makine/${m.makine_id}`)} style={{ ...listItemStyle, padding: "8px", display: "flex", flexDirection: "column", justifyContent: "space-between", cursor: "pointer" }}>
                        <div>
                          <div style={{ fontWeight: "bold", color: "#2c3e50", fontSize: "12px" }}>{m.makine_adi || m.ad || `Makine ${m.makine_id}`}</div>
                          <div style={{ color: "#7f8c8d", fontSize: "10px", marginTop: "2px" }}>
                            Risk Skoru: <span style={{ color: "#e74c3c", fontWeight: "bold" }}>{m.mevcut_risk_skoru}</span>
                          </div>
                        </div>
                      </div>
                    )) : (
                      <div style={{ ...listItemStyle, padding: "8px", textAlign: "center", color: "#999", gridColumn: "1 / -1", display: "flex", alignItems: "center", justifyContent: "center", fontSize: "12px" }}>
                        Yakın zamanda planlanan bakım bulunmuyor.
                      </div>
                    )}
                  </div>
                </div>

                {/* MALİYET ÖZETİ */}
                <div
                  style={{ ...kpiBox, flex: 1, minWidth: "200px", padding: "10px 15px", cursor: "pointer", transition: "all 0.2s" }}
                  onClick={() => setIsCostModalOpen(true)}
                  onMouseOver={(e) => { e.currentTarget.style.transform = "scale(1.02)"; e.currentTarget.style.boxShadow = "0 8px 16px rgba(0, 0, 0, 0.1)"; }}
                  onMouseOut={(e) => { e.currentTarget.style.transform = "scale(1)"; e.currentTarget.style.boxShadow = "0 2px 10px rgba(0,0,0,0.05)"; }}
                >
                  <span style={{ ...kpiTitle, fontSize: "11px", marginBottom: "2px" }}>Aylık Bakım Maliyeti</span>
                  <span style={{ fontSize: "24px", color: "#27ae60", fontWeight: "bold", margin: "2px 0" }}>₺{thisMonthMaliyet.toLocaleString()}</span>
                  <p style={{ color: "#7f8c8d", fontSize: "10px", textAlign: "center", maxWidth: "180px", margin: 0 }}>Geçmiş maliyet analizini görmek için tıklayın.</p>
                </div>

              </div>

              {/* --- ORTA ALAN (Takvim ve Sayaçlar) --- */}
              <div style={{ display: "grid", gridTemplateColumns: "1.5fr 1fr", gap: "15px" }}>

                {/* TAKVİM */}
                <div style={{ ...cardStyle, padding: "15px" }}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "10px", borderBottom: "1px solid #eee", paddingBottom: "8px" }}>
                    <h3 style={{ margin: 0, fontSize: "15px", color: "#0f3460", fontWeight: "600" }}>Makine Bakım & Arıza Takvimi</h3>
                    <div style={{ display: "flex", gap: "10px", alignItems: "center" }}>
                      <span style={{ fontSize: "14px", color: "#2c3e50", fontWeight: "bold" }}>{monthNames[currentDate.getMonth()]} {currentDate.getFullYear()}</span>
                      <div style={{ display: "flex", gap: "5px" }}>
                        <button style={{ ...calBtnStyle, height: "24px", width: "24px", fontSize: "12px" }} onClick={() => setCurrentDate(new Date(currentDate.getFullYear(), currentDate.getMonth() - 1, 1))}>{"<"}</button>
                        <button style={{ ...calBtnStyle, height: "24px", width: "24px", fontSize: "12px" }} onClick={() => setCurrentDate(new Date())}>{"•"}</button>
                        <button style={{ ...calBtnStyle, height: "24px", width: "24px", fontSize: "12px" }} onClick={() => setCurrentDate(new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 1))}>{">"}</button>
                      </div>
                    </div>
                  </div>

                  <div style={{ display: "grid", gridTemplateColumns: "repeat(7, 1fr)", gap: "4px", marginBottom: "5px" }}>
                    {["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"].map(d => (
                      <div key={d} style={{ textAlign: "center", color: "#7f8c8d", fontSize: "11px", fontWeight: "bold", paddingBottom: "4px", borderBottom: "2px solid #eee" }}>{d}</div>
                    ))}
                  </div>

                  <div style={{ display: "grid", gridTemplateColumns: "repeat(7, 1fr)", gap: "4px" }}>
                    {days.map((day, idx) => {
                      const events = getDayEvents(day);
                      return (
                        <div key={idx} style={{
                          minHeight: "40px",
                          background: day ? "#f8f9fa" : "transparent",
                          borderRadius: "4px",
                          padding: "2px 4px",
                          border: day ? "1px solid #e1e5eb" : "none",
                          transition: "all 0.2s",
                          cursor: day ? "pointer" : "default"
                        }}
                          onMouseOver={(e) => { if (day) e.currentTarget.style.background = "#fff"; e.currentTarget.style.boxShadow = "0 2px 8px rgba(0,0,0,0.05)" }}
                          onMouseOut={(e) => { if (day) { e.currentTarget.style.background = "#f8f9fa"; e.currentTarget.style.boxShadow = "none" } }}
                        >
                          <div style={{ fontSize: "10px", color: "#2c3e50", fontWeight: "bold", marginBottom: "1px" }}>{day || ""}</div>
                          <div style={{ display: "flex", flexDirection: "column", gap: "2px" }}>
                            {events.map((ev, i) => (
                              <div key={i} onClick={() => navigate(`/makine/${ev.makine_id}`)} style={{
                                fontSize: "8px",
                                background: ev.type === "PLANLI" ? "#3498db" : "#e74c3c",
                                color: "#fff",
                                padding: "2px 3px",
                                borderRadius: "2px",
                                display: "block",
                                fontWeight: "bold",
                                wordBreak: "break-word",
                                lineHeight: "1.1",
                                textAlign: "center",
                                cursor: "pointer"
                              }}>
                                {ev.type === "PLANLI" ? "⏱" : "⚡"} {ev.text}
                              </div>
                            ))}
                          </div>
                        </div>
                      )
                    })}
                  </div>

                  <div style={{ display: "flex", gap: "20px", marginTop: "12px", paddingTop: "12px", borderTop: "1px solid #eee" }}>
                    <div style={{ display: "flex", alignItems: "center", fontSize: "12px", color: "#2c3e50", fontWeight: "bold" }}>
                      <div style={{ width: "12px", height: "12px", borderRadius: "50%", background: "#3498db", marginRight: "6px" }}></div> PLANLI
                    </div>
                    <div style={{ display: "flex", alignItems: "center", fontSize: "12px", color: "#2c3e50", fontWeight: "bold" }}>
                      <div style={{ width: "12px", height: "12px", borderRadius: "50%", background: "#e74c3c", marginRight: "6px" }}></div> ARIZA
                    </div>
                  </div>
                </div>

                {/* SAYAÇLAR */}
                <div style={{ ...cardStyle, display: "flex", flexDirection: "column", padding: "15px" }}>
                  <h3 style={{ ...cardTitle, fontSize: "15px", marginBottom: "10px", paddingBottom: "8px" }}>Çalışma Saati Sayaçları</h3>
                  <div style={{ display: "flex", flexDirection: "column", gap: "15px", flex: 1 }}>
                    {machineCounters.slice(0, 5).map((m, i) => (
                      <div key={i} onClick={() => navigate(`/makine/${m.makine_id}`)} style={{ display: "flex", flexDirection: "column", gap: "6px", cursor: "pointer" }}>
                        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "2px" }}>
                          <span style={{ fontSize: "13px", color: "#2c3e50", fontWeight: "500" }}>{m.name}</span>
                          <span style={{ fontSize: "13px", color: m.isKritik ? "#e74c3c" : "#f39c12", fontWeight: "bold" }}>{m.kalan} Saat Kaldı</span>
                        </div>
                        <div style={{ width: "100%", height: "12px", background: "#ecf0f1", borderRadius: "6px", overflow: "hidden" }}>
                          <div style={{
                            width: `${m.progress}%`,
                            height: "100%",
                            background: m.isKritik ? "linear-gradient(90deg, #f39c12 0%, #e74c3c 100%)" : "linear-gradient(90deg, #2ecc71 0%, #f1c40f 100%)",
                            borderRadius: "5px",
                            transition: "width 1s ease-in-out"
                          }}></div>
                        </div>
                      </div>
                    ))}
                    {machineCounters.length === 0 && (
                      <div style={{ textAlign: "center", color: "#999", padding: "20px" }}>Makine sayacı bulunmuyor.</div>
                    )}
                  </div>
                </div>

              </div>

              {/* --- ALT ALAN (Maliyet Tablosu) --- */}
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
                      <tr key={i} onClick={() => navigate(`/makine/${m.id}`)} style={{ borderBottom: "1px solid #eee", cursor: "pointer" }}>
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
          )}

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
                  <button onClick={() => setIsCostModalOpen(false)} style={saveBtnStyle}>Kapat</button>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// --- GÖRSEL STİLLER ---
const kpiBox = { background: "white", padding: "20px", borderRadius: "10px", boxShadow: "0 2px 10px rgba(0,0,0,0.05)", display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "center" };
const kpiTitle = { color: "#7f8c8d", fontSize: "13px", fontWeight: "bold", textTransform: "uppercase", marginBottom: "8px", letterSpacing: "0.5px" };

const cardStyle = { background: "white", padding: "25px", borderRadius: "10px", boxShadow: "0 2px 10px rgba(0,0,0,0.05)" };
const cardTitle = { margin: "0 0 20px 0", color: "#0f3460", fontSize: "18px", borderBottom: "1px solid #eee", paddingBottom: "12px" };

const tableStyle = { width: "100%", borderCollapse: "collapse" };
const thStyle = { textAlign: "left", padding: "12px", background: "#f8f9fa", color: "#2c3e50", fontWeight: "bold", fontSize: "14px", borderBottom: "2px solid #ddd" };
const tdStyle = { padding: "12px", fontSize: "14px", color: "#555" };

const listItemStyle = { background: "#f8f9fa", padding: "15px", borderRadius: "8px", borderLeft: "4px solid #3498db", transition: "transform 0.2s" };

const calBtnStyle = {
  background: "#f1f2f6",
  color: "#2c3e50",
  border: "1px solid #dcdde1",
  borderRadius: "6px",
  width: "30px",
  height: "30px",
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  cursor: "pointer",
  fontWeight: "bold",
  transition: "all 0.2s"
};

const modalOverlayStyle = { position: "fixed", top: 0, left: 0, right: 0, bottom: 0, background: "rgba(0,0,0,0.5)", display: "flex", justifyContent: "center", alignItems: "center", zIndex: 1000, backdropFilter: "blur(4px)" };
const modalContentStyle = { background: "white", padding: "30px", borderRadius: "16px", width: "90%", maxWidth: "500px", boxShadow: "0 20px 50px rgba(0,0,0,0.2)" };
const closeBtnStyle = { background: "transparent", border: "none", fontSize: "20px", cursor: "pointer", color: "#999" };
const saveBtnStyle = { padding: "12px 24px", background: "#1e293b", color: "white", border: "none", borderRadius: "8px", fontWeight: "bold", cursor: "pointer" };
