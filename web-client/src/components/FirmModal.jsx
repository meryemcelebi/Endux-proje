import React, { useState } from "react";

// Yeni firma (Tedarikçi veya Servis) eklemek için kullanılan Modal bileşeni
export default function FirmModal({ isOpen, onClose, onSave, initialType = "Servis" }) {
  // Form verilerini tutan state
  const [form, setForm] = useState({
    ad: "",
    tip: initialType,
    telefon: "",
    email: "",
    adres: "",
    uzmanlik_alani: "",
    sorumlu_ad: "",
    sorumlu_soyad: "",
    sorumlu_telefon: "",
    yetkili_kisi: "",
    veri_no: "",
    guvenilirlik_skoru: ""
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
      yetkili_kisi: "", veri_no: "", guvenilirlik_skoru: ""
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
            <div style={{ background: "#f8f9fa", padding: "15px", borderRadius: "8px", border: "1px solid #e1e5eb" }}>
              <h4 style={{ margin: "0 0 10px 0", color: "#34495e", fontSize: "14px" }}>Servis & Teknisyen Detayları</h4>
              
              <div style={{ marginBottom: "12px" }}>
                <label style={labelStil}>Uzmanlık Alanı</label>
                <input type="text" name="uzmanlik_alani" value={form.uzmanlik_alani} onChange={handleChange} style={inputStil} placeholder="Örn: CNC Mekaniği, Motor Revizyon" />
              </div>

              <div style={formRowStil}>
                <div style={{ flex: 1 }}>
                  <label style={labelStil}>Teknisyen (Sorumlu) Adı</label>
                  <input type="text" name="sorumlu_ad" value={form.sorumlu_ad} onChange={handleChange} style={inputStil} placeholder="Örn: Ahmet" />
                </div>
                <div style={{ flex: 1 }}>
                  <label style={labelStil}>Teknisyen Soyadı</label>
                  <input type="text" name="sorumlu_soyad" value={form.sorumlu_soyad} onChange={handleChange} style={inputStil} placeholder="Örn: Yılmaz" />
                </div>
              </div>
              
              <div style={{ marginTop: "12px" }}>
                <label style={labelStil}>Teknisyen Cep Telefonu</label>
                <input type="text" name="sorumlu_telefon" value={form.sorumlu_telefon} onChange={handleChange} style={inputStil} placeholder="Örn: 05XX..." />
              </div>
            </div>
          )}

          {form.tip === "Tedarikçi" && (
            <div style={{ background: "#f0f7ff", padding: "15px", borderRadius: "8px", border: "1px solid #cce3ff" }}>
              <h4 style={{ margin: "0 0 10px 0", color: "#0056b3", fontSize: "14px" }}>Tedarikçi Ek Bilgileri</h4>
              
              <div style={{ marginBottom: "12px" }}>
                <label style={labelStil}>Yetkili Kişi</label>
                <input type="text" name="yetkili_kisi" value={form.yetkili_kisi} onChange={handleChange} style={inputStil} placeholder="Örn: Mehmet Özsoy" />
              </div>

              <div style={formRowStil}>
                <div style={{ flex: 1 }}>
                  <label style={labelStil}>Veri / Vergi No</label>
                  <input type="text" name="veri_no" value={form.veri_no} onChange={handleChange} style={inputStil} placeholder="Örn: TR123..." />
                </div>
                <div style={{ flex: 1 }}>
                  <label style={labelStil}>Güvenilirlik Skoru (0-100)</label>
                  <input type="number" name="guvenilirlik_skoru" value={form.guvenilirlik_skoru} onChange={handleChange} style={inputStil} placeholder="Örn: 90" min="0" max="100" />
                </div>
              </div>
            </div>
          )}

          <div>
            <label style={labelStil}>Firma Adresi</label>
            <textarea name="adres" value={form.adres} onChange={handleChange} style={{ ...inputStil, height: "60px" }} />
          </div>

          <div style={{ display: "flex", gap: "10px", marginTop: "10px" }}>
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
