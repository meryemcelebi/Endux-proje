
import React, { useState } from "react";
import { QRCodeCanvas } from "qrcode.react";
import Sidebar from "./Sidebar";
import Navbar from "./Navbar";

export default function Makineler() {
  const [machines, setMachines] = useState([]);

  const [form, setForm] = useState({
    firmaid: "",
    makineqr: "",
    makinead: "",
    satinAlmaTarihi: "",
    satinAlmaMaliyeti: "",
    toplamCalismaSaati: "",
    makineOzellikleri: "",
    mevcutRiskSkoru: "",
    mevcutRiskSeviyesi: "",
    aktiflikDurumu: "",
    geciciMakineTurAdi: "",
    geciciFirmaAdi: "",
    seriNo: "",
    geciciRiskKatsayisi: "",
  });

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const addMachine = () => {
    if (!form.makinead) return;

    const yeniMakine = {
      ...form,
      id: Date.now(),
      makineid: Date.now().toString(), /*otomatik benzersiz ID*/
      geciciTurAciklama: "", /*otomatik boş*/
    };

    setMachines([
      yeniMakine,
      ...machines,
    ]);

    setForm({
      firmaid: "",
      makineqr: "",
      makinead: "",
      satinAlmaTarihi: "",
      satinAlmaMaliyeti: "",
      toplamCalismaSaati: "",
      makineOzellikleri: "",
      mevcutRiskSkoru: "",
      mevcutRiskSeviyesi: "",
      aktiflikDurumu: "",
      geciciMakineTurAdi: "",
      geciciFirmaAdi: "",
      seriNo: "",
      geciciRiskKatsayisi: "",
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
                    border: "1px solid #f5f6faff",
                    padding: 10,
                    marginBottom: 10,
                    borderRadius: 8,
                    background: "#f9f9f9",
                    color: "black"
                  }}
                >
                  <h3>{m.makinead}</h3>

                  <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
                    <div>Makine ID: {m.makineid}</div>
                    <div>Firma ID: {m.firmaid}</div>
                    <div>Makine QR: {m.makineqr}</div>
                    <div>Satın Alma Tarihi: {m.satinAlmaTarihi}</div>
                    <div>Satın Alma Maliyeti: {m.satinAlmaMaliyeti}</div>
                    <div>Toplam Çalışma Saati: {m.toplamCalismaSaati}</div>
                    <div>Makine Özellikleri: {m.makineOzellikleri}</div>
                    <div>Mevcut Risk Skoru: {m.mevcutRiskSkoru}</div>
                    <div>Mevcut Risk Seviyesi: {m.mevcutRiskSeviyesi}</div>
                    <div>Aktiflik Durumu: {m.aktiflikDurumu}</div>
                    <div>Geçici Makine Tür Adı: {m.geciciMakineTurAdi}</div>
                    <div>Geçici Firma Adı: {m.geciciFirmaAdi}</div>
                    <div>Seri No: {m.seriNo}</div>
                    <div>Geçici Risk Katsayısı: {m.geciciRiskKatsayisi}</div>
                    <div>Geçici Tür Açıklama: {m.geciciTurAciklama}</div>
                  </div>

                  <div style={{ marginTop: 10 }} className={`qr-container-${m.id}`}>
                    <QRCodeCanvas value={JSON.stringify(m)} size={110} />
                    <br />
                    <button
                      onClick={() => {
                        const container = document.querySelector(`.qr-container-${m.id}`);
                        const canvas = container?.querySelector('canvas');
                        if (!canvas) return;
                        const imgData = canvas.toDataURL('image/png');
                        const printWindow = window.open('', '_blank');
                        printWindow.document.write(`
                          <html>
                            <head><title>QR Kod Çıktısı - ${m.makinead}</title></head>
                            <body style="display:flex; flex-direction:column; align-items:center; justify-content:center; height:100vh; margin:0;">
                              <h2>${m.makinead} - QR Kod</h2>
                              <img src="${imgData}" style="width:200px; height:200px;" />
                              <p style="font-size:12px; color:gray; margin-top:10px;">Makine ID: ${m.makineid}</p>
                            </body>
                          </html>
                        `);
                        printWindow.document.close();
                        printWindow.focus();
                        printWindow.print();
                        printWindow.close();
                      }}
                      style={{
                        marginTop: '8px',
                        padding: '6px 14px',
                        background: 'darkslategray',
                        color: 'white',
                        border: 'none',
                        borderRadius: '6px',
                        cursor: 'pointer',
                        fontWeight: 'bold',
                        fontSize: '12px'
                      }}
                    >
                      Çıktı Al
                    </button>
                  </div>
                </div>
              ))}
            </div>

            {/* SAĞ - FORM */}
            <div style={{ flex: 1 }}>
              <h2>Makine Ekle</h2>

              <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>

                <input name="firmaid" placeholder="Firma ID" value={form.firmaid} onChange={handleChange} />
                <input name="makineqr" placeholder="Makine QR" value={form.makineqr} onChange={handleChange} />
                <input name="makinead" placeholder="Makine Adı" value={form.makinead} onChange={handleChange} />
                <input name="satinAlmaTarihi" placeholder="Satın Alma Tarihi" value={form.satinAlmaTarihi} onChange={handleChange} />
                <input name="satinAlmaMaliyeti" placeholder="Satın Alma Maliyeti" value={form.satinAlmaMaliyeti} onChange={handleChange} />
                <input name="toplamCalismaSaati" placeholder="Toplam Çalışma Saati" value={form.toplamCalismaSaati} onChange={handleChange} />
                <input name="makineOzellikleri" placeholder="Makine Özellikleri" value={form.makineOzellikleri} onChange={handleChange} />
                <input name="mevcutRiskSkoru" placeholder="Mevcut Risk Skoru" value={form.mevcutRiskSkoru} onChange={handleChange} />
                <input name="mevcutRiskSeviyesi" placeholder="Mevcut Risk Seviyesi" value={form.mevcutRiskSeviyesi} onChange={handleChange} />
                <input name="aktiflikDurumu" placeholder="Aktiflik Durumu" value={form.aktiflikDurumu} onChange={handleChange} />
                <input name="geciciMakineTurAdi" placeholder="Geçici Makine Tür Adı" value={form.geciciMakineTurAdi} onChange={handleChange} />
                <input name="geciciFirmaAdi" placeholder="Geçici Firma Adı" value={form.geciciFirmaAdi} onChange={handleChange} />
                <input name="seriNo" placeholder="Seri No" value={form.seriNo} onChange={handleChange} />
                <input name="geciciRiskKatsayisi" placeholder="Geçici Risk Katsayısı" value={form.geciciRiskKatsayisi} onChange={handleChange} />


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