import React, { useState, useEffect } from "react";
import Sidebar from "./Sidebar";
import Navbar from "./Navbar";
import { api } from "./services/api";

/**
 * Personel / Kişi Ekleme Sayfası
 * Sisteme yeni kullanıcı, operatör veya teknisyen kaydı yapar.
 */
export default function KisiEkle() {
  const [kisiler, setKisiler] = useState([]); // Mevcut kullanıcı listesi

  // --- FORM STATE (Yeni Personel Bilgileri) ---
  const [form, setForm] = useState({
    kullanici_adi: "", // Giriş için kullanılacak kimlik
    sifre: "", // Kullanıcı parolası
    eposta: "", // İletişim e-postası
    telefon: "", // İletişim numarası
    ad: "", // Personel adı
    soyad: "", // Personel soyadı
    baslama_tarihi: "", // İşe giriş / sistem kayıt tarihi
    firma_id: "", // Bağlı olduğu firma (Fabrika içi veya Dış Servis)
    rol_id: "", // Yetki seviyesi (Admin, Teknisyen, Operatör)
  });

  // Load mock data on mount
  useEffect(() => {
    const fetchData = async () => {
      try {
        const users = await api.getUsers();
        setKisiler(users);
      } catch (error) {
        console.error("Kullanıcılar yüklenemedi", error);
      }
    };
    fetchData();
  }, []);

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  // --- YENİ KİŞİ KAYDETME ---
  const addKisi = async () => {
    // Gerekli alanların doluluk kontrolü
    if (!form.ad || !form.soyad || !form.firma_id || !form.rol_id) {
       alert("Lütfen ad, soyad, firma ve rol alanlarını doldurun.");
       return;
    }

    try {
      // rol_id (string sayısal değer örn "3") üzerinden rol stringini bul
      const roleMap = {
        "1": "OPERATOR",
        "2": "TEKNISYEN",
        "3": "YONETICI",
        "4": "SERVIS"
      };

      const rolStr = roleMap[form.rol_id] || "";

      // API'ye gönderilecek veriler (backend 'rol' stringi bekliyor)
      const payload = {
        ...form,
        firma_id: Number(form.firma_id),
        rol: rolStr
      };

      const addedUser = await api.addUser(payload);
      
      // Kaydedilen kişiyi listeye en başa ekle
      setKisiler([addedUser.kullanici ? addedUser.kullanici : addedUser, ...kisiler]);

      // Formu temizle
      setForm({
        kullanici_adi: "", sifre: "", eposta: "", telefon: "",
        ad: "", soyad: "", baslama_tarihi: "", firma_id: "", rol_id: "",
      });
      alert("Kişi başarıyla eklendi!");
    } catch (err) {
      console.error("Kullanıcı eklenirken hata!", err);
      alert("Kayıt Başarısız: " + (err.message || "Bilinmeyen bir hata oluştu"));
    }
  };

  return (
    <div style={{ display: "flex", background: "#f5f6fa", minHeight: "100vh" }}>
      <Sidebar />
      
      <div style={{ flex: 1, display: "flex", flexDirection: "column", height: "100vh", overflow: "hidden" }}>
        <Navbar />
        
        <div style={{ padding: "25px", flex: 1, overflowY: "auto" }}>
          <div style={{ display: "flex", gap: "25px", flexWrap: "wrap" }}>

            {/* SOL - LİSTE */}
            <div style={{ flex: 2, minWidth: "400px", background: "white", padding: "25px", borderRadius: "10px", boxShadow: "0 2px 10px rgba(0,0,0,0.05)" }}>
              <h2 style={{ margin: "0 0 20px 0", color: "#0f3460", borderBottom: "1px solid #eee", paddingBottom: "12px" }}>Kişi Listesi</h2>

              {kisiler.length === 0 && (
                <p style={{ color: "gray" }}>Henüz kişi eklenmedi.</p>
              )}

              {kisiler.map((k) => (
                <div
                  key={k.kullanici_id}
                  style={{
                    borderLeft: "4px solid #3498db",
                    padding: "15px",
                    marginBottom: 15,
                    borderRadius: 8,
                    background: "#f8f9fa",
                    color: "#555"
                  }}
                >
                  <h3 style={{ margin: "0 0 10px 0", color: "#333", fontSize: "16px" }}>{k.ad} {k.soyad}</h3>

                  <div style={{ display: "flex", flexDirection: "column", gap: 8, fontSize: "13px" }}>
                    <div><strong>Kullanıcı ID:</strong> {k.kullanici_id}</div>
                    <div><strong>Firma ID:</strong> {k.firma_id}</div>
                    <div><strong>Rol ID:</strong> {k.rol_id}</div>
                    <div><strong>Telefon:</strong> {k.telefon}</div>
                    <div><strong>E-Posta:</strong> {k.eposta}</div>
                    <div><strong>Kullanıcı Adı:</strong> {k.kullanici_adi}</div>
                    <div><strong>Başlama Tarihi:</strong> {k.baslama_tarihi}</div>
                  </div>
                </div>
              ))}
            </div>

            {/* SAĞ - FORM */}
            <div style={{ flex: 1, minWidth: "300px", background: "white", padding: "25px", borderRadius: "10px", boxShadow: "0 2px 10px rgba(0,0,0,0.05)" }}>
              <h2 style={{ margin: "0 0 20px 0", color: "#0f3460", borderBottom: "1px solid #eee", paddingBottom: "12px" }}>Yeni Kişi Ekle</h2>

              <div style={{ display: "flex", flexDirection: "column", gap: 15 }}>
                <input name="ad" placeholder="Ad" value={form.ad} onChange={handleChange} style={inputStyle} />
                <input name="soyad" placeholder="Soyad" value={form.soyad} onChange={handleChange} style={inputStyle} />
                <input name="telefon" placeholder="Telefon" value={form.telefon} onChange={handleChange} style={inputStyle} />
                <input name="eposta" placeholder="E-Posta" type="email" value={form.eposta} onChange={handleChange} style={inputStyle} />
                <input name="kullanici_adi" placeholder="Kullanıcı Adı" value={form.kullanici_adi} onChange={handleChange} style={inputStyle} />
                <input name="sifre" placeholder="Şifre" type="password" value={form.sifre} onChange={handleChange} style={inputStyle} />
                <input name="baslama_tarihi" placeholder="Başlama Tarihi" type="date" value={form.baslama_tarihi} onChange={handleChange} style={inputStyle} />
                <input name="firma_id" placeholder="Firma ID" type="number" value={form.firma_id} onChange={handleChange} style={inputStyle} />
                <select name="rol_id" value={form.rol_id} onChange={handleChange} style={inputStyle}>
                  <option value="" disabled>Rol seçin</option>
                  <option value="1">Operatör</option>
                  <option value="2">Teknisyen</option>
                  <option value="3">Yönetici</option>
                  <option value="4">Dış Servis Sorumlusu</option>
                </select>

                <button
                  onClick={addKisi}
                  style={buttonStyle}
                  onMouseOver={(e) => e.target.style.background = "#1a467a"} 
                  onMouseOut={(e) => e.target.style.background = "#0f3460"}
                >
                  Kişiyi Kaydet
                </button>
              </div>
            </div>

          </div>
        </div>
      </div>
    </div>
  );
}

const inputStyle = { padding: "14px", border: "1px solid #e1e5eb", borderRadius: "8px", fontSize: "14px", outline: "none", width: "100%", boxSizing: "border-box", background: "#fafafa", color: "#333", fontFamily: "inherit" };
const buttonStyle = { padding: "14px", background: "#0f3460", color: "white", border: "none", borderRadius: "8px", fontSize: "16px", fontWeight: "bold", cursor: "pointer", transition: "0.2s", marginTop: "10px" };
