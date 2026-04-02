import React, { useState } from "react";
import { useNavigate } from "react-router-dom";

export default function Login() {
  const navigate = useNavigate();
  const [kullaniciAdi, setKullaniciAdi] = useState("");
  const [sifre, setSifre] = useState("");
  const [hata, setHata] = useState("");

  const handleGiris = (e) => {
    e.preventDefault(); 

    if (kullaniciAdi && sifre) {
      // Backend (Prisma & Node.js auth işlemi simülasyonu)
      const mockToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.mock_token.signature";
      const userPayload = { kullanici_id: 1, rol_id: 1, isim: "Admin" };
      
      localStorage.setItem("auth_token", mockToken);
      localStorage.setItem("user_payload", JSON.stringify(userPayload));
      localStorage.setItem("girisYapildi", "true"); 
      
      navigate("/dashboard"); 
    } else {
      setHata("Kullanıcı adı veya şifre boş bırakılamaz!");
    }
  };

  return (
    <div style={sayfaStil}>
      <div style={kartStil}>
        {/* LOGO / BAŞLIK */}
        <div style={{ textAlign: "center", marginBottom: "30px" }}>
          <h1 style={{ color: "navy", margin: 0, fontSize: "28px" }}>ENDUX</h1>
          <p style={{ color: "gray", marginTop: "5px" }}>Yönetici Giriş Paneli</p>
        </div>

        {/* HATA MESAJI */}
        {hata && (
          <div style={hataStil}>
            {hata}
          </div>
        )}

        {/* GİRİŞ FORMU */}
        <form onSubmit={handleGiris}>
          <div style={{ marginBottom: "15px" }}>
            <label style={labelStil}>Kullanıcı Adı</label>
            <input
              type="text"
              value={kullaniciAdi}
              onChange={(e) => setKullaniciAdi(e.target.value)}
              placeholder="Kullanıcı adınızı girin"
              style={inputStil}
            />
          </div>

          <div style={{ marginBottom: "20px" }}>
            <label style={labelStil}>Şifre</label>
            <input
              type="password"
              value={sifre}
              onChange={(e) => setSifre(e.target.value)}
              placeholder="Şifrenizi girin"
              style={inputStil}
            />
          </div>

          <button type="submit" style={butonStil}>
            Giriş Yap
          </button>
        </form>
      </div>
    </div>
  );
}

/* STILLER */
const sayfaStil = {
  display: "flex",
  justifyContent: "center",
  alignItems: "center",
  height: "100vh",
  background: "linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%)",
  margin: 0,
};

const kartStil = {
  background: "white",
  padding: "40px",
  borderRadius: "12px",
  boxShadow: "0 8px 30px rgba(0, 0, 0, 0.3)",
  width: "380px",
  maxWidth: "90%",
};

const labelStil = {
  display: "block",
  marginBottom: "6px",
  fontWeight: "bold",
  color: "#333",
  fontSize: "14px",
};

const inputStil = {
  width: "100%",
  padding: "12px",
  border: "2px solid #ddd",
  borderRadius: "8px",
  fontSize: "14px",
  boxSizing: "border-box",
  outline: "none",
  color: "#333",
  background: "#fafafa",
};

const butonStil = {
  width: "100%",
  padding: "14px",
  background: "navy",
  color: "white",
  border: "none",
  borderRadius: "8px",
  fontSize: "16px",
  fontWeight: "bold",
  cursor: "pointer",
};

const hataStil = {
  background: "#ffe0e0",
  color: "#c62828",
  padding: "10px",
  borderRadius: "8px",
  marginBottom: "15px",
  textAlign: "center",
  fontSize: "14px",
};
