/*import React from "react";
import { useParams } from "react-router-dom";

export default function Checklist() {
  const { id } = useParams();

  return (
    <div style={{ padding: 20 }}>
      <h2>🔧 Makine Checklist</h2>
      <p>Makine ID: {id}</p>

      <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        <p>Makine çalışıyor mu?</p>
        <p>Ses normal mi?</p>
        <p>Titreşim var mı?</p>
        <p>Yağ seviyesi yeterli mi?</p>
      </div>

      <button onClick={() => alert("Kaydedildi ✔")}>
        Tamamla
      </button>
    </div>
  );
}*/
import React, { useState } from "react";
import { useParams } from "react-router-dom";

export default function Checklist() {
  const { id } = useParams();

  const [items, setItems] = useState([
    { text: "Makine çalışıyor mu?", value: null },
    { text: "Ses normal mi?", value: null },
    { text: "Titreşim var mı?", value: null },
    { text: "Yağ seviyesi yeterli mi?", value: null },
  ]);

  const [saved, setSaved] = useState(false);

  const setValue = (index, val) => {
    const copy = [...items];
    copy[index].value = val;
    setItems(copy);
    setSaved(false); // değişiklik olunca tekrar kaydedilmemiş olur
  };

  const saveChecklist = () => {
    const data = {
      machineId: id,
      date: new Date().toISOString(),
      results: items,
    };

    // 💾 şimdilik localStorage'a kaydediyoruz
    localStorage.setItem(`checklist-${id}`, JSON.stringify(data));

    setSaved(true);
    alert("Checklist kaydedildi ✔");
  };

  return (
    <div style={{ padding: 20 }}>

      <h2>Checklist</h2>
      <p>Makine ID: {id}</p>

      {items.map((item, i) => (
        <div key={i} style={{ marginBottom: 15 }}>
          <p>{item.text}</p>

          <button
            onClick={() => setValue(i, "EVET")}
            style={{
              marginRight: 10,
              background: item.value === "EVET" ? "green" : "#d8d5e5ff",
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

      {/* 🔥 KAYDET BUTONU */}
      <button
        onClick={saveChecklist}
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