import React, { useState } from "react";

// Yeni firma (Tedarikçi veya Servis) eklemek için kullanılan Modal bileşeni
export default function FirmModal({ isOpen, onClose, onSave, initialType = "Servis" }) {
  // --- FORM STATE TANIMLAMALARI ---
  const [form, setForm] = useState({
    ad: "", // Firma veya Servis adı
    tip: initialType, // Tedarikçi veya Servis firması ayrımı
    telefon: "", // Kurumsal iletişim numarası
    email: "", // Kurumsal e-posta adresi
    adres: "", // Firmanın açık adresi
    uzmanlik_alani: "", // Sadece Servis firmaları için uzmanlık detayı (Genel Mekanik vb.)
    sorumlu_ad: "", // İlgili personelin adı
    sorumlu_soyad: "", // İlgili personelin soyadı
    sorumlu_telefon: "", // İlgili personelin doğrudan ulaşım numarası
    yetkili_kisi: "", // Sadece Tedarikçiler için ana temas kişisi
    vergi_no: "", // Vergi numarası veya resmi sicil no
    il: "", // İl bilgisi
    ilce: "" // İlçe bilgisi
  });

  // Modal kapalıysa hiçbir şey render etme
  if (!isOpen) return null;

  // İnput değişimlerini takip eden fonksiyon
  const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

  // Form gönderildiğinde çalışan fonksiyon
  const handleSubmit = (e) => {
    e.preventDefault();
    if (!form.ad) return alert("Firma adı zorunludur!");

    const payload = {
      ...form,
      aktiflik: true,
      kayit_tarihi: new Date().toISOString(),
      ortalama_puan: 0 // Yeni firmalar 0 puanla başlar
    };
    onSave(payload); // Veriyi üst bileşene gönder

    setForm({
      ad: "", tip: initialType, telefon: "", email: "", adres: "",
      uzmanlik_alani: "", sorumlu_ad: "", sorumlu_soyad: "", sorumlu_telefon: "",
      yetkili_kisi: "", vergi_no: "", il: "", ilce: ""
    }); // Formu sıfırla
  };

  return (
    <div style={modalOverlayStil}>
      <div style={modalContentStil}>
        {/* Modal Başlığı */}
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "20px" }}>
          <h3 style={{ margin: 0, color: "#0f3460" }}>Yeni Firma Ekle ({form.tip})</h3>
          <button onClick={onClose} style={closeButonStil}>&times;</button>
        </div>

        {/* Ekleme Formu */}
        <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: "15px" }}>

          <div style={formRowStil}>
            <div style={{ flex: 1 }}>
              <label style={labelStil}>Firma/Servis Adı *</label>
              <input type="text" name="ad" value={form.ad} onChange={handleChange} style={inputStil} required />
            </div>
            <div style={{ flex: 1 }}>
              <label style={labelStil}>Firma Türü</label>
              <input type="text" value={form.tip} style={{ ...inputStil, background: "#eee", cursor: "not-allowed", color: "#666" }} disabled />
            </div>
          </div>

          <div style={formRowStil}>
            <div style={{ flex: 1 }}>
              <label style={labelStil}>Kurumsal Telefon</label>
              <input type="text" name="telefon" value={form.telefon} onChange={handleChange} style={inputStil} placeholder="Örn: 0216..." />
            </div>
            <div style={{ flex: 1 }}>
              <label style={labelStil}>Kurumsal E-posta</label>
              <input type="email" name="email" value={form.email} onChange={handleChange} style={inputStil} placeholder="Örn: info@firma.com" />
            </div>
          </div>

          {form.tip === "Servis" && (
            <React.Fragment>
              <div style={{ marginBottom: "12px" }}>
                <label style={labelStil}>Uzmanlık Alanı</label>
                <input type="text" name="uzmanlik_alani" value={form.uzmanlik_alani} onChange={handleChange} style={inputStil} placeholder="Örn: CNC Mekaniği, Motor Revizyon" />
              </div>

              <div style={{ marginBottom: "12px" }}>
                <label style={labelStil}>Sorumlu Adı/Soyadı</label>
                <input type="text" name="sorumlu_ad" value={form.sorumlu_ad} onChange={handleChange} style={inputStil} placeholder="Örn: Ahmet Yılmaz" />
              </div>
            </React.Fragment>
          )}

          {form.tip === "Tedarikçi" && (
            <React.Fragment>
              <div style={{ marginBottom: "12px" }}>
                <label style={labelStil}>Yetkili Kişi Adı/Soyadı</label>
                <input type="text" name="yetkili_kisi" value={form.yetkili_kisi} onChange={handleChange} style={inputStil} placeholder="Örn: Mehmet Özsoy" />
              </div>

              <div style={{ marginBottom: "12px" }}>
                <label style={labelStil}>Veri / Vergi No</label>
                <input type="text" name="vergi_no" value={form.vergi_no} onChange={handleChange} style={inputStil} placeholder="Örn: TR123..." />
              </div>
            </React.Fragment>
          )}

          <div style={formRowStil}>
            <div style={{ flex: 1 }}>
              <label style={labelStil}>İl</label>
              <input type="text" name="il" value={form.il} onChange={handleChange} style={inputStil} placeholder="Örn: İstanbul" />
            </div>
            <div style={{ flex: 1 }}>
              <label style={labelStil}>İlçe</label>
              <input type="text" name="ilce" value={form.ilce} onChange={handleChange} style={inputStil} placeholder="Örn: Üsküdar" />
            </div>
          </div>

          <div style={{ marginTop: "12px" }}>
            <label style={labelStil}>Firma Adresi (Açık Adres)</label>
            <textarea name="adres" value={form.adres} onChange={handleChange} style={{ ...inputStil, height: "60px" }} />
          </div>

          <div style={{ display: "flex", gap: "10px", marginTop: "20px" }}>
            <button type="button" onClick={onClose} style={{ ...butonStil, background: "#ccc", color: "#333" }}>İptal</button>
            <button type="submit" style={butonStil}>Kaydet</button>
          </div>
        </form>
      </div>
    </div>
  );
}

const modalOverlayStil = {
  position: "fixed",
  top: 0,
  left: 0,
  right: 0,
  bottom: 0,
  background: "rgba(0,0,0,0.5)",
  display: "flex",
  justifyContent: "center",
  alignItems: "center",
  zIndex: 1000,
  backdropFilter: "blur(4px)"
};

const modalContentStil = {
  background: "white",
  padding: "30px",
  borderRadius: "12px",
  width: "550px",
  boxShadow: "0 10px 40px rgba(0,0,0,0.2)",
  maxHeight: "90vh",
  overflowY: "auto"
};

const labelStil = {
  display: "block",
  marginBottom: "5px",
  fontWeight: "bold",
  fontSize: "14px",
  color: "#333"
};

const formRowStil = {
  display: "flex",
  gap: "15px"
};

const inputStil = {
  width: "100%",
  padding: "10px",
  border: "1px solid #ddd",
  borderRadius: "6px",
  fontSize: "14px",
  boxSizing: "border-box"
};

const butonStil = {
  flex: 1,
  padding: "12px",
  borderRadius: "6px",
  border: "none",
  fontWeight: "bold",
  cursor: "pointer",
  background: "#0f3460",
  color: "white"
};

const closeButonStil = {
  background: "none",
  border: "none",
  fontSize: "24px",
  cursor: "pointer",
  color: "#999"
};
