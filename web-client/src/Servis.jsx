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
    <div style={{ padding: 20 }}>
      <h2> Teknik Servis Paneli</h2>
      <p>Makine ID: {id}</p>

      {/*  GEÇMİŞ KAYITLAR */}
      <h3> Geçmiş İşlemler</h3>
      <div style={{ marginBottom: 20 }}>
        {history.map((item, index) => (
          <div
            key={index}
            style={{
              border: "1px solid #ccc",
              padding: 10,
              marginBottom: 10,
              borderRadius: 6,
            }}
          >
            <b>{item.date}</b>
            <p> {item.action}</p>
            <p> {item.note}</p>
          </div>
        ))}
      </div>

      {/*  YENİ KAYIT */}
      <h3> Yeni Servis Kaydı</h3>

      <input
        type="text"
        placeholder="Yapılan işlem (örn: motor değişimi)"
        value={action}
        onChange={(e) => setAction(e.target.value)}
        style={{ display: "block", marginBottom: 10, width: "300px" }}
      />

      <textarea
        placeholder="Detay not"
        value={note}
        onChange={(e) => setNote(e.target.value)}
        style={{ display: "block", marginBottom: 10, width: "300px", height: 80 }}
      />

      <button onClick={addRecord}>Kaydı Ekle</button>
    </div>
  );
}