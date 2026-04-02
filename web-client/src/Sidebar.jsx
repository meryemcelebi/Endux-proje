import React, { useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";

const Sidebar = () => {
  const location = useLocation();
  const currentPath = location.pathname;
  const navigate = useNavigate();
  const [dropdownOpen, setDropdownOpen] = useState(false);

  const kullaniciAdi = "Yönetici";

  const handleCikis = () => {
    localStorage.removeItem("auth_token");
    localStorage.removeItem("user_payload");
    localStorage.removeItem("girisYapildi");
    navigate("/");
  };

  const isActive = (path) => currentPath === path || currentPath.startsWith(path + "/");

  const getLinkStyle = (path) => ({
    ...linkStyle,
    background: isActive(path) ? "rgba(233, 69, 96, 0.15)" : "rgba(255,255,255,0.05)",
    color: isActive(path) ? "#fff" : "#e0e4eb",
    borderLeft: isActive(path) ? "4px solid #e94560" : "4px solid transparent",
    fontWeight: isActive(path) ? "bold" : "500",
  });

  return (
    <div
      style={{
        width: "260px",
        background: "#0f3460", // Darker premium navy
        color: "white",
        height: "100vh",
        padding: "25px 20px",
        display: "flex",
        flexDirection: "column",
        boxShadow: "2px 0 15px rgba(0,0,0,0.3)",
        boxSizing: "border-box",
        zIndex: 10
      }}
    >
      {/* ENDUX LOGO ALANI */}
      <div style={{ textAlign: "center", marginBottom: "30px", paddingBottom: "20px", borderBottom: "1px solid rgba(255,255,255,0.1)" }}>
        <h2 style={{ margin: 0, fontSize: "32px", fontWeight: "bold", letterSpacing: "3px", color: "#e94560" }}>ENDUX</h2>
        <span style={{ fontSize: "12px", color: "#a0a5b1", letterSpacing: "1px" }}>YÖNETİM PANELİ</span>
      </div>

      <nav
        style={{
          display: "flex",
          flexDirection: "column",
          gap: "12px",
        }}
      >
        <Link to="/dashboard" style={getLinkStyle("/dashboard")}>
          Ana Kontrol Paneli
        </Link>

        <Link to="/makineler" style={getLinkStyle("/makineler")}>
          Makine Yönetimi
        </Link>

        <Link to="/bakim" style={getLinkStyle("/bakim")}>
          Bakım Yönetimi
        </Link>

        <Link to="/tedarikciler" style={getLinkStyle("/tedarikciler")}>
          Tedarikçi Bilgisi
        </Link>

        <Link to="/kisi-ekle" style={getLinkStyle("/kisi-ekle")}>
          Kişi Ekle
        </Link>
      </nav>

      {/* YÖNETİCİ PROFİLİ (EN ALTTA) */}
      <div style={{ marginTop: "auto", position: "relative" }}>
        <div 
          style={{ 
            background: "rgba(255,255,255,0.05)", 
            padding: "15px", 
            borderRadius: "10px", 
            display: "flex", 
            alignItems: "center", 
            gap: "12px", 
            cursor: "pointer",
            border: "1px solid rgba(255,255,255,0.1)"
          }}
          onClick={() => setDropdownOpen(!dropdownOpen)}
        >
          <div style={{
            width: "40px",
            height: "40px",
            borderRadius: "50%",
            background: "#e94560",
            color: "white",
            display: "flex",
            justifyContent: "center",
            alignItems: "center",
            fontWeight: "bold",
            fontSize: "18px"
          }}>
            {kullaniciAdi.charAt(0)}
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontWeight: "bold", fontSize: "14px" }}>{kullaniciAdi}</div>
            <div style={{ fontSize: "12px", color: "#a0a5b1" }}>Yetkili</div>
          </div>
          <span style={{ fontSize: "10px", color: "#666" }}>▲</span>
        </div>

        {dropdownOpen && (
          <div style={{
            position: "absolute",
            bottom: "80px",
            left: "0",
            background: "white",
            border: "1px solid #eee",
            boxShadow: "0 -4px 15px rgba(0,0,0,0.1)",
            borderRadius: "8px",
            width: "100%",
            overflow: "hidden",
            zIndex: 10
          }}>
            <div 
              style={{ padding: "12px 15px", color: "#e94560", fontSize: "14px", cursor: "pointer", fontWeight: "bold", textAlign: "center" }}
              onClick={handleCikis}
            >
              Çıkış Yap
            </div>
          </div>
        )}
      </div>

    </div>
  );
};

const linkStyle = {
  color: "#e0e4eb",
  textDecoration: "none",
  padding: "12px 16px",
  borderRadius: "8px",
  background: "rgba(255,255,255,0.05)",
  fontSize: "15px",
  fontWeight: "500",
  transition: "all 0.2s ease-in-out",
  display: "flex",
  alignItems: "center",
  gap: "10px"
};

export default Sidebar;