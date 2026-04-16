import React, { useState, useEffect } from "react";
import { useParams } from "react-router-dom";
import { api } from "./services/api";

/**
 * Operatör Checklist Sayfası
 * Operatörlerin makineler için günlük kontrol formlarını doldurduğu ekrandır.
 */
export default function Checklist() {
  const { id } = useParams(); // URL'den makine ID'sini al

  const FORM_ID = 1; // Backend için örnek form kimliği
  const SABLON_ID = 1; // Backend için örnek şablon ID

  // --- STATE TANIMLAMALARI ---
  const [kontrolMaddeleri, setKontrolMaddeleri] = useState([]); // API'den gelen günlük kontrol soruları listesi
  const [cevaplar, setCevaplar] = useState([]); // Kullanıcının sorulara verdiği cevaplar (EVET/HAYIR)
  const [genelNot, setGenelNot] = useState(""); // Operatörün eklemek istediği özel not veya arıza bildirimi

  // Sayfa yüklendiğinde kontrol sorularını getir
  useEffect(() => {
    const fetchQuestions = async () => {
      try {
        const data = await api.getChecklistQuestions(SABLON_ID);
        setKontrolMaddeleri(data);
      } catch (err) {
        console.error("Sorular yüklenemedi", err);
      }
    };
    fetchQuestions();
  }, [SABLON_ID]);

  const [saved, setSaved] = useState(false); // Kayıt durumu kontrolü

  // --- CEVAP KAYDETME MANTIĞI ---
  // Operatör bir soruya tıkladığında cevabı state içinde günceller veya yeni ekler.
  const setCevap = (madde_id, cevapBool) => {
    const girilenDeger = cevapBool ? "EVET" : "HAYIR";
    const durumDeger = "BEKLEMEDE"; // Varsayılan durum

    const existing = cevaplar.find(c => c.madde_id === madde_id);
    if (existing) {
      // Eğer daha önce cevap verilmişse üzerine yaz
      setCevaplar(cevaplar.map(c => c.madde_id === madde_id ? { ...c, girilen_deger: [girilenDeger], durum: [durumDeger], rawVal: cevapBool } : c));
    } else {
      // Yeni madde cevabı ekle
      setCevaplar([...cevaplar, { form_id: FORM_ID, madde_id: madde_id, girilen_deger: [girilenDeger], durum: [durumDeger], rawVal: cevapBool }]);
    }
    setSaved(false);
  };

  // Formu API'ye gönderen fonksiyon
  const saveChecklist = async () => {
    if (cevaplar.length !== kontrolMaddeleri.length) {
      alert("Lütfen tüm soruları yanıtlayın!");
      return;
    }

    // API'nin beklediği veri yapısına dönüştürme
    const answersPayload = cevaplar.map(c => ({
      form_id: c.form_id,
      madde_id: c.madde_id,
      girilen_deger: c.girilen_deger,
      durum: c.durum,
      aciklama: []
    }));

    const payload = {
      makine_id: Number(id),
      kullanici_id: 1, // Mock kullanıcı (Login'den gelecek)
      sablon_id: SABLON_ID,
      kontrol_tarihi: [new Date().toISOString()],
      genel_not: [genelNot],
      ai_on_risk_durumu: [],
      form_madde_cevap: answersPayload
    };

    try {
      await api.submitChecklist(payload);
      setSaved(true);
      alert("Checklist API'ye gönderildi ve kaydedildi ✔");
    } catch (err) {
      console.error("Checklist kaydedileedi", err);
    }
  };

  return (
    <div style={sayfaStil}>
      <div style={konteynerStil}>

        {/* BAŞLIK VE ETİKET */}
        <div style={baslikStil}>
          <h2 style={{ margin: 0, color: "white", fontSize: "22px" }}> Operatör Checklist</h2>
          <div style={etiketStil}>Makine ID: {id}</div>
        </div>

        {/* --- KONTROL SORULARI LİSTESİ --- */}
        <div style={kartStil}>
          <h3 style={{ color: "navy", marginTop: 0, marginBottom: "20px", fontSize: "18px" }}>
            Kontrol Soruları
          </h3>

          {kontrolMaddeleri.map((madde, i) => {
            const soruMetni = Array.isArray(madde.madde_adi) ? madde.madde_adi[0] : madde.madde_adi;
            const mevcutCevap = cevaplar.find(c => c.madde_id === madde.madde_id)?.rawVal;

            return (
              <div key={madde.madde_id} style={soruSatirStil}>
                <span style={soruTextStil}>{i + 1}. {soruMetni || "Soru?"}</span>

                {/* Evet / Hayır Seçenekleri */}
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

          {/* --- ACİL DURUM / OPERATÖR NOTU KUTUSU --- */}
          <div style={notKonteynerStil}>
            <label style={notEtiketStil}>
              <span style={{ marginRight: "8px" }}>⚠️</span>
              Acil Durum / Yapılan İşlem Açıklaması
            </label>
            <textarea
              style={notTextareaStil}
              placeholder="Eğer bir parça değiştirdiyseniz veya acil bir durum oluştuysa buraya detaylıca yazınız..."
              value={genelNot}
              onChange={(e) => setGenelNot(e.target.value)}
            />
          </div>

          {/* Formu Kaydet Butonu */}
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

// --- GÖRSEL STİLLER ---
const sayfaStil = {
  minHeight: "100vh",
  background: "linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%)",
  padding: "30px",
  boxSizing: "border-box",
};

const konteynerStil = {
  maxWidth: "700px",
  margin: "0 auto",
};

const baslikStil = {
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

const notKonteynerStil = {
  marginTop: "25px",
  padding: "15px",
  background: "#fff3f3",
  borderRadius: "10px",
  border: "1px solid #ffcdd2",
};

const notEtiketStil = {
  display: "block",
  marginBottom: "10px",
  color: "#c62828",
  fontWeight: "bold",
  fontSize: "14px",
};

const notTextareaStil = {
  width: "100%",
  height: "100px",
  padding: "12px",
  boxSizing: "border-box",
  borderRadius: "8px",
  border: "1px solid #ddd",
  fontSize: "14px",
  fontFamily: "inherit",
  resize: "vertical",
  outline: "none",
  transition: "border-color 0.2s",
};
