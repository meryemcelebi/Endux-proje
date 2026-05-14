import React, { useState, useEffect } from "react";
import { useSearchParams } from "react-router-dom";
import Sidebar from "./Sidebar";
import Navbar from "./Navbar";
import { api } from "./services/api";

export default function MaliyetDetay() {
  const [searchParams] = useSearchParams();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [selectedCategory, setSelectedCategory] = useState(searchParams.get("kategori") || "all");

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      const res = await api.getDashboardOzet();
      setData(res.maliyet_ozeti);
    } catch (error) {
      console.error("Maliyet verileri çekilemedi:", error);
    } finally {
      setLoading(false);
    }
  };

  const formatCurrency = (val) => {
    return new Intl.NumberFormat("tr-TR", {
      style: "currency",
      currency: "TRY",
      maximumFractionDigits: 0,
    }).format(val || 0);
  };

  if (loading) return <div style={loadingStyle}>Veriler Yükleniyor...</div>;

  const rawMachineData = data?.makine_detaylari || [];
  const partCategoryData = data?.parca_kategori_detaylari || [];

  const costItems = [
    {
      id: "planned",
      title: "Planlı (Önleyici) Bakım",
      value: data?.planli_bakim,
      color: "#2ecc71",
      icon: "📅",
      dataKey: "planli_maliyet"
    },
    {
      id: "unplanned",
      title: "Arızi (Plansız) Bakım",
      value: data?.arizi_bakim,
      color: "#e74c3c",
      icon: "🚨",
      dataKey: "arizi_maliyet"
    },
    {
      id: "parts",
      title: "Yedek Parça Giderleri",
      value: data?.parca_gideri,
      color: "#e67e22",
      icon: "⚙️",
      dataKey: "parca_maliyeti"
    },
    {
      id: "external",
      title: "Dış Servis Ücretleri",
      value: data?.dis_servis,
      color: "#9b59b6",
      icon: "🤝",
      dataKey: "dis_servis_maliyet"
    },
    {
      id: "downtime",
      title: "Duruş (Üretim Kaybı)",
      value: data?.durus_maliyeti,
      color: "#34495e",
      icon: "📉",
      dataKey: "durus_kaybi_maliyeti"
    },
  ];

  // Filtreleme ve Sıralama
  let displayList = [];
  if (selectedCategory === "parts") {
    // Yedek Parça seçildiğinde kategori + lokasyon bazlı liste göster
    displayList = partCategoryData.map(item => ({
      label: item.kategori,
      maliyet: item.maliyet
    })).sort((a, b) => b.maliyet - a.maliyet);
  } else {
    // Diğerleri için makine bazlı liste göster
    const currentKey = selectedCategory === "all" ? null : costItems.find(c => c.id === selectedCategory).dataKey;
    displayList = rawMachineData.map(m => ({
      label: m.makine_adi,
      lokasyon: m.fabrika_alani || "Bilinmiyor",
      maliyet: selectedCategory === "all" 
        ? (m.planli_maliyet + m.arizi_maliyet + m.parca_maliyeti + m.dis_servis_maliyet + m.durus_kaybi_maliyeti)
        : (m[currentKey] || 0)
    }))
    .filter(m => m.maliyet > 0)
    .sort((a, b) => b.maliyet - a.maliyet);
  }

  const activeCategory = costItems.find(c => c.id === selectedCategory);
  const isPartsSelected = selectedCategory === "parts";

  return (
    <div style={containerStyle}>
      <Sidebar />
      <div style={mainStyle}>
        <Navbar title="Stratejik Maliyet Analizi Detayı" />
        
        <div style={contentLayout}>
          {/* SOL TARAF: Maliyet Kalemleri Sidebar */}
          <div style={leftSidebarStyle}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <h3 style={sidebarTitleStyle}>Maliyet Kalemleri</h3>
                {selectedCategory !== "all" && (
                    <button onClick={() => setSelectedCategory("all")} style={resetButtonStyle}>Tümünü Gör</button>
                )}
            </div>
            <div style={costCardsGrid}>
              {costItems.map((item) => (
                <div 
                    key={item.id} 
                    onClick={() => setSelectedCategory(item.id)}
                    style={{ 
                        ...miniCardStyle, 
                        borderLeftColor: item.color,
                        opacity: selectedCategory === "all" || selectedCategory === item.id ? 1 : 0.5,
                        transform: selectedCategory === item.id ? 'scale(1.02)' : 'scale(1)',
                        cursor: 'pointer'
                    }}
                >
                  <div style={cardHeaderStyle}>
                    <span style={{ fontSize: "18px" }}>{item.icon}</span>
                    <span style={miniTitleStyle}>{item.title}</span>
                  </div>
                  <div style={{ ...miniValueStyle, color: item.color }}>{formatCurrency(item.value)}</div>
                </div>
              ))}
            </div>
            
            <div style={totalTcoBox}>
              <span style={tcoLabel}>TOPLAM SAHİP OLMA MALİYETİ (TCO)</span>
              <span style={tcoValue}>
                {formatCurrency(data?.planli_bakim + data?.arizi_bakim + data?.parca_gideri + data?.dis_servis + data?.durus_maliyeti)}
              </span>
            </div>
          </div>

          {/* SAĞ TARAF: Liste (Grafik kaldırıldı) */}
          <div style={rightContentStyle}>
            {/* Grafik sadece 'Yedek Parça' dışında ve 'Tümü' seçili değilse gösterilsin veya tamamen kaldırılsın */}
            {/* Kullanıcı "bütün grafiksel yapılar kalksın" dediği için burada grafiği kaldırıyoruz */}
            
            <div style={tableContainerStyle}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
                  <h3 style={sectionTitleStyle}>
                    {isPartsSelected ? "Kategori Bazlı Yedek Parça Dağılımı" : "Ekipman Bazlı Analiz Listesi"}
                  </h3>
                  <div style={badgeStyle}>
                    {isPartsSelected ? "Kategori Görünümü" : "Ekipman Görünümü"}
                  </div>
              </div>
              
              <table style={tableStyle}>
                <thead>
                  <tr style={theadStyle}>
                    {!isPartsSelected && <th style={thStyle}>Lokasyon</th>}
                    <th style={thStyle}>{isPartsSelected ? "Parça Kategorisi" : "Makine Adı"}</th>
                    <th style={thStyle}>Maliyet Etkisi</th>
                    <th style={thStyle}>Pay %</th>
                  </tr>
                </thead>
                <tbody>
                  {displayList.map((item, idx) => {
                    const totalTco = (data?.planli_bakim + data?.arizi_bakim + data?.parca_gideri + data?.dis_servis + data?.durus_maliyeti) || 1;
                    const share = ((item.maliyet / totalTco) * 100).toFixed(1);
                    
                    return (
                      <tr key={idx} style={trStyle}>
                        {!isPartsSelected && (
                          <td style={{ ...tdStyle, color: '#64748b', fontWeight: 'bold' }}>{item.lokasyon}</td>
                        )}
                        <td style={{ ...tdStyle, fontWeight: '700' }}>{item.label}</td>
                        <td style={{ ...tdStyle, color: selectedCategory === "all" ? '#1e293b' : activeCategory.color, fontWeight: '800' }}>
                          {formatCurrency(item.maliyet)}
                        </td>
                        <td style={tdStyle}>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                                <div style={{ flex: 1, height: '6px', background: '#f1f5f9', borderRadius: '3px', overflow: 'hidden', minWidth: '100px' }}>
                                    <div style={{ width: `${share}%`, height: '100%', background: selectedCategory === "all" ? '#3498db' : activeCategory.color }} />
                                </div>
                                <span style={{ fontSize: '12px', fontWeight: 'bold', width: '45px' }}>%{share}</span>
                            </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>

              {displayList.length === 0 && (
                <div style={{ padding: '40px', textAlign: 'center', color: '#64748b' }}>
                    Bu kategori için henüz kayıtlı bir maliyet verisi bulunamadı.
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// --- STYLES ---
const containerStyle = { display: "flex", minHeight: "100vh", background: "#f8fafc" };
const mainStyle = { flex: 1, display: "flex", flexDirection: "column" };
const contentLayout = { display: "flex", padding: "25px", gap: "25px", flex: 1 };

const leftSidebarStyle = { width: "260px", display: "flex", flexDirection: "column", gap: "15px" };
const sidebarTitleStyle = { margin: 0, fontSize: "16px", fontWeight: "900", color: "#1e293b", textTransform: "uppercase" };
const costCardsGrid = { display: "flex", flexDirection: "column", gap: "10px" };

const rightContentStyle = { flex: 1, display: "flex", flexDirection: "column", gap: "20px" };

const loadingStyle = { display: "flex", justifyContent: "center", alignItems: "center", height: "100vh", fontSize: "20px", fontWeight: "bold" };

const miniCardStyle = {
  padding: "12px 15px",
  borderRadius: "12px",
  background: "#fff",
  borderLeft: "5px solid",
  display: "flex",
  flexDirection: "column",
  gap: "4px",
  transition: "all 0.2s ease",
  boxShadow: '0 2px 4px rgba(0,0,0,0.02)'
};

const cardHeaderStyle = { display: "flex", alignItems: "center", gap: "8px" };
const miniTitleStyle = { fontSize: "11px", fontWeight: "800", color: "#64748b" };
const miniValueStyle = { fontSize: "18px", fontWeight: "900" };

const totalTcoBox = {
  marginTop: "auto",
  background: "linear-gradient(135deg, #1e293b 0%, #334155 100%)",
  padding: "20px",
  borderRadius: "16px",
  color: "#fff",
  display: "flex",
  flexDirection: "column",
  gap: "5px",
  boxShadow: "0 10px 20px rgba(0,0,0,0.1)"
};
const tcoLabel = { fontSize: "9px", fontWeight: "800", color: "#94a3b8" };
const tcoValue = { fontSize: "20px", fontWeight: "900" };

const tableContainerStyle = { background: "#fff", padding: "25px", borderRadius: "20px", boxShadow: "0 4px 6px rgba(0,0,0,0.02)" };
const sectionTitleStyle = { margin: 0, fontSize: "17px", fontWeight: "800", color: "#1e293b" };

const tableStyle = { width: "100%", borderCollapse: "collapse" };
const theadStyle = { background: "#f8fafc", textAlign: "left" };
const thStyle = { padding: "15px", fontSize: "12px", color: "#64748b", fontWeight: "800", borderBottom: "2px solid #f1f5f9" };
const trStyle = { borderBottom: "1px solid #f1f5f9" };
const tdStyle = { padding: "15px", fontSize: "13px", color: "#334155" };

const resetButtonStyle = { 
    padding: '4px 8px', 
    fontSize: '11px', 
    fontWeight: 'bold', 
    background: '#f1f5f9', 
    border: 'none', 
    borderRadius: '4px', 
    cursor: 'pointer',
    color: '#64748b'
};

const badgeStyle = {
    padding: '4px 12px',
    background: '#e2e8f0',
    color: '#475569',
    borderRadius: '20px',
    fontSize: '11px',
    fontWeight: 'bold'
};
