import React, { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { AreaChart, Area, ResponsiveContainer, Tooltip } from "recharts";

/**
 * TPM Maliyet Analizi Bileşeni (Yeniden Tasarım)
 * Tüm veriler veritabanından gelir — mock veri yok.
 * - Kompakt başlık + toplam tutar
 * - Stacked Progress Bar (yatay çubuk)
 * - Minimalist 4 satırlık dağılım listesi
 * - 3 aylık gerçek trend grafiği (sparkline area chart)
 */
export default function TPMCostAnalysis({ data }) {
  const navigate = useNavigate();

  // Ay seçici dropdown için son 6 ayın listesini oluştur
  const months = useMemo(() => {
    const list = [];
    const now = new Date();
    for (let i = 0; i < 6; i++) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const label = d.toLocaleDateString("tr-TR", { month: "long", year: "numeric" });
      list.push({
        label: label.charAt(0).toUpperCase() + label.slice(1),
        value: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`,
      });
    }
    return list;
  }, []);
  const [selectedMonth, setSelectedMonth] = useState(months[0]?.value || "");

  const {
    planli_bakim = 0,
    arizi_bakim = 0,
    parca_gideri = 0,
    dis_servis = 0,
    durus_maliyeti = 0,
    aylik_trend = [],
  } = data || {};

  const formatCurrency = (val) => {
    return new Intl.NumberFormat("tr-TR", {
      style: "currency",
      currency: "TRY",
      maximumFractionDigits: 0,
    }).format(val || 0);
  };

  const costItems = useMemo(
    () => [
      {
        id: "planned",
        name: "Planlı Bakım",
        value: Number(planli_bakim || 0),
        color: "#22c55e",
      },
      {
        id: "unplanned",
        name: "Arıza Bakım",
        value: Number(arizi_bakim || 0),
        color: "#ef4444",
      },
      {
        id: "external",
        name: "Dış Servis",
        value: Number(dis_servis || 0),
        color: "#8b5cf6",
      },
      {
        id: "parts",
        name: "Yedek Parça",
        value: Number(parca_gideri || 0),
        color: "#f97316",
      },
      {
        id: "downtime",
        name: "Duruş Maliyeti",
        value: Number(durus_maliyeti || 0),
        color: "#06b6d4",
      },
    ],
    [planli_bakim, arizi_bakim, dis_servis, parca_gideri, durus_maliyeti]
  );

  const totalCost = costItems.reduce((sum, item) => sum + item.value, 0);

  // Backend'den gelen gerçek 6 aylık trend verisini grafik formatına dönüştür
  const trendData = useMemo(() => {
    if (!aylik_trend || aylik_trend.length === 0) {
      return [];
    }
    return aylik_trend.map((row) => {
      const date = new Date(row.ay);
      const ayLabel = date.toLocaleDateString("tr-TR", { month: "short", year: "2-digit" });
      return {
        ay: ayLabel.charAt(0).toUpperCase() + ayLabel.slice(1),
        maliyet: Number(row.toplam || 0),
      };
    });
  }, [aylik_trend]);



  return (
    <div style={containerStyle}>
      {/* --- 1. BAŞLIK + AY SEÇİCİ + TOPLAM TUTAR --- */}
      <div style={headerStyle}>
        <span style={titleStyle}>MALİYET ANALİZİ</span>
        <select
          value={selectedMonth}
          onChange={(e) => setSelectedMonth(e.target.value)}
          style={dropdownStyle}
        >
          {months.map((m) => (
            <option key={m.value} value={m.value}>
              {m.label}
            </option>
          ))}
        </select>
      </div>

      <div
        style={totalStyle}
        onClick={() => navigate("/maliyet-detay")}
        title="Detaylı analize git"
      >
        {formatCurrency(totalCost)}
      </div>

      {/* --- 2. STACKED PROGRESS BAR --- */}
      <div style={stackedBarContainer}>
        {costItems.map((item) => {
          const pct = totalCost > 0 ? (item.value / totalCost) * 100 : 25;
          if (pct < 0.5) return null;
          return (
            <div
              key={item.id}
              style={{
                ...stackedSegment,
                width: `${pct}%`,
                backgroundColor: item.color,
              }}
              title={`${item.name}: ${formatCurrency(item.value)} (%${pct.toFixed(1)})`}
            />
          );
        })}
      </div>

      {/* --- 3. MİNİMALİST VERİ LİSTESİ --- */}
      <div style={listContainer}>
        {costItems.map((item) => {
          const pct =
            totalCost > 0 ? ((item.value / totalCost) * 100).toFixed(1) : "0.0";
          return (
            <div
              key={item.id}
              style={listRow}
              onClick={() => navigate(`/maliyet-detay?kategori=${item.id}`)}
              onMouseOver={(e) => {
                e.currentTarget.style.background = "#f8fafc";
                e.currentTarget.style.transform = "translateX(3px)";
              }}
              onMouseOut={(e) => {
                e.currentTarget.style.background = "transparent";
                e.currentTarget.style.transform = "translateX(0)";
              }}
            >
              <div style={listLeft}>
                <span
                  style={{
                    ...colorDot,
                    backgroundColor: item.color,
                  }}
                />
                <span style={listLabel}>{item.name}</span>
              </div>
              <div style={listRight}>
                <span style={listValue}>{formatCurrency(item.value)}</span>
                <span style={{ ...listPct, color: item.color }}>%{pct}</span>
              </div>
            </div>
          );
        })}
      </div>

      {/* --- 4. 3 AYLIK GERÇEK TREND GRAFİĞİ --- */}
      <div style={trendContainer}>
        <span style={trendTitle}>6 Aylık Bakım Trendi</span>
        <div style={{ width: "100%", height: 80 }}>
          {trendData.length > 0 ? (
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={trendData} margin={{ top: 5, right: 5, left: 5, bottom: 0 }}>
                <defs>
                  <linearGradient id="tpmCostGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#3b82f6" stopOpacity={0.3} />
                    <stop offset="100%" stopColor="#3b82f6" stopOpacity={0.02} />
                  </linearGradient>
                </defs>
                <Tooltip
                  formatter={(value) => [formatCurrency(value), "Maliyet"]}
                  contentStyle={{
                    background: "#1e293b",
                    border: "none",
                    borderRadius: "8px",
                    color: "#fff",
                    fontSize: "11px",
                    fontWeight: "700",
                    padding: "6px 10px",
                  }}
                  labelStyle={{ color: "#94a3b8", fontSize: "10px" }}
                  itemStyle={{ color: "#fff" }}
                />
                <Area
                  type="monotone"
                  dataKey="maliyet"
                  stroke="#3b82f6"
                  strokeWidth={2}
                  fill="url(#tpmCostGradient)"
                  dot={{ r: 3, fill: "#3b82f6", stroke: "#fff", strokeWidth: 2 }}
                  activeDot={{ r: 5, fill: "#3b82f6", stroke: "#fff", strokeWidth: 2 }}
                />
              </AreaChart>
            </ResponsiveContainer>
          ) : (
            <div style={{ display: "flex", alignItems: "center", justifyContent: "center", height: "100%", color: "#94a3b8", fontSize: "11px", fontWeight: "700" }}>
              Henüz trend verisi yok
            </div>
          )}
        </div>
      </div>

      {/* Detaylı Analiz Butonu */}
      <button
        type="button"
        onClick={() => navigate("/maliyet-detay")}
        style={detailBtnStyle}
        onMouseOver={(e) => {
          e.currentTarget.style.background = "#1e293b";
          e.currentTarget.style.color = "#fff";
        }}
        onMouseOut={(e) => {
          e.currentTarget.style.background = "#f1f5f9";
          e.currentTarget.style.color = "#334155";
        }}
      >
        Detaylı Analiz →
      </button>
    </div>
  );
}

// --- STYLE TANIMLARI ---

const containerStyle = {
  background: "#fff",
  padding: "20px",
  borderRadius: "16px",
  boxShadow: "0 4px 20px rgba(0,0,0,0.04)",
  fontFamily: "'Inter', sans-serif",
  display: "flex",
  flexDirection: "column",
  height: "100%",
  boxSizing: "border-box",
  gap: "14px",
};

const headerStyle = {
  display: "flex",
  justifyContent: "space-between",
  alignItems: "center",
};

const titleStyle = {
  fontSize: "13px",
  fontWeight: "900",
  color: "#1e293b",
  letterSpacing: "1.5px",
  textTransform: "uppercase",
};

const dropdownStyle = {
  fontSize: "11px",
  fontWeight: "700",
  color: "#475569",
  background: "#f8fafc",
  border: "1px solid #e2e8f0",
  borderRadius: "8px",
  padding: "5px 10px",
  cursor: "pointer",
  outline: "none",
};

const totalStyle = {
  fontSize: "28px",
  fontWeight: "950",
  color: "#0f172a",
  letterSpacing: "-0.5px",
  lineHeight: 1,
  cursor: "pointer",
  transition: "color 0.2s",
};

const stackedBarContainer = {
  display: "flex",
  width: "100%",
  height: "10px",
  borderRadius: "999px",
  overflow: "hidden",
  background: "#f1f5f9",
};

const stackedSegment = {
  height: "100%",
  transition: "width 0.6s cubic-bezier(0.4, 0, 0.2, 1)",
};

const listContainer = {
  display: "flex",
  flexDirection: "column",
  gap: "2px",
};

const listRow = {
  display: "flex",
  justifyContent: "space-between",
  alignItems: "center",
  padding: "7px 6px",
  borderRadius: "8px",
  cursor: "pointer",
  transition: "all 0.2s ease",
};

const listLeft = {
  display: "flex",
  alignItems: "center",
  gap: "10px",
};

const colorDot = {
  width: "10px",
  height: "10px",
  borderRadius: "50%",
  flexShrink: 0,
};

const listLabel = {
  fontSize: "12px",
  fontWeight: "700",
  color: "#334155",
};

const listRight = {
  display: "flex",
  alignItems: "center",
  gap: "12px",
};

const listValue = {
  fontSize: "13px",
  fontWeight: "800",
  color: "#0f172a",
};

const listPct = {
  fontSize: "11px",
  fontWeight: "800",
  background: "#f8fafc",
  border: "1px solid #e2e8f0",
  borderRadius: "999px",
  padding: "2px 8px",
  minWidth: "42px",
  textAlign: "center",
};

const trendContainer = {
  display: "flex",
  flexDirection: "column",
  gap: "6px",
  marginTop: "2px",
};

const trendTitle = {
  fontSize: "10px",
  fontWeight: "800",
  color: "#94a3b8",
  textTransform: "uppercase",
  letterSpacing: "1px",
};

const detailBtnStyle = {
  width: "100%",
  padding: "10px",
  fontSize: "12px",
  fontWeight: "800",
  color: "#334155",
  background: "#f1f5f9",
  border: "1px solid #e2e8f0",
  borderRadius: "10px",
  cursor: "pointer",
  transition: "all 0.25s ease",
  textAlign: "center",
  marginTop: "auto",
};
