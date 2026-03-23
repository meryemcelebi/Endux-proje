import { useNavigate } from "react-router-dom";

export default function Dashboard() {
  const navigate = useNavigate();

  return (
    <div style={{ padding: 20 }}>

      {/* ÜST MENÜ */}
      <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 20 }}>
        <h2>Dashboard</h2>

        <button onClick={() => navigate("/makineler")}>
          Makineler
        </button>
      </div>

      {/* ÜST 3 KUTU */}
      <div style={{ display: "flex", gap: 15, marginBottom: 20 }}>
        <div style={boxStyle}>Kritik Uyarılar</div>
        <div style={boxStyle}>Bakım Bekleyenler</div>
        <div style={boxStyle}>OEE</div>
      </div>

      {/* ALT */}
      <div style={{ display: "flex", gap: 15 }}>
        <div style={bigBox}>Fabrika Haritası</div>
        <div style={bigBox}>Masraf Analizi</div>
      </div>

    </div>
  );
}

const boxStyle = {
  flex: 1,
  height: 120,
  background: "#f5f5f5",
  borderRadius: 10,
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  fontWeight: "bold",
  border: "1px solid #ddd",
};

const bigBox = {
  flex: 1,
  height: 280,
  background: "#e9e9e9",
  borderRadius: 10,
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  fontWeight: "bold",
  border: "1px solid #ccc",
};