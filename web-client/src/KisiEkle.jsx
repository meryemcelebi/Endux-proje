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
  const [seciliKisiId, setSeciliKisiId] = useState(null); // Tıklanan/Seçilen kişi ID'si

  // --- FORM STATE (Yeni Personel Bilgileri) ---
  const [form, setForm] = useState({
    kullanici_adi: "", // Giriş için kullanılacak kimlik
    sifre: "", // Kullanıcı parolası
    eposta: "", // İletişim e-postası
    telefon: "", // İletişim numarası
    ad: "", // Personel adı
    soyad: "", // Personel soyadı
    baslama_tarihi: "", // İşe giriş / sistem kayıt tarihi
    rol_id: "", // Yetki seviyesi (Admin, Teknisyen, Operatör)
  });

  // Load users on mount
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
    // Gerekli alanların doluluk kontrolü (sadece ad, soyad, telefon zorunlu)
    if (!form.ad || !form.soyad || !form.telefon) {
      alert("Lütfen ad, soyad ve telefon alanlarını doldurun.");
      return;
    }

    try {
      // rol_id (string sayısal değer örn "3") üzerinden rol stringini bul
      const roleMap = {
        "1": "OPERATOR",
        "2": "TEKNISYEN"
      };

      const rolStr = roleMap[form.rol_id] || "OPERATOR";

      // Oturum açan adminin firma_id'sini al
      const loggedUser = JSON.parse(localStorage.getItem("user") || "{}");
      const firmaId = loggedUser.firma_id || 1;

      // Şifre girilmediyse varsayılan şifre oluştur
      const sifre = form.sifre || "Endux1234";

      // API'ye gönderilecek veriler (backend 'rol' stringi bekliyor)
      const payload = {
        ...form,
        rol: rolStr,
        sifre: sifre,
        firma_id: firmaId
      };

      const addedUser = await api.addUser(payload);

      // Kaydedilen kişiyi listeye en başa ekle
      setKisiler([addedUser.kullanici ? addedUser.kullanici : addedUser, ...kisiler]);

      // Formu temizle
      setForm({
        kullanici_adi: "", sifre: "", eposta: "", telefon: "",
        ad: "", soyad: "", baslama_tarihi: "", rol_id: "",
      });
      alert("Kişi başarıyla eklendi!");
    } catch (err) {
      console.error("Kullanıcı eklenirken hata!", err);
      alert("Kayıt Başarısız: " + (err.message || "Bilinmeyen bir hata oluştu"));
    }
  };

  // --- KİŞİ SİLME / ERİŞİM KESME ---
  const deletePerson = async (id) => {
    if (!window.confirm("Bu personelin işine son vermek ve erişimini kesmek istediğinize emin misiniz?")) return;
    try {
      await api.deleteUser(id);
      // Listeden kaldır
      setKisiler(kisiler.filter(k => k.kullanici_id !== id));
      alert("Personel erişimi başarıyla sonlandırıldı (İşten ayrıldı olarak işaretlendi).");
    } catch (err) {
      console.error("Silme hatası:", err);
      alert("Hata: " + err.message);
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
                    borderLeft: `4px solid ${seciliKisiId === k.kullanici_id ? "#e74c3c" : "#3498db"}`,
                    padding: "15px",
                    marginBottom: 15,
                    borderRadius: 8,
                    background: seciliKisiId === k.kullanici_id ? "#fff5f5" : "#f8f9fa",
                    color: "#555",
                    cursor: "pointer",
                    transition: "0.3s all ease"
                  }}
                  onClick={() => setSeciliKisiId(seciliKisiId === k.kullanici_id ? null : k.kullanici_id)}
                >
                  <h3 style={{ margin: "0 0 10px 0", color: "#333", fontSize: "16px" }}>{k.ad} {k.soyad}</h3>

                  <div style={{ display: "flex", flexDirection: "column", gap: 8, fontSize: "13px" }}>
                    <div><strong>Kullanıcı ID:</strong> {k.kullanici_id}</div>
                    <div><strong>Rol ID:</strong> {k.rol_id}</div>
                    <div><strong>Telefon:</strong> {k.telefon}</div>
                    <div><strong>E-Posta:</strong> {k.eposta}</div>
                    <div><strong>Kullanıcı Adı:</strong> {k.kullanici_adi}</div>
                    <div><strong>Başlama Tarihi:</strong> {k.baslama_tarihi}</div>
                  </div>

                  {seciliKisiId === k.kullanici_id && (
                    <button
                      onClick={(e) => {
                        e.stopPropagation(); // Card'ın onClick'ini tetikleme
                        deletePerson(k.kullanici_id);
                      }}
                      style={{
                        marginTop: "15px",
                        padding: "10px 14px",
                        background: "#e74c3c",
                        color: "white",
                        border: "none",
                        borderRadius: "6px",
                        cursor: "pointer",
                        fontSize: "12px",
                        fontWeight: "bold",
                        width: "100%",
                        transition: "0.2s",
                        boxShadow: "0 4px 6px rgba(231, 76, 60, 0.2)"
                      }}
                      onMouseOver={(e) => e.target.style.background = "#c0392b"}
                      onMouseOut={(e) => e.target.style.background = "#e74c3c"}
                    >
                      İşten Ayrıldı / Erişimi Kes
                    </button>
                  )}
                </div>
              ))}
            </div>

            {/* SAĞ - FORM */}
            <div style={{ flex: 1, minWidth: "300px", background: "white", padding: "25px", borderRadius: "10px", boxShadow: "0 2px 10px rgba(0,0,0,0.05)" }}>
              <h2 style={{ margin: "0 0 20px 0", color: "#0f3460", borderBottom: "1px solid #ffffffff", paddingBottom: "12px" }}>Yeni Kişi Ekle</h2>

              <div style={{ display: "flex", flexDirection: "column", gap: 15 }}>
                <input name="ad" placeholder="Ad" value={form.ad} onChange={handleChange} style={inputStyle} />
                <input name="soyad" placeholder="Soyad" value={form.soyad} onChange={handleChange} style={inputStyle} />
                <input name="telefon" placeholder="Telefon" value={form.telefon} onChange={handleChange} style={inputStyle} />
                <input name="eposta" placeholder="E-Posta" type="email" value={form.eposta} onChange={handleChange} style={inputStyle} />
                <input name="sifre" placeholder="Şifre" type="password" value={form.sifre} onChange={handleChange} style={inputStyle} />
                <input name="baslama_tarihi" placeholder="Başlama Tarihi" type="date" value={form.baslama_tarihi} onChange={handleChange} style={inputStyle} className="date-input-dark" />
                <select name="rol_id" value={form.rol_id} onChange={handleChange} style={inputStyle}>
                  <option value="" disabled>Rol seçin</option>
                  <option value="1">Operatör</option>
                  <option value="2">Teknisyen</option>
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
