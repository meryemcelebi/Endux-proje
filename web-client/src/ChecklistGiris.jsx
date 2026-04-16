import React, { useState, useEffect } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { api } from "./services/api";

/**
 * Makine Özel Giriş Paneli (İkili Mod: Personel + Misafir)
 * Personel (Yönetici/Operatör) kullanıcı adı ile,
 * Misafir (Servis) telefon ve PIN ile giriş sağlar.
 */
export default function ChecklistGiris() {
  const { id } = useParams();
  const navigate = useNavigate();

  // Mode State
  const [isGuestMode, setIsGuestMode] = useState(false);

  // Personel Login State
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");

  // Misafir Login State
  const [phone, setPhone] = useState("");
  const [fullName, setFullName] = useState("");
  const [title, setTitle] = useState("");
  const [firmId, setFirmId] = useState("");
  const [pin, setPin] = useState("");

  const [firms, setFirms] = useState([]);
  const [welcomeMsg, setWelcomeMsg] = useState(null);

  // Firma listesini yükle (Misafir girişi için)
  useEffect(() => {
    const fetchFirms = async () => {
      try {
        const allFirms = await api.getFirms();
        setFirms(allFirms);
      } catch (err) {
        console.error("Firmalar yüklenemedi:", err);
      }
    };
    fetchFirms();
  }, []);

  const handleStaffLogin = async () => {
    if (!username || !password) {
      alert("Lütfen tüm alanları doldurun!");
      return;
    }
    try {
      const result = await api.login({ kullanici_adi: username, sifre: password });
      if (result.success) {
        saveLogin(result);
        const role = result.user.rol_id;
        if (role === 1) navigate(`/makine/${id}`);
        else if (role === 3) navigate(`/checklist/${id}`);
        else if (role === 2) navigate(`/servis/${id}`);
      }
    } catch (err) {
      alert(err.message || "Giriş başarısız.");
    }
  };

  const handleGuestLogin = async () => {
    if (!phone || !pin) {
      alert("Telefon ve PIN kodu zorunludur!");
      return;
    }
    try {
      const result = await api.checkServiceLogin({
        makine_id: id,
        telefon: phone,
        ad_soyad: fullName,
        unvan: title,
        firma_id: firmId,
        pin: pin
      });
      if (result.success) {
        setWelcomeMsg(result.isNew
          ? `Hoş geldiniz, ${result.user.ad}! Kaydınız oluşturuldu.`
          : `Tekrar hoş geldin, ${result.user.ad}!`);

        saveLogin(result);
        setTimeout(() => navigate(`/servis/${id}`), 2000);
      }
    } catch (err) {
      alert(err.message || "Giriş başarısız.");
    }
  };

  const saveLogin = (result) => {
    localStorage.setItem("auth_token", result.token);
    localStorage.setItem("user_payload", JSON.stringify(result.user));
    localStorage.setItem("girisYapildi", "true");
  };

  return (
    <div style={sayfaStil}>
      <div style={kartStil}>
        <div style={{ textAlign: "center", marginBottom: "25px" }}>
          <h1 style={{ color: "#e94560", margin: 0, fontSize: "32px", fontWeight: "bold", letterSpacing: "2px" }}>ENDUX</h1>
          <p style={{ color: "#a0a5b1", marginTop: "5px", fontSize: "14px" }}>
            {isGuestMode ? "Misafir (Servis) Girişi" : "Personel Giriş Paneli"}
          </p>
          <div style={etiketStil}>Makine ID: {id}</div>
        </div>

        {welcomeMsg && (
          <div style={welcomeBoxStyle}>
            🌟 {welcomeMsg}
          </div>
        )}

        {!isGuestMode ? (
          /* PERSONEL GİRİŞ FORMU */
          <div>
            <div style={{ marginBottom: "15px" }}>
              <label style={etiketYaziStil}>Kullanıcı Adı</label>
              <input
                type="text"
                placeholder="operatör / yönetici"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                style={inputStil}
              />
            </div>
            <div style={{ marginBottom: "20px" }}>
              <label style={etiketYaziStil}>Şifre</label>
              <input
                type="password"
                placeholder="Şifrenizi girin"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                style={inputStil}
              />
            </div>
            <button onClick={handleStaffLogin} style={butonStil}>Giriş Yap</button>
            <div style={{ marginTop: "20px", textAlign: "center" }}>
              <button
                onClick={() => setIsGuestMode(true)}
                style={personelToggleStil}
              >
                Misafir Servis Girişi Yap
              </button>
            </div>
          </div>
        ) : (
          /* MİSAFİR GİRİŞ FORMU */
          <div>
            <div style={{ marginBottom: "10px" }}>
              <label style={etiketYaziStil}>Telefon Numarası</label>
              <input
                type="tel"
                placeholder="05xx xxx xx xx"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                style={inputStil}
              />
            </div>
            <div style={{ marginBottom: "10px" }}>
              <label style={etiketYaziStil}>Ad Soyad</label>
              <input
                type="text"
                placeholder="İsim Giriniz"
                value={fullName}
                onChange={(e) => setFullName(e.target.value)}
                style={inputStil}
              />
            </div>
            <div style={{ marginBottom: "10px" }}>
              <label style={etiketYaziStil}>Firma</label>
              <select
                value={firmId}
                onChange={(e) => setFirmId(e.target.value)}
                style={inputStil}
              >
                <option value="">Firma Seçiniz...</option>
                {firms.map(f => (
                  <option key={f.id} value={f.id}>{f.ad || f.firma_adi}</option>
                ))}
              </select>
            </div>
            <div style={{ marginBottom: "20px" }}>
              <label style={etiketYaziStil}>Makine PIN</label>
              <input
                type="password"
                placeholder="4 Haneli PIN"
                value={pin}
                onChange={(e) => setPin(e.target.value)}
                style={{ ...inputStil, textAlign: "center", letterSpacing: "5px" }}
              />
            </div>
            <button onClick={handleGuestLogin} style={butonStil}>
              Servis Girişini Tamamla
            </button>
            <div style={{ marginTop: "20px", textAlign: "center" }}>
              <button
                onClick={() => setIsGuestMode(false)}
                style={personelToggleStil}
              >
                Personel Girişine Dön
              </button>
            </div>
          </div>
        )}
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
  background: "linear-gradient(135deg, #0f3460 0%, #16213e 50%, #1a1a2e 100%)",
  margin: 0,
};

const kartStil = {
  background: "white",
  padding: "35px",
  borderRadius: "20px",
  boxShadow: "0 15px 35px rgba(0, 0, 0, 0.4)",
  width: "400px",
  maxWidth: "90%",
};

const etiketStil = {
  display: "inline-block",
  marginTop: "10px",
  padding: "5px 15px",
  background: "rgba(233, 69, 96, 0.1)",
  color: "#e94560",
  borderRadius: "15px",
  fontSize: "12px",
  fontWeight: "bold",
};

const etiketYaziStil = {
  display: "block",
  marginBottom: "5px",
  fontWeight: "bold",
  color: "#333",
  fontSize: "13px",
};

const inputStil = {
  width: "100%",
  padding: "10px 15px",
  border: "1px solid #ddd",
  borderRadius: "10px",
  fontSize: "14px",
  boxSizing: "border-box",
  background: "#fdfdfd",
  color: "black", // Yazı rengi net siyah yapıldı
};

const butonStil = {
  width: "100%",
  padding: "14px",
  background: "navy",
  color: "white",
  border: "none",
  borderRadius: "10px",
  fontSize: "16px",
  fontWeight: "bold",
  cursor: "pointer",
  transition: "all 0.3s ease",
};

const linkButonStil = {
  background: "none",
  border: "none",
  color: "#16213e",
  fontSize: "13px",
  fontWeight: "bold",
  cursor: "pointer",
  textDecoration: "underline",
};

const servisToggleStil = {
  background: "rgba(39, 174, 96, 0.1)",
  border: "2px solid rgba(39, 174, 96, 0.3)",
  color: "#27ae60",
  padding: "8px 25px",
  borderRadius: "12px",
  fontSize: "13px",
  fontWeight: "bold",
  cursor: "pointer",
  transition: "all 0.3s ease",
  marginTop: "10px",
  display: "inline-block",
};

const personelToggleStil = {
  background: "rgba(233, 69, 96, 0.05)",
  border: "1px dashed rgba(233, 69, 96, 0.5)",
  color: "#e94560",
  padding: "8px 15px",
  borderRadius: "10px",
  fontSize: "13px",
  fontWeight: "bold",
  cursor: "pointer",
  transition: "all 0.3s ease",
};

const servisCikarButonStil = {
  width: "100%",
  padding: "14px",
  background: "linear-gradient(135deg, #27ae60 0%, #2ecc71 100%)",
  color: "white",
  border: "none",
  borderRadius: "12px",
  fontSize: "16px",
  fontWeight: "bold",
  cursor: "pointer",
  boxShadow: "0 4px 15px rgba(46, 204, 113, 0.3)",
  transition: "all 0.3s ease",
};

const welcomeBoxStyle = {
  background: "#d4edda",
  color: "#155724",
  padding: "12px",
  borderRadius: "10px",
  marginBottom: "20px",
  textAlign: "center",
  fontWeight: "bold",
  fontSize: "14px",
  border: "1px solid #c3e6cb",
};