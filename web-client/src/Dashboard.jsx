import { useNavigate } from "react-router-dom";
import Sidebar from "./Sidebar";
import Navbar from "./Navbar";

export default function Dashboard() {
  const navigate = useNavigate();

  return (
    <div style={{ height: "100vh", display: "flex", flexDirection: "column", overflow: "hidden" }}>
      {/* ÜST NAVBAR */}
      <Navbar />

      <div style={{ display: "flex", flex: 1, overflow: "hidden" }}>

        {/* SOL MENÜ */}
        <Sidebar />

        {/* ANA İÇERİK */}
        <div style={{
          flex: 1,
          padding: "20px",
          boxSizing: "border-box",
          display: "flex",
          flexDirection: "column",
          gap: "20px",
          overflow: "auto"
        }}>

          {/* KPI KUTULARI */}
          <div style={{ display: "flex", gap: "20px", width: "100%", minHeight: "120px" }}>
            <div style={kpiBox}>Günlük Kritik Uyarılar</div>
            <div style={kpiBox}>Bekleyen Bakım Onayları</div>
            <div style={kpiBox}>Genel OEE Skoru</div>
          </div>

          {/* ALT ALAN */}
          <div style={{ display: "flex", gap: "20px", width: "100%", flex: 1, minHeight: "300px" }}>

            {/* HARİTA */}
            <div style={mapBox}>
              Buraya Fabrika Haritası Gelecek
            </div>

            {/* MASRAF */}
            <div style={costBox}>
              Makine Alım & Bakım Masraf Oranı
            </div>

          </div>

        </div>
      </div>
    </div>
  );
}

/* STILLER */
const kpiBox = {
  flex: 1,
  background: "lightgray",
  padding: "30px",
  textAlign: "center",
  borderRadius: "8px",  //Köşeleri yuvarlatır
  fontWeight: "bold",   //Yazıyı kalın yapar
  fontSize: "18px",     //Yazı boyutu büyütüldü
  color: "navy",        //Yazı rengi lacivert
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  boxSizing: "border-box"
};

const mapBox = { //harita kutusu
  flex: 2,
  background: "lightgray",
  display: "flex",  //İçindeki elemanları flex sistemiyle hizalar
  alignItems: "center",  //Dikeyde ortalar (yukarı-aşağı)
  justifyContent: "center",  //Yatayda ortalar (sağ-sol)
  borderRadius: "8px",
  fontWeight: "bold",
  boxSizing: "border-box", // Tutarlılık için önemli padding eklenince kutu büyümez
  color: "navy"
};

const costBox = { //masraf kutusu
  flex: 1,
  background: "lightgray",
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  borderRadius: "8px",
  fontWeight: "bold",
  textAlign: "center",
  padding: "10px",
  boxSizing: "border-box",// Padding'in kutuyu büyütmesini engellendi
  color: "navy"
};
