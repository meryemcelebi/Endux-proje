import React, { useState } from "react";
import { useParams } from "react-router-dom";

export default function Servis() {
  const { id } = useParams();

  //  geçmiş kayıtlar (örnek veri)
  const [history, setHistory] = useState([  //servis geçmişi listesi
    {
      date: "2026-03-20",
      action: "Motor bakımı yapıldı",
      note: "Yağ değişimi ve genel kontrol tamamlandı",
    },
    {
      date: "2026-03-10",
      action: "Sensör değişimi",
      note: "Hatalı sensör yenisi ile değiştirildi",
    },
  ]);

  //  yeni kayıt
  const [action, setAction] = useState(""); //işlem adı
  const [note, setNote] = useState("");     //detay

  const addRecord = () => {                //yeni servis ekleme fonksiyonu
    if (!action || !note) {
      alert("Tüm alanları doldur !");
      return;
    }

    const newRecord = {
      date: new Date().toISOString().split("T")[0],     //.split("T")[0]sadece gün kısmını alır
      action,
      note,
    };

    setHistory([newRecord, ...history]);
    setAction("");
    setNote("");
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
                  <div style={{ fontWeight: "bold", color: "navy", fontSize: "15px", marginTop: "8px" }}>{item.action}</div>
                  <p style={{ margin: 0, color: "#555", fontSize: "14px", marginTop: "6px" }}>{item.note}</p>
                </div>
              ))}
            </div>
          </div>

          {/* SAĞ - YENİ KAYIT */}
          <div style={yeniKayitAlaniStil}>
            <h3 style={baslikStil}>Yeni Servis Kaydı</h3>

            <div style={{ marginBottom: "15px" }}>
              <label style={labelStil}>Yapılan İşlem</label>
              <input
                type="text"
                placeholder="örn: motor değişimi"
                value={action}
                onChange={(e) => setAction(e.target.value)}
                style={inputStil}
              />
            </div>

            <div style={{ marginBottom: "20px" }}>
              <label style={labelStil}>Detay Not</label>
              <textarea
                placeholder="İşlem hakkında detay yazın..."
                value={note}
                onChange={(e) => setNote(e.target.value)}
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