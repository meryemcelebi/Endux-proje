import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "./services/api";

/**
 * Ana Giriş Sayfası (Login)
 * Yöneticilerin ve teknik servis personelinin sisteme giriş yaptığı ekrandır.
 * Operatörler bu panel yerine makineye özel giriş panelini kullanır.
 */
export default function Login() {
  const navigate = useNavigate();
  const [kullaniciAdi, setKullaniciAdi] = useState(""); // Kullanıcı adı state'i
  const [sifre, setSifre] = useState(""); // Şifre state'i
  const [hata, setHata] = useState(""); // Hata mesajlarını tutar

  // --- GİRİŞ İŞLEMİ (FORM SUBMIT) ---
  const handleGiris = async (e) => {
    e.preventDefault();

    if (!kullaniciAdi || !sifre) {
      setHata("Kullanıcı adı veya şifre boş bırakılamaz!");
      return;
    }

    try {
      // API'ye giriş isteği at (Kullanıcı adını küçük harfe zorla)
      const result = await api.login({ kullanici_adi: kullaniciAdi, sifre });

      if (result.success) {
        // Dashboard ve Teknik Servis girişi için yetki kontrolü (Rol 0, 1 veya 2 olmalı)
        if (result.user.rol_id !== 0 && result.user.rol_id !== 1 && result.user.rol_id !== 2) {
          throw new Error("Bu panele Operatörler giriş yapamaz. Sadece Yönetici ve Teknik Servis girebilir.");
        }

        // Kimlik doğrulama verilerini tarayıcı hafızasına (Local Storage) kaydet
        localStorage.setItem("auth_token", result.token);
        localStorage.setItem("user_payload", JSON.stringify(result.user));
        localStorage.setItem("girisYapildi", "true");

        // ROL BAZLI YÖNLENDİRME:
        // Eğer kullanıcı Teknik Servis ise (rol_id = 2) servis sayfasına, 
        // Yönetici ise (rol_id = 0, 1) dashboard paneline yönlendir.
        if (result.user.rol_id === 2) {
          navigate("/teknik-servis");
        } else {
          navigate("/dashboard");
        }
      }
    } catch (error) {
      setHata(error.message || "Giriş başarısız oldu.");
    }
  };

  return (
    <div style={sayfaStil}>
      <div style={kartStil}>
        {/* LOGO / BAŞLIK */}
        <div style={{ textAlign: "center", marginBottom: "30px" }}>
          <h1 style={{ color: "navy", margin: 0, fontSize: "28px" }}>MAİNTFY</h1>
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
