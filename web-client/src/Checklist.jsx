
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
    <div style={{ padding: 20 }}>

      <h2>Checklist</h2>
      <p>Makine ID: {id}</p>

      {items.map((item, i) => (       // tüm sorular üzerinde dönülür
        <div key={i} style={{ marginBottom: 15 }}>   
          <p>{item.text}</p>           {/* soru metni gösterilir*/}

          <button
            onClick={() => setValue(i, "EVET")}
            style={{
              marginRight: 10,
              background: item.value === "EVET" ? "green" : "#d8d5e5ff",  // eğer EVET seçildiyse yeşil olur
              color: item.value === "EVET" ? "white" : "black",
              padding: 8
            }}
          >
            EVET
          </button>

          <button
            onClick={() => setValue(i, "HAYIR")}
            style={{
              background: item.value === "HAYIR" ? "red" : "#d8d5e5ff",  
              color: item.value === "HAYIR" ? "white" : "black",
              padding: 8
            }}
          >
            HAYIR
          </button>
        </div>
      ))}

      {/*  KAYDET BUTONU */}  
      <button
        onClick={saveChecklist}     // tıklanınca kaydet fonksiyonu çalışır
        style={{
          marginTop: 20,
          padding: "10px 20px",
          background: saved ? "green" : "#5134e1ff",
          color: "white",
          border: "none",
          borderRadius: 8,
          cursor: "pointer"
        }}
      >
        {saved ? "Kaydedildi ✔" : "Kaydet"}
      </button>

    </div>
  );
}