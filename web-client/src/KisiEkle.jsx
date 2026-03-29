
import React, { useState } from "react";
import Sidebar from "./Sidebar";
import Navbar from "./Navbar";

export default function KisiEkle() {
  const [kisiler, setKisiler] = useState([]);

  const [form, setForm] = useState({
    ad: "",
    soyad: "",
    telefon: "",
    eposta: "",
    kullaniciAdi: "",
    sifre: "",
    baslamaTarihi: "",
    rol: "",
  });

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const addKisi = () => {
    if (!form.ad || !form.soyad) return; /*Ad ve soyad zorunlu*/

    const yeniKisi = {
      ...form,
      kullaniciId: Date.now().toString(), /*otomatik benzersiz Kullanıcı ID*/
      rolId: Math.floor(Math.random() * 9000 + 1000).toString(), /*otomatik Rol ID*/
    };

    setKisiler([yeniKisi, ...kisiler]);

    setForm({
      ad: "",
      soyad: "",
      telefon: "",
      eposta: "",
      kullaniciAdi: "",
      sifre: "",
      baslamaTarihi: "",
      rol: "",
    });
  };

  return (
    <div>
      {/* ÜST NAVBAR */}
      <Navbar />

      <div style={{ display: "flex" }}>

        {/* SOL MENÜ */}
        <Sidebar />

        {/* ANA İÇERİK */}
        <div style={{ flex: 1, padding: "20px" }}>

          <div style={{ display: "flex", gap: "20px" }}>

            {/* SOL - LİSTE */}
            <div style={{ flex: 1 }}>
              <h2>Kişi Listesi</h2>

              {kisiler.length === 0 && (
                <p style={{ color: "gray" }}>Henüz kişi eklenmedi.</p>
              )}

              {kisiler.map((k) => (
                <div
                  key={k.kullaniciId}
                  style={{
                    border: "1px solid #f5f6faff",
                    padding: 10,
                    marginBottom: 10,
                    borderRadius: 8,
                    background: "#f9f9f9",
                    color: "black"
                  }}
                >
                  <h3>{k.ad} {k.soyad}</h3>

                  <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
                    <div>Kullanıcı ID: {k.kullaniciId}</div>
                    <div>Rol ID: {k.rolId}</div>
                    <div>Ad: {k.ad}</div>
                    <div>Soyad: {k.soyad}</div>
                    <div>Telefon: {k.telefon}</div>
                    <div>E-Posta: {k.eposta}</div>
                    <div>Kullanıcı Adı: {k.kullaniciAdi}</div>
                    <div>Başlama Tarihi: {k.baslamaTarihi}</div>
                    <div>Rol: {k.rol}</div>
                  </div>
                </div>
              ))}
            </div>

            {/* SAĞ - FORM */}
            <div style={{ flex: 1 }}>
              <h2>Kişi Ekle</h2>

              <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>

                <input name="ad" placeholder="Ad" value={form.ad} onChange={handleChange} />
                <input name="soyad" placeholder="Soyad" value={form.soyad} onChange={handleChange} />
                <input name="telefon" placeholder="Telefon" value={form.telefon} onChange={handleChange} />
                <input name="eposta" placeholder="E-Posta" type="email" value={form.eposta} onChange={handleChange} />
                <input name="kullaniciAdi" placeholder="Kullanıcı Adı" value={form.kullaniciAdi} onChange={handleChange} />
                <input name="sifre" placeholder="Şifre" type="password" value={form.sifre} onChange={handleChange} />
                <input name="baslamaTarihi" placeholder="Başlama Tarihi" type="date" value={form.baslamaTarihi} onChange={handleChange} />
                <input name="rol" placeholder="Rol (örn: Yönetici, Teknisyen, Operatör)" value={form.rol} onChange={handleChange} />

                <button
                  onClick={addKisi}
                  style={{
                    padding: "10px",
                    background: "blue",
                    color: "white",
                    border: "none",
                    borderRadius: "6px",
                    cursor: "pointer"
                  }}
                >
                  Kaydet
                </button>
              </div>
            </div>

          </div>

        </div>
      </div>
    </div>
  );
}
