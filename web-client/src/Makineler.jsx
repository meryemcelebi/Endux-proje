
import React, { useState } from "react";
import { QRCodeCanvas } from "qrcode.react";
import Sidebar from "./Sidebar";
import Navbar from "./Navbar";

export default function Makineler() {
  const [machines, setMachines] = useState([]);

  const [form, setForm] = useState({
    name: "",
    buyDate: "",
    price: "",
    lifetime: "",
    maintenance: "",
  });

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const addMachine = () => {
    if (!form.name) return;

    setMachines([
      { id: Date.now(), ...form },
      ...machines,
    ]);

    setForm({
      name: "",
      buyDate: "",
      price: "",
      lifetime: "",
      maintenance: "",
    });
  };

  return (
    <div>
      {/* ÜST NAVBAR */}
      <Navbar />

      <div style={{ display: "flex" }}>
        
        {/* SOL MENÜ */}
        <Sidebar />

        {/* ANA İÇERİK */}
        <div style={{ flex: 1, padding: "20px" }}>

          <div style={{ display: "flex", gap: "20px" }}>

            {/* SOL - LİSTE */}
            <div style={{ flex: 1 }}>
              <h2>Makine Listesi</h2>

              {machines.map((m) => (
                <div
                  key={m.id}
                  style={{
                    border: "1px solid #ddd",
                    padding: 10,
                    marginBottom: 10,
                    borderRadius: 8,
                    background: "#f9f9f9"
                  }}
                >
                  <h3>{m.name}</h3>

                  <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
                    <div>Alış Tarihi: {m.buyDate}</div>
                    <div>Fiyat: {m.price}</div>
                    <div>Ömür: {m.lifetime}</div>
                    <div>Bakım: {m.maintenance}</div>
                  </div>

                  <div style={{ marginTop: 10 }}>
                    <QRCodeCanvas value={JSON.stringify(m)} size={110} />
                  </div>
                </div>
              ))}
            </div>

            {/* SAĞ - FORM */}
            <div style={{ flex: 1 }}>
              <h2>Makine Ekle</h2>

              <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
                <input name="name" placeholder="Makine adı" value={form.name} onChange={handleChange} />
                <input name="buyDate" placeholder="Alış tarihi" value={form.buyDate} onChange={handleChange} />
                <input name="price" placeholder="Fiyat" value={form.price} onChange={handleChange} />
                <input name="lifetime" placeholder="Ömür (yıl)" value={form.lifetime} onChange={handleChange} />
                <input name="maintenance" placeholder="Bakım aralığı" value={form.maintenance} onChange={handleChange} />

                <button
                  onClick={addMachine}
                  style={{
                    padding: "10px",
                    background: "blue",
                    color: "white",
                    border: "none",
                    borderRadius: "6px",
                    cursor: "pointer"
                  }}
                >
                  Kaydet
                </button>
              </div>
            </div>

          </div>

        </div>
      </div>
    </div>
  );
}