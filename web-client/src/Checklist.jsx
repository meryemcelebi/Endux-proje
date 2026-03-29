
import React, { useState } from "react";
import { useParams } from "react-router-dom";

export default function Checklist() { /*Checklist adında component oluşturulur*/
  const { id } = useParams();        /*urlden gelen id alınır*/

  const [items, setItems] = useState([   /*checklist sorularını tutar*/
    { text: "Makine çalışıyor mu?", value: null },
    { text: "Ses normal mi?", value: null },
    { text: "Titreşim var mı?", value: null },
    { text: "Yağ seviyesi yeterli mi?", value: null },
  ]);

  const [saved, setSaved] = useState(false); /*kaydedildi mi bilgisini tutar*/

  const setValue = (index, val) => {  /*Bir sorunun cevabını güncelleyen fonksiyon*/
    const copy = [...items];     /*tems array'inin kopyası alınır (direkt değiştirmemek için)*/
    copy[index].value = val;     /*seçilen sorunun value'su değiştirilir*/
    setItems(copy);              /*state güncellenir*/
    setSaved(false); // değişiklik olunca tekrar kaydedilmemiş olur
  };

  const saveChecklist = () => {   // Checklist'i kaydeden fonksiyon
    const data = {                // kaydedilecek veri hazırlanır
      machineId: id,               // hangi makineye ait (URL'den gelen id)
      date: new Date().toISOString(),  // kaydedilme zamanı 
      results: items,                // tüm sorular ve cevaplar
    };

    //  şimdilik localStorage'a kaydediyoruz
    localStorage.setItem(`checklist-${id}`, JSON.stringify(data));   // veriyi tarayıcıya kaydeder

    setSaved(true);                    // kaydedildi durumunu true yapar
    alert("Checklist kaydedildi ✔");  // kullanıcıya uyarı verir
  };

  return (
    <div style={sayfaStil}>   {/*arka plan*/}
      <div style={konteynerStil}> {/*içeriği ortalar*/}

        {/* BAŞLIK */}
        <div style={baslikStil}>
          <h2 style={{ margin: 0, color: "white", fontSize: "22px" }}> Operatör Checklist</h2>
          <div style={etiketStil}>Makine ID: {id}</div>    {/*makine idsini yanda veriri*/}
        </div>

        {/* CHECKLIST KART */}
        <div style={kartStil}>
          <h3 style={{ color: "navy", marginTop: 0, marginBottom: "20px", fontSize: "18px" }}>
            Kontrol Soruları
          </h3>

          {items.map((item, i) => (       // tüm sorular üzerinde dönülür
            <div key={i} style={soruSatirStil}>
              <span style={soruTextStil}>{i + 1}. {item.text}</span> {/*soru listesi*/}

              <div style={{ display: "flex", gap: "10px" }}>
                <button
                  onClick={() => setValue(i, "EVET")}
                  style={{
                    ...cevapButonStil,
                    background: item.value === "EVET" ? "#2e7d32" : "#f5f5f5",
                    color: item.value === "EVET" ? "white" : "#333",
                    border: item.value === "EVET" ? "2px solid #2e7d32" : "2px solid #ddd",
                  }}
                >
                  ✓ EVET
                </button>

                <button
                  onClick={() => setValue(i, "HAYIR")}
                  style={{
                    ...cevapButonStil,
                    background: item.value === "HAYIR" ? "#c62828" : "#f5f5f5",
                    color: item.value === "HAYIR" ? "white" : "#333",
                    border: item.value === "HAYIR" ? "2px solid #c62828" : "2px solid #ddd",
                  }}
                >
                  ✗ HAYIR
                </button>
              </div>
            </div>
          ))}

          {/*  KAYDET BUTONU */}
          <button
            onClick={saveChecklist}     // tıklanınca kaydet fonksiyonu çalışır
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