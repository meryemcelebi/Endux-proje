
import React, { useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
// useParams → URL'den id almak için
// useNavigate → sayfa yönlendirmek için


export default function ChecklistGiris() {
  const { id } = useParams();
  const navigate = useNavigate();
  // sayfalar arasında yönlendirme yapmak için kullanılır


  const [username, setUsername] = useState("");  // kullanıcı adı state'i (rol için kullanılıyor)

  const [password, setPassword] = useState("");   // şifre state'i


  const handleLogin = () => {  
    if (!username || !password) {
      alert("Lütfen tüm alanları doldur !");
      return;
    }

    const roleString = username.toLowerCase();    
    let assignedRoleId = 0;

    // JWT Otorizasyon / Rol Yönetimi Mock'u
    if (roleString === "yönetici") assignedRoleId = 1;
    else if (roleString === "servis" || roleString === "teknisyen") assignedRoleId = 2;
    else if (roleString === "operatör") assignedRoleId = 3;
    else {
      alert("Geçersiz kullanıcı adı türü (Mevcut roller: yönetici, servis, operatör)");
      return;
    }

    // Backend (Prisma auth) Simülasyonu
    const mockToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.machinelogintoken.key";
    const userPayload = { kullanici_id: 2, rol_id: assignedRoleId, isim: "Saha Elemanı" };
    
    localStorage.setItem("auth_token", mockToken);
    localStorage.setItem("user_payload", JSON.stringify(userPayload));
    localStorage.setItem("girisYapildi", "true");

    // Yönlendirme
    if (assignedRoleId === 1) { // Yönetici Detay Görür
      navigate(`/makine/${id}`);
    }
    else if (assignedRoleId === 3) { // Operatör Checklist Yanıtlar
      navigate(`/checklist/${id}`);
    }
    else if (assignedRoleId === 2) { // Teknisyen Servis kaydı girer
      navigate(`/servis/${id}`);
    }
  };

  return (
    <div style={sayfaStil}>
      <div style={kartStil}>
        {/* BAŞLIK */}
        <div style={{ textAlign: "center", marginBottom: "30px" }}>
          <h1 style={{ color: "navy", margin: 0, fontSize: "28px" }}>ENDUX</h1>
          <p style={{ color: "gray", marginTop: "5px" }}>Makine Giriş Paneli</p>
          <div style={etiketStil}>Makine ID: {id}</div>
        </div>

        {/*  kullanıcı adı (rol yazılıyor) */}
        <div style={{ marginBottom: "15px" }}>
          <label style={etiketYaziStil}>Kullanıcı Adı</label>
          <input
            type="text"
            placeholder="operatör / yönetici / servis"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            style={inputStil}
          />
        </div>

        {/*  şifre */}
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

        <button onClick={handleLogin} style={butonStil}>Giriş Yap</button>
      </div>
    </div>
  );
}

/* STILLER - Login sayfasıyla uyumlu */
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

const etiketStil = {
  display: "inline-block",
  marginTop: "10px",
  padding: "6px 16px",
  background: "#e8eaf6",
  color: "navy",
  borderRadius: "20px",
  fontSize: "13px",
  fontWeight: "bold",
};

const etiketYaziStil = {
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