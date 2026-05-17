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

  // --- MİSAFİR (SERVİS) GİRİŞİ STATE'LERİ ---
  const [phone, setPhone] = useState(""); // Servis elemanı telefon numarası (Zorunlu)
  const [fullName, setFullName] = useState(""); // Servis elemanı ad soyad
  const [title, setTitle] = useState(""); // Ünvanı (Teknisyen, Mühendis vb.)
  const [firmId, setFirmId] = useState(""); // Bağlı olduğu firma ID'si
  const [pin, setPin] = useState(""); // Makineye özel 4 haneli PIN kodu

  const [firms, setFirms] = useState([]);
  const [welcomeMsg, setWelcomeMsg] = useState(null);

  // Firma listesini yükle (Misafir girişi için)
  useEffect(() => {
    const fetchFirms = async () => {
      try {
        const servisFirmalari = await api.getServiceFirms();
        // Dropdown formatına uygun map
        setFirms(servisFirmalari.map(f => ({
          id: f.servis_firma_id,
          ad: f.firma_adi
        })));
      } catch (err) {
        console.error("Firmalar yüklenemedi:", err);
      }
    };
    fetchFirms();
  }, []);

  // --- OTURUM KAYDET ---
  const saveLogin = (result) => {
    localStorage.setItem("auth_token", result.token);
    localStorage.setItem("user_payload", JSON.stringify(result.user));
    localStorage.setItem("girisYapildi", "true");
  };

  // --- PERSONEL GİRİŞİ (Yönetici / Operatör) ---
  const handleStaffLogin = async () => {
    if (!username || !password) {
      alert("Lütfen tüm alanları doldurun!");
      return;
    }
    try {
      const result = await api.login({ kullanici_adi: username, sifre: password });
      if (result.success) {
        saveLogin(result);

        if (id) {
          try {
            // QR Merkezi üzerinden (qrileMakineGetir) AUDIT loglarını yazdır ve gerçek veriyi getir
            const qrResult = await api.getMachineByQR(id);
            console.log("QR Sonuç:", qrResult);
            const roleStr = qrResult.rol;
            const makineId = qrResult.makine?.makine_id || qrResult.data?.makine_id;

            if (!makineId) {
              alert("Makine ID alınamadı. Backend yanıtı: " + JSON.stringify(qrResult).substring(0, 200));
              return;
            }

            // Dinamik olarak merkezin belirlediği role göre form/panellere yönlendir
            if (roleStr === "YONETICI") navigate(`/makine/${makineId}`);
            else if (roleStr === "OPERATOR") navigate(`/checklist/${makineId}`);
            else if (roleStr === "TEKNISYEN") navigate(`/servis/${makineId}`);
            else navigate(`/dashboard`);
          } catch (err) {
            console.error("QR giriş hatası:", err);
            alert("QR kod doğrulanamadı: " + (err.message || "Bilinmeyen hata"));
          }
        } else {
          // Eğer direkt URL'den /checklist-giris yazıp girdiyse (makine yoksa) panele at
          navigate("/dashboard");
        }
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
        qr_uuid: id,
        telefon: phone,
        ad_soyad: fullName,
        unvan: title,
        firma_id: firmId,
        pin: pin
      });
      if (result.success) {
        setWelcomeMsg(result.isNew
          ? `Hoş geldiniz, ${result.user.ad}! Yeni kaydınız oluşturuldu.`
          : `Tekrar hoş geldin, ${result.user.ad}!`);

        saveLogin(result);

        // API'den gelen makine_id'yi (integer) kullan (UUID yerine)
        const finalId = result.makine?.makine_id || result.data?.makine?.makine_id;

        setTimeout(() => {
          if (finalId) navigate(`/servis/${finalId}`);
          else navigate("/dashboard");
        }, 2000);
      }
    } catch (err) {
      alert(err.message || "Giriş başarısız.");
    }
  };

  return (
    <div className="app-container" style={sayfaStil}>
      <div style={kartStil}>
        <div style={{ textAlign: "center", marginBottom: "25px" }}>
          <h1 style={{ color: "#e94560", margin: 0, fontSize: "32px", fontWeight: "bold", letterSpacing: "2px" }}>MAINTIFY</h1>
          <p style={{ color: "#a0a5b1", marginTop: "5px", fontSize: "14px" }}>
            {isGuestMode ? "Misafir (Servis) Girişi" : "Personel Giriş Paneli"}
          </p>
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
                placeholder="operatör / yönetici / teknisyen"
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
              <label style={etiketYaziStil}>Ünvan / Uzmanlık Alanı</label>
              <select
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                style={inputStil}
              >
                <option value="">Ünvan Seçiniz...</option>
                <option value="Bakım Teknisyeni">Bakım Teknisyeni</option>
                <option value="Elektrik Teknisyeni">Elektrik Teknisyeni</option>
                <option value="Mekanik Teknisyeni">Mekanik Teknisyeni</option>
                <option value="Servis Mühendisi">Servis Mühendisi</option>
                <option value="Yazılım Destek">Yazılım Destek</option>
                <option value="Otomasyon Uzmanı">Otomasyon Uzmanı</option>
                <option value="Diğer">Diğer</option>
              </select>
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