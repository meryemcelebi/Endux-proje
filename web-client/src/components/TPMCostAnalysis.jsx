import React, { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip, Legend } from "recharts";

export default function TPMCostAnalysis({ data }) {
  const navigate = useNavigate();
  const [selectedCostId, setSelectedCostId] = useState("all");

  const {
    planli_bakim = 0,
    arizi_bakim = 0,
    parca_gideri = 0,
    dis_servis = 0,
  } = data || {};

  const formatCurrency = (val) => {
    return new Intl.NumberFormat("tr-TR", {
      style: "currency",
      currency: "TRY",
      maximumFractionDigits: 0,
    }).format(val || 0);
  };

  const costItems = useMemo(() => ([
    {
      id: "planned",
      name: "Periyodik Bakım",
      title: "Periyodik Bakım Maliyetleri",
      value: Number(planli_bakim || 0),
      color: "#2ecc71",
      description: "Planlı ve önleyici bakım kayıtlarından oluşan maliyetler.",
    },
    {
      id: "unplanned",
      name: "Arızi Bakım",
      title: "Arızi Bakım Maliyetleri",
      value: Number(arizi_bakim || 0),
      color: "#e74c3c",
      description: "Plansız arıza müdahalelerinden oluşan bakım maliyetleri.",
    },
    {
      id: "external",
      name: "Dış Servis",
      title: "Dış Servis Maliyetleri",
      value: Number(dis_servis || 0),
      color: "#9b59b6",
      description: "Dış servis veya taşeron desteğiyle oluşan maliyetler.",
    },
    {
      id: "parts",
      name: "Yedek Parça",
      title: "Yedek Parça Maliyetleri",
      value: Number(parca_gideri || 0),
      color: "#e67e22",
      description: "Bakım sırasında değişen parça ve sarf maliyetleri.",
    },
  ]), [planli_bakim, arizi_bakim, dis_servis, parca_gideri]);

  const chartData = costItems.filter((item) => item.value > 0);
  const totalCost = costItems.reduce((sum, item) => sum + item.value, 0);
  const visibleItems = selectedCostId === "all"
    ? costItems
    : costItems.filter((item) => item.id === selectedCostId);

  const handleSliceClick = (entry) => {
    setSelectedCostId(entry.id);
  };

  const openDetail = () => {
    const query = selectedCostId === "all" ? "" : `?kategori=${selectedCostId}`;
    navigate(`/maliyet-detay${query}`);
  };

  return (
    <div style={containerStyle}>
      <div style={headerStyle}>
        <div>
          <h2 style={titleStyle}>MALİYET ANALİZİ</h2>
          <p style={subTitleStyle}>Bakım, servis ve parça maliyet dağılımı</p>
        </div>
        <div style={totalBadgeStyle}>
          <span style={totalLabelStyle}>TOPLAM MALİYET</span>
          <span style={totalValueStyle}>{formatCurrency(totalCost)}</span>
        </div>
      </div>

      <div style={mainContentStyle}>
        <div style={chartSectionStyle}>
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={chartData}
                innerRadius={78}
                outerRadius={108}
                paddingAngle={5}
                dataKey="value"
                onClick={handleSliceClick}
                cursor="pointer"
              >
                {chartData.map((entry) => (
                  <Cell
                    key={entry.id}
                    fill={entry.color}
                    opacity={selectedCostId === "all" || selectedCostId === entry.id ? 1 : 0.35}
                  />
                ))}
              </Pie>
              <Tooltip formatter={(value) => formatCurrency(value)} />
              <Legend verticalAlign="bottom" height={36} />
            </PieChart>
          </ResponsiveContainer>

          <div style={filterBarStyle}>
            <button
              type="button"
              onClick={() => setSelectedCostId("all")}
              style={selectedCostId === "all" ? activeFilterButtonStyle : filterButtonStyle}
            >
              Tümü
            </button>
            <button type="button" onClick={openDetail} style={detailButtonStyle}>
              Detaylı Analiz
            </button>
          </div>
        </div>

        <div style={itemsGridStyle}>
          {visibleItems.map((item) => {
            const share = totalCost > 0 ? ((item.value / totalCost) * 100).toFixed(1) : "0.0";
            return (
              <button
                type="button"
                key={item.id}
                onClick={() => setSelectedCostId(item.id)}
                style={{ ...miniCardStyle, borderLeftColor: item.color }}
              >
                <div style={cardHeaderStyle}>
                  <span style={miniTitleStyle}>{item.title}</span>
                  <span style={{ ...shareBadgeStyle, color: item.color }}>%{share}</span>
                </div>
                <div style={{ ...miniValueStyle, color: item.color }}>{formatCurrency(item.value)}</div>
                <div style={miniDescriptionStyle}>{item.description}</div>
              </button>
            );
          })}
        </div>
      </div>

      <div style={footerNoteStyle}>
        Pasta grafiğinde bir maliyet kalemine tıklayınca panel yalnızca o veriyi gösterir.
      </div>
    </div>
  );
}

const containerStyle = {
  background: "#fff",
  padding: "25px",
  borderRadius: "12px",
  boxShadow: "0 10px 25px rgba(0,0,0,0.03)",
  fontFamily: "'Inter', sans-serif",
  display: "flex",
  flexDirection: "column",
  height: "100%",
  boxSizing: "border-box",
};

const headerStyle = {
  display: "flex",
  justifyContent: "space-between",
  alignItems: "center",
  borderBottom: "1px solid #f1f5f9",
  paddingBottom: "15px",
  gap: "18px",
};

const titleStyle = { margin: 0, fontSize: "20px", fontWeight: "900", color: "#1e293b" };
const subTitleStyle = { margin: "4px 0 0 0", fontSize: "12px", color: "#64748b", fontWeight: "700", textTransform: "uppercase" };
const totalBadgeStyle = { background: "linear-gradient(135deg, #1e293b 0%, #334155 100%)", padding: "10px 20px", borderRadius: "8px", display: "flex", flexDirection: "column", alignItems: "flex-end" };
const totalLabelStyle = { fontSize: "9px", color: "#94a3b8", fontWeight: "800" };
const totalValueStyle = { fontSize: "22px", color: "#fff", fontWeight: "900" };
const mainContentStyle = { display: "grid", gridTemplateColumns: "minmax(260px, 1fr) minmax(260px, 0.9fr)", gap: "22px", alignItems: "center" };
const chartSectionStyle = { display: "flex", flexDirection: "column", alignItems: "center", position: "relative" };
const filterBarStyle = { display: "flex", alignItems: "center", gap: "10px", marginTop: "10px" };
const filterButtonStyle = { border: "1px solid #cbd5e1", background: "#fff", color: "#475569", borderRadius: "8px", padding: "9px 13px", fontSize: "12px", fontWeight: "800", cursor: "pointer" };
const activeFilterButtonStyle = { ...filterButtonStyle, background: "#1e293b", color: "#fff", borderColor: "#1e293b" };
const detailButtonStyle = { ...filterButtonStyle, background: "#3498db", borderColor: "#3498db", color: "#fff" };
const itemsGridStyle = { display: "grid", gridTemplateColumns: "1fr", gap: "10px" };
const miniCardStyle = { padding: "13px", borderRadius: "8px", background: "#f8fafc", border: "1px solid #f1f5f9", borderLeft: "4px solid", display: "flex", flexDirection: "column", gap: "6px", textAlign: "left", cursor: "pointer" };
const cardHeaderStyle = { display: "flex", alignItems: "center", justifyContent: "space-between", gap: "8px" };
const miniTitleStyle = { fontSize: "12px", fontWeight: "900", color: "#475569" };
const miniValueStyle = { fontSize: "18px", fontWeight: "900" };
const miniDescriptionStyle = { fontSize: "11px", fontWeight: "600", color: "#64748b", lineHeight: 1.35 };
const shareBadgeStyle = { fontSize: "11px", fontWeight: "900", background: "#fff", border: "1px solid #e2e8f0", borderRadius: "999px", padding: "3px 8px" };
const footerNoteStyle = { marginTop: "12px", fontSize: "10px", color: "#94a3b8", textAlign: "center" };
