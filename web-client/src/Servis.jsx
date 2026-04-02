import React, { useState } from "react";
import { useParams } from "react-router-dom";

export default function Servis() {
  const { id } = useParams();

  const [history, setHistory] = useState([
    {
      date: "2026-03-20",
      kullanici_id: 1,
      firma_id: 2,
      ariza_sebebi: "Genel Bakım",
      bakim_maliyeti: 1500,
      aciklama: "Yağ değişimi ve genel kontrol tamamlandı",
    },
    {
      date: "2026-03-10",
      kullanici_id: 2,
      firma_id: 1,
      ariza_sebebi: "Sensör Hatası",
      bakim_maliyeti: 800,
      aciklama: "Hatalı sensör yenisi ile değiştirildi",
    },
  ]);

  const [form, setForm] = useState({
    kullanici_id: "",
    firma_id: "",
    ariza_sebebi: "",
    bakim_maliyeti: "",
    aciklama: ""
  });

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const addRecord = () => {
    if (!form.kullanici_id || !form.firma_id || !form.ariza_sebebi || !form.bakim_maliyeti || !form.aciklama) {
      alert("Tüm alanları doldur!");
      return;
    }

    const newRecord = {
      date: new Date().toISOString().split("T")[0],
      kullanici_id: Number(form.kullanici_id),
      firma_id: Number(form.firma_id),
      ariza_sebebi: form.ariza_sebebi,
      bakim_maliyeti: Number(form.bakim_maliyeti),
      aciklama: form.aciklama,
    };

    setHistory([newRecord, ...history]);
    setForm({ kullanici_id: "", firma_id: "", ariza_sebebi: "", bakim_maliyeti: "", aciklama: "" });
  };

  return (
    <div style={sayfaStil}>
      <div style={containerStil}>
        {/* BAŞLIK */}
        <div style={headerStil}>
          <h2 style={{ margin: 0, color: "white", fontSize: "22px" }}>Teknik Servis Paneli</h2>
          <div style={badgeStil}>Makine ID: {id}</div>
        </div>

        <div style={icerikStil}>
          {/* SOL - GEÇMİŞ KAYITLAR */}
          <div style={{ flex: 1 }}>
            <h3 style={{ ...baslikStil, color: "white" }}>Geçmiş İşlemler</h3>
            <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
              {history.map((item, index) => (
                <div key={index} style={kayitKartStil}>
                  <div style={tarihStil}>{item.date}</div>
                  <div style={{ fontWeight: "bold", color: "navy", fontSize: "15px", marginTop: "8px" }}>
                    Firma: {item.firma_id} | Sebep: {item.ariza_sebebi} | Maliyet: {item.bakim_maliyeti} ₺
                  </div>
                  <p style={{ margin: 0, color: "#555", fontSize: "14px", marginTop: "6px" }}>{item.aciklama}</p>
                </div>
              ))}
            </div>
          </div>

          {/* SAĞ - YENİ BAKIM KAYDI */}
          <div style={yeniKayitAlaniStil}>
            <h3 style={baslikStil}>Yeni Bakım Kaydı</h3>

            {/* 1. İşlemi Yapan (kullanici_id) */}
            <div style={{ marginBottom: "15px" }}>
              <label style={labelStil}>İşlemi Yapan (Kullanıcı ID)</label>
              <input
                type="number"
                name="kullanici_id"
                placeholder="Kullanıcı ID giriniz"
                value={form.kullanici_id}
                onChange={handleChange}
                style={inputStil}
              />
            </div>

            {/* 2. Servis Şirketi (firma_id) */}
            <div style={{ marginBottom: "15px" }}>
              <label style={labelStil}>Servis Şirketi (Firma ID)</label>
              <input
                type="number"
                name="firma_id"
                placeholder="Firma ID giriniz"
                value={form.firma_id}
                onChange={handleChange}
                style={inputStil}
              />
            </div>

            {/* 3. Neden Yapıldığı (ariza_sebebi) */}
            <div style={{ marginBottom: "15px" }}>
              <label style={labelStil}>Arıza Sebebi</label>
              <input
                type="text"
                name="ariza_sebebi"
                placeholder="Örn: Sensör Hatası, Periyodik Bakım"
                value={form.ariza_sebebi}
                onChange={handleChange}
                style={inputStil}
              />
            </div>

            {/* 4. Maliyet (bakim_maliyeti) */}
            <div style={{ marginBottom: "15px" }}>
              <label style={labelStil}>Maliyet (Bakım Maliyeti)</label>
              <input
                type="number"
                name="bakim_maliyeti"
                placeholder="₺ maliyet giriniz"
                value={form.bakim_maliyeti}
                onChange={handleChange}
                style={inputStil}
              />
            </div>

            {/* 5. Açıklama */}
            <div style={{ marginBottom: "20px" }}>
              <label style={labelStil}>Açıklama</label>
              <textarea
                name="aciklama"
                placeholder="Bakım hakkında açıklama yazın..."
                value={form.aciklama}
                onChange={handleChange}
                style={{ ...inputStil, height: "100px", resize: "vertical" }}
              />
            </div>

            <button onClick={addRecord} style={butonStil}>Kaydı Ekle</button>
          </div>
        </div>
      </div>
    </div>
  );
}

/* STILLER */
const sayfaStil = {
  minHeight: "100vh",
  background: "linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%)",
  padding: "30px",
  boxSizing: "border-box",
};

const containerStil = {
  maxWidth: "1100px",
  margin: "0 auto",
};

const headerStil = {
  display: "flex",
  justifyContent: "space-between",
  alignItems: "center",
  marginBottom: "25px",
  padding: "20px 25px",
  background: "rgba(255,255,255,0.1)",
  borderRadius: "12px",
  backdropFilter: "blur(10px)",
};

const badgeStil = {
  padding: "6px 16px",
  background: "rgba(255,255,255,0.2)",
  color: "white",
  borderRadius: "20px",
  fontSize: "13px",
  fontWeight: "bold",
};

const icerikStil = {
  display: "flex",
  gap: "25px",
};

const baslikStil = {
  color: "navy",
  marginTop: 0,
  marginBottom: "15px",
  fontSize: "18px",
};

const kayitKartStil = {
  background: "white",
  padding: "15px 20px",
  borderRadius: "10px",
  boxShadow: "0 2px 10px rgba(0,0,0,0.08)",
  borderLeft: "4px solid navy",
};

const tarihStil = {
  fontSize: "13px",
  color: "white",
  background: "navy",
  padding: "6px 14px",
  borderRadius: "6px",
  fontWeight: "bold",
  display: "inline-block",
  letterSpacing: "0.5px",
};

const yeniKayitAlaniStil = {
  width: "380px",
  flexShrink: 0,
  background: "white",
  padding: "25px",
  borderRadius: "12px",
  boxShadow: "0 4px 20px rgba(0,0,0,0.1)",
  alignSelf: "flex-start",
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
  fontFamily: "inherit",
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