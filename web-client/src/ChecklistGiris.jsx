
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


  const PASSWORDS = {   // rol → şifre eşleşmeleri
    operatör: "1111",
    yönetici: "9999",
    servis: "5555",
  };

  const handleLogin = () => {   // giriş kontrol fonksiyonu
    if (!username || !password) {
      alert("Lütfen tüm alanları doldur !");
      return;
    }

    const role = username.toLowerCase();    // kullanıcı adını küçük harfe çevirir

    if (!PASSWORDS[role]) {
      alert("Geçersiz kullanıcı adı !");
      return;
    }

    if (PASSWORDS[role] !== password) {
      alert("Şifre yanlış !");
      return;
    }

    // yönlendirme
    if (role === "yönetici") {
      navigate(`/makine/${id}`);
    } 
    else if (role === "operatör") {
      navigate(`/checklist/${id}`);
    } 
    else if (role === "servis") {
      navigate(`/servis/${id}`);
    }
  };

  return (
    <div style={{ padding: 20 }}>
      <h2>Makine Girişi</h2>
      <p>Makine ID: {id}</p>

      {/*  kullanıcı adı (rol yazılıyor) */}
      <input
        type="text"
        placeholder="operatör / yönetici / servis"
        value={username}
        onChange={(e) => setUsername(e.target.value)}   // kullanıcı yazdıkça username güncellenir

        style={{ display: "block", marginBottom: 10 }}   // alt alta gelsin diye block + boşluk
      />

      {/*  şifre */}
      <input
        type="password"
        placeholder="Şifre gir"
        value={password}
        onChange={(e) => setPassword(e.target.value)}   // yazdıkça password güncellenir
        style={{ display: "block", marginBottom: 10 }}
      />

      <button onClick={handleLogin}>Giriş</button>      
          </div>
  );
}