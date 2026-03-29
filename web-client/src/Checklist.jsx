import React, { useState } from "react";
import { useParams } from "react-router-dom";

export default function Checklist() { 
  const { id } = useParams();

  const FORM_ID = 1; // Backend için örnek form kimliği
  
  // Mock 'kontrol_maddesi' array (Veritabanı bazlı yapı)
  const [kontrolMaddeleri] = useState([
    { madde_id: 101, metin: "Makine çalışıyor mu?" },
    { madde_id: 102, metin: "Ses normal mi?" },
    { madde_id: 103, metin: "Titreşim var mı?" },
    { madde_id: 104, metin: "Yağ seviyesi yeterli mi?" },
  ]);

  // Prisma 'form_madde_cevap' formatına uyumlu state listesi 
  const [cevaplar, setCevaplar] = useState([]);
  const [saved, setSaved] = useState(false);

  const setCevap = (madde_id, cevapBool) => {
    const existing = cevaplar.find(c => c.madde_id === madde_id);
    if (existing) {
      setCevaplar(cevaplar.map(c => c.madde_id === madde_id ? { ...c, cevap: cevapBool } : c));
    } else {
      setCevaplar([...cevaplar, { form_id: FORM_ID, madde_id: madde_id, cevap: cevapBool }]);
    }
    setSaved(false);
  };

  const saveChecklist = () => {
    if (cevaplar.length !== kontrolMaddeleri.length) {
      alert("Lütfen tüm soruları yanıtlayın!");
      return;
    }
    
    // Backend API'a iletilmesi planlanan yapı
    const payload = {
      makine_id: id,
      tarih: new Date().toISOString(),
      form_madde_cevap: cevaplar
    };

    localStorage.setItem(`checklist-${id}`, JSON.stringify(payload));
    console.log("Backend'e Gönderilecek Payload:", payload);

    setSaved(true);
    alert("Checklist formatlanarak kaydedildi ✔");
  };

  return (
    <div style={sayfaStil}>
      <div style={konteynerStil}>

        {/* BAŞLIK */}
        <div style={baslikStil}>
          <h2 style={{ margin: 0, color: "white", fontSize: "22px" }}> Operatör Checklist</h2>
          <div style={etiketStil}>Makine ID: {id}</div>
        </div>

        {/* CHECKLIST KART */}
        <div style={kartStil}>
          <h3 style={{ color: "navy", marginTop: 0, marginBottom: "20px", fontSize: "18px" }}>
            Kontrol Soruları
          </h3>

          {kontrolMaddeleri.map((madde, i) => {
            const mevcutCevap = cevaplar.find(c => c.madde_id === madde.madde_id)?.cevap;

            return (
              <div key={madde.madde_id} style={soruSatirStil}>
                <span style={soruTextStil}>{i + 1}. {madde.metin}</span>

                <div style={{ display: "flex", gap: "10px" }}>
                  <button
                    onClick={() => setCevap(madde.madde_id, true)}
                    style={{
                      ...cevapButonStil,
                      background: mevcutCevap === true ? "#2e7d32" : "#f5f5f5",
                      color: mevcutCevap === true ? "white" : "#333",
                      border: mevcutCevap === true ? "2px solid #2e7d32" : "2px solid #ddd",
                    }}
                  >
                    ✓ EVET
                  </button>

                  <button
                    onClick={() => setCevap(madde.madde_id, false)}
                    style={{
                      ...cevapButonStil,
                      background: mevcutCevap === false ? "#c62828" : "#f5f5f5",
                      color: mevcutCevap === false ? "white" : "#333",
                      border: mevcutCevap === false ? "2px solid #c62828" : "2px solid #ddd",
                    }}
                  >
                    ✗ HAYIR
                  </button>
                </div>
              </div>
            );
          })}

          <button
            onClick={saveChecklist}
            style={{
              ...kaydetButonStil,
              background: saved ? "#2e7d32" : "navy",
            }}
          >
            {saved ? "✔ Kaydedildi" : "Kaydet"}
          </button>
        </div>
      </div>
    </div>
  );
}

/* STILLER */
const sayfaStil = {
  minHeight: "100vh",  //ekran boyu kadar yer kaplar
  background: "linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%)",
  padding: "30px",
  boxSizing: "border-box",
};

const konteynerStil = {
  maxWidth: "700px",  //ortalar
  margin: "0 auto",
};

const baslikStil = {   //üst başlık
  display: "flex",
  justifyContent: "space-between",
  alignItems: "center",
  marginBottom: "25px",
  padding: "20px 25px",
  background: "rgba(255,255,255,0.1)",
  borderRadius: "12px",
  backdropFilter: "blur(10px)",
};

const etiketStil = {
  padding: "6px 16px",
  background: "rgba(255,255,255,0.2)",
  color: "white",
  borderRadius: "20px",
  fontSize: "13px",
  fontWeight: "bold",
};

const kartStil = {
  background: "white",
  padding: "30px",
  borderRadius: "12px",
  boxShadow: "0 4px 20px rgba(0,0,0,0.15)",
};

const soruSatirStil = {
  display: "flex",
  justifyContent: "space-between",
  alignItems: "center",
  padding: "15px 20px",
  marginBottom: "12px",
  background: "#f8f9fa",
  borderRadius: "10px",
  borderLeft: "4px solid navy",
};

const soruTextStil = {
  fontWeight: "bold",
  color: "#333",
  fontSize: "15px",
};

const cevapButonStil = {
  padding: "8px 18px",
  borderRadius: "8px",
  cursor: "pointer",
  fontWeight: "bold",
  fontSize: "13px",
  transition: "all 0.2s",
};

const kaydetButonStil = {
  width: "100%",
  padding: "14px",
  color: "white",
  border: "none",
  borderRadius: "8px",
  fontSize: "16px",
  fontWeight: "bold",
  cursor: "pointer",
  marginTop: "20px",
};