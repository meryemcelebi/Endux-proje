import React, { useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";

/**
 * Yan Menü (Sidebar) Bileşeni
 * Uygulamanın ana navigasyonunu sağlar. Kullanıcının rolüne (Admin/Yönetici/Teknisyen)
 * göre menü elemanlarını dinamik olarak gösterir veya gizler.
 */
const Sidebar = () => {
  const location = useLocation(); // Mevcut sayfa yolunu belirlemek için
  const currentPath = location.pathname;
  const navigate = useNavigate();
  const [dropdownOpen, setDropdownOpen] = useState(false);

  // Oturum açan kullanıcının bilgilerini ve yetki seviyesini al
  const payloadStr = localStorage.getItem("user_payload");
  const userPayload = payloadStr ? JSON.parse(payloadStr) : { ad: "Yönetici", rol_id: 1 };
  const kullaniciAdi = userPayload.ad || "Kullanıcı";
  const userRole = userPayload.rol_id;

  // Yetki Kontrolü: Sadece rolü 0 (Süper Admin) ve 1 (Yönetici) olanlar tüm menüleri görebilir
  const isAdmin = userRole === 0 || userRole === 1;

  // Çıkış yaparken tarayıcıdaki oturum bilgilerini temizler ve giriş sayfasına döner.
  const handleCikis = () => {
    localStorage.removeItem("auth_token");
    localStorage.removeItem("user_payload");
    localStorage.removeItem("girisYapildi");
    navigate("/");
  };

  // Aktif menü öğesini belirlemek için URL kontrolü yapar
  const isActive = (path) => currentPath === path || currentPath.startsWith(path + "/");

  // Menü öğeleri için dinamik stil oluşturur (Aktifse vurgular)
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
      {/* MAİNTFY LOGO ALANI */}
      <div style={{ textAlign: "center", marginBottom: "30px", paddingBottom: "20px", borderBottom: "1px solid rgba(255,255,255,0.1)" }}>
        <h2 style={{ margin: 0, fontSize: "32px", fontWeight: "bold", letterSpacing: "3px", color: "#e94560" }}>MAİNTFY</h2>
        <span style={{ fontSize: "12px", color: "#a0a5b1", letterSpacing: "1px" }}>
          {isAdmin ? "YÖNETİM PANELİ" : "SERVİS PANELİ"}
        </span>
      </div>

      <nav
        style={{
          display: "flex",
          flexDirection: "column",
          gap: "12px",
        }}
      >
        {isAdmin && (
          <>
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
              Tedarikçi/Stok Yönetimi
            </Link>

            <Link to="/kisi-ekle" style={getLinkStyle("/kisi-ekle")}>
              Personel Ekle
            </Link>
          </>
        )}

        <Link to="/teknik-servis" style={getLinkStyle("/teknik-servis")}>
          Teknik Servis
        </Link>
      </nav>

      {/* YÖNETİCİ/PERSONEL PROFİLİ (EN ALTTA) */}
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
            {kullaniciAdi.charAt(0).toUpperCase()}
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontWeight: "bold", fontSize: "14px" }}>{kullaniciAdi}</div>
            <div style={{ fontSize: "12px", color: "#a0a5b1" }}>
              {isAdmin ? "Yetkili Yönetici" : "Dahili Teknisyen"}
            </div>
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