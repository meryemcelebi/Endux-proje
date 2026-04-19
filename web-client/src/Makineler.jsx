import React, { useState, useEffect } from "react";
import { QRCodeCanvas } from "qrcode.react";
import { useNavigate } from "react-router-dom";
import Sidebar from "./Sidebar";
import Navbar from "./Navbar";
import { api } from "./services/api";

/**
 * Makineler Sayfası
 * Fabrikadaki tüm makinelerin listelendiği, filtrelendiği 
 * ve yeni makine eklemesinin yapıldığı ana yönetim ekranıdır.
 * Her makine için QR kod oluşturma ve çıktı alma özelliği sunar.
 */
export default function Makineler() {
  const navigate = useNavigate();
  const [filter, setFilter] = useState("Tümü"); // Liste filtresi (Aktif, Bakımda, Arızalı vb.)
  const [expandedMachineId, setExpandedMachineId] = useState(null); // Detayı açık olan makine ID
  const [searchTerm, setSearchTerm] = useState(""); // Arama terimi
  const [filterKat, setFilterKat] = useState(""); // Kat filtresi
  const [filterLokasyon, setFilterLokasyon] = useState(""); // Lokasyon filtresi

  const [machines, setMachines] = useState([]); // API'den gelen makineler

  // --- VERİ ÇEKME SÜRECİ ---
  // Uygulama yüklendiğinde makineleri API'den çeker ve UI için formatlar
  useEffect(() => {
    const fetchMachines = async () => {
      try {
        const data = await api.getMachines();
        // API'den gelen veriyi yerel state'e uygun hale getir (ID ve durum eşleştirmesi)
        const formattedData = data.map(m => ({
          ...m,
          id: m.makine_id,
          makineid: "MKN-" + m.makine_id,
          aktiflik_durumu: typeof m.aktiflik_durumu === "string" ? m.aktiflik_durumu : (m.aktiflik_durumu ? "Aktif" : "Pasif")
        }));
        setMachines(formattedData);
      } catch (err) {
        console.error("Makineler yüklenirken hata oluştu", err);
      }
    };
    fetchMachines();
  }, []);

  const [isModalOpen, setIsModalOpen] = useState(false);

  const [form, setForm] = useState({
    makine_ad: "",
    firma_id: "",
    m_tur_id: "",
    seri_no: "",
    satin_alma_tarihi: "",
    satin_alma_maliyeti: "",
    garanti_suresi: "",
    aktiflik_durumu: "Aktif",
    lo_id: "", // Yeni: Lokasyon ID
    servis_firma_adi: "",
    servis_telefon: "",
    servis_il_ilce: "", // Yeni: İl/İlçe
    servis_adres: "",    // Yeni: Tam Adres
  });

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  // --- YENİ MAKİNE EKLEME FONKSİYONU ---
  const addMachine = async () => {
    if (!form.makine_ad || !form.firma_id || !form.m_tur_id) {
      alert("Makine adı, firma id ve makine tür id zorunludur!");
      return;
    }

    try {
      // Seri numaralarını virgülle ayrılmışsa diziye çevir
      const seriNoArray = typeof form.seri_no === "string"
        ? form.seri_no.split(",").map(s => s.trim()).filter(s => s !== "")
        : Array.isArray(form.seri_no) ? form.seri_no : [form.seri_no];

      // API'ye gönderilecek veri modelini oluştur
      const payload = {
        ...form,
        firma_id: Number(form.firma_id),
        m_tur_id: Number(form.m_tur_id),
        seri_no: seriNoArray,
        satin_alma_tarihi: form.satin_alma_tarihi ? new Date(form.satin_alma_tarihi).toISOString() : new Date().toISOString(),
        satin_alma_maliyeti: Number(form.satin_alma_maliyeti),
        aktiflik_durumu: form.aktiflik_durumu === "Aktif",
        top_cal_sma_saati: [],
        makine_ozellikleri: [],
        // Garanti bilgisi varsa tedarikçi objesini doldur
        tedarikci: form.garanti_suresi ? {
          firma_adi: form.servis_firma_adi,
          telefon: form.servis_telefon,
          il_ilce: form.servis_il_ilce,
          adres: form.servis_adres
        } : null
      };

      const addedMachine = await api.addMachine(payload);

      // UI listesini anlık olarak güncelle
      const machineForUI = {
        ...addedMachine.makine, // Backend'den dönen makine nesnesini kullan
        id: addedMachine.makine.makine_id,
        makineid: "MKN-" + addedMachine.makine.makine_id,
        aktiflik_durumu: form.aktiflik_durumu
      };

      setMachines([machineForUI, ...machines]);

      // Formu temizle ve modali kapat
      setForm({
        makine_ad: "", firma_id: "", m_tur_id: "", seri_no: "",
        satin_alma_tarihi: "", satin_alma_maliyeti: "", garanti_suresi: "", aktiflik_durumu: "Aktif",
        lo_id: "", servis_firma_adi: "", servis_telefon: "", servis_il_ilce: "", servis_adres: ""
      });
      setIsModalOpen(false);
    } catch (err) {
      console.error("Makine eklenirken hata:", err);
    }
  };

  // KPI Hesaplamaları
  const totalMachines = machines.length;
  const maintenanceCount = machines.filter(m => m.aktiflik_durumu?.toLowerCase() === "bakımda").length;
  const faultyCount = machines.filter(m => m.aktiflik_durumu?.toLowerCase() === "arızalı" || m.aktiflik_durumu?.toLowerCase() === "pasif").length;

  return (
    <div style={{ display: "flex", background: "#f5f6fa", minHeight: "100vh" }}>
      <Sidebar />

      <div style={{ flex: 1, display: "flex", flexDirection: "column", height: "100vh", overflow: "hidden" }}>
        <Navbar />

        <div style={{ padding: "25px", flex: 1, overflowY: "auto", position: "relative" }}>

          {/* ARAMA VE FİLTRELEME ALANI - MİNİMAL */}
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "20px", gap: "12px", flexWrap: "wrap" }}>
            <div style={{ display: "flex", gap: "10px", flex: 1, minWidth: "300px", alignItems: "center" }}>
              {/* Arama Kutusu */}
              <input
                type="text"
                placeholder="Makine adı veya ID ara..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                style={{
                  padding: "10px 12px",
                  border: "1px solid #ddd",
                  borderRadius: "6px",
                  fontSize: "13px",
                  outline: "none",
                  flex: 0.8,
                  minWidth: "180px",
                  color: "#333",
                  backgroundColor: "#fff"
                }}
              />

              {/* Kat Filtresi */}
              <select
                value={filterKat}
                onChange={(e) => setFilterKat(e.target.value)}
                style={{
                  padding: "10px 8px",
                  border: "1px solid #ddd",
                  borderRadius: "6px",
                  fontSize: "13px",
                  outline: "none",
                  backgroundColor: "#fff",
                  color: "#333",
                  cursor: "pointer",
                  minWidth: "80px"
                }}
              >
                <option value="">Kat</option>
                <option value="0">Z.Kat</option>
                
              </select>

              {/* Lokasyon Filtresi */}
              <select
                value={filterLokasyon}
                onChange={(e) => setFilterLokasyon(e.target.value)}
                style={{
                  padding: "10px 8px",
                  border: "1px solid #ddd",
                  borderRadius: "6px",
                  fontSize: "13px",
                  outline: "none",
                  backgroundColor: "#fff",
                  color: "#333",
                  cursor: "pointer",
                  minWidth: "90px"
                }}
              >
                <option value="">Lokasyon</option>
                {[...new Set(machines.map(m => m.lo_id).filter(Boolean))].map((id) => (
                  <option key={id} value={id}>
                    L{id}
                  </option>
                ))}
              </select>

              {/* Filtreleri Sıfırla */}
              {(searchTerm || filterKat || filterLokasyon) && (
                <button
                  onClick={() => {
                    setSearchTerm("");
                    setFilterKat("");
                    setFilterLokasyon("");
                  }}
                  style={{
                    padding: "10px 12px",
                    background: "#e74c3c",
                    color: "white",
                    border: "none",
                    borderRadius: "6px",
                    fontWeight: "bold",
                    cursor: "pointer",
                    fontSize: "12px",
                    whiteSpace: "nowrap"
                  }}
                  onMouseOver={(e) => e.target.style.background = "#c0392b"}
                  onMouseOut={(e) => e.target.style.background = "#e74c3c"}
                >
                  Sıfırla
                </button>
              )}
            </div>

            <button
              onClick={() => setIsModalOpen(true)}
              style={ekleButonStyle}
            >
              +Makine Ekle
            </button>
          </div>

          {/* KPI ALANI: Makinelerin durum özetini gösteren interaktif kartlar */}
          <div style={kpiContainer}>
            {/* Tümü Filtresi */}
            <div
              style={{ ...kpiBox, border: filter === "Tümü" ? "2px solid #3498db" : "2px solid transparent", cursor: "pointer" }}
              onClick={() => setFilter("Tümü")}
            >
              <span style={kpiTitle}>Toplam Makine</span>
              <span style={{ fontSize: "36px", color: "#3498db", fontWeight: "bold" }}>{totalMachines}</span>
            </div>
            {/* Bakımda Filtresi */}
            <div
              style={{ ...kpiBox, border: filter === "Bakımda" ? "2px solid #f39c12" : "2px solid transparent", cursor: "pointer" }}
              onClick={() => setFilter("Bakımda")}
            >
              <span style={kpiTitle}>Bakımda Olanlar</span>
              <span style={{ fontSize: "36px", color: "#f39c12", fontWeight: "bold" }}>{maintenanceCount}</span>
            </div>
            {/* Arızalı/Pasif Filtresi */}
            <div
              style={{ ...kpiBox, border: filter === "Arızalı / Pasif" ? "2px solid #e74c3c" : "2px solid transparent", cursor: "pointer" }}
              onClick={() => setFilter("Arızalı / Pasif")}
            >
              <span style={kpiTitle}>Arızalı / Pasif</span>
              <span style={{ fontSize: "36px", color: "#e74c3c", fontWeight: "bold" }}>{faultyCount}</span>
            </div>
          </div>

          {/* MAKİNE LİSTESİ */}
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(300px, 1fr))", gap: "20px", marginTop: "25px" }}>
            {machines
              .filter(m => {
                // Durum filtresi (Tümü, Bakımda, Arızalı/Pasif)
                if (filter === "Bakımda" && m.aktiflik_durumu?.toLowerCase() !== "bakımda") return false;
                if (filter === "Arızalı / Pasif" && m.aktiflik_durumu?.toLowerCase() !== "arızalı" && m.aktiflik_durumu?.toLowerCase() !== "pasif") return false;

                // Arama filtresi
                if (searchTerm) {
                  const searchLower = searchTerm.toLowerCase();
                  const matches = 
                    (m.makine_ad?.toLowerCase().includes(searchLower)) ||
                    (m.makineid?.toLowerCase().includes(searchLower)) ||
                    (m.m_tur_id?.toString().includes(searchLower));
                  if (!matches) return false;
                }

                // Lokasyon filtresi
                if (filterLokasyon && m.lo_id?.toString() !== filterLokasyon) return false;

                // Kat filtresi (lo_id'den kat bilgisini çıkart veya varsayılan olarak kullan)
                if (filterKat && m.lo_id) {
                  // lo_id formatı örneğin: "203" ise ilk digit kat (2. kat), veya ayrı kat bilgisi varsa onu kullan
                  const machineKat = m.kat || Math.floor(m.lo_id / 100)?.toString();
                  if (machineKat?.toString() !== filterKat?.toString()) return false;
                }

                return true;
              })
              .sort((a, b) => (b.mevcut_risk_skoru || 0) - (a.mevcut_risk_skoru || 0))
              .map((m) => (
                <div
                  key={m.id}
                  style={{
                    ...cardStyle,
                    cursor: "pointer",
                    border: expandedMachineId === m.id ? "2px solid #3498db" : "2px solid transparent",
                    background: "white",
                    display: "flex",
                    flexDirection: "column",
                    justifyContent: "space-between",
                    minHeight: "380px"
                  }}
                  onClick={() => setExpandedMachineId(expandedMachineId === m.id ? null : m.id)}
                >
                  <div>
                    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", borderBottom: "1px solid #eee", paddingBottom: "10px", marginBottom: "15px", height: "50px" }}>
                      <h3 style={{ margin: 0, color: "#2c3e50", fontSize: "16px", overflow: "hidden", textOverflow: "ellipsis", display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical" }}>{m.makine_ad}</h3>
                      <div style={{ display: "flex", flexDirection: "column", gap: "5px", alignItems: "flex-end" }}>
                        {m.garanti_suresi > 0 && (
                          <span style={garantiRozetStyle} title={`${m.garanti_suresi} Ay Garanti`}>
                            🛡️ Garantili
                          </span>
                        )}
                        <span style={{
                          padding: "4px 8px",
                          borderRadius: "20px",
                          fontSize: "12px",
                          fontWeight: "bold",
                          color: "white",
                          minWidth: "95px", // Genişlik eşitlendi
                          textAlign: "center",
                          background: m.aktiflik_durumu?.toLowerCase() === "aktif" ? "#2ecc71" :
                            m.aktiflik_durumu?.toLowerCase() === "bakımda" ? "#f39c12" : "#e74c3c"
                        }}>
                          {m.aktiflik_durumu || "Bilinmiyor"}
                        </span>
                      </div>
                    </div>

                    <div style={{ display: "flex", flexDirection: "column", gap: "8px", fontSize: "14px", color: "#555" }}>
                      <div><strong>ID:</strong> {m.makineid}</div>
                      {m.firma_id && <div><strong>Firma ID:</strong> {m.firma_id}</div>}
                      {m.satin_alma_tarihi && <div><strong>Satın Alma:</strong> {m.satin_alma_tarihi}</div>}
                      <div><strong>Risk Skoru:</strong> {m.mevcut_risk_skoru}</div>
                    </div>

                    {expandedMachineId === m.id && (
                      <div style={{ marginTop: "15px", paddingTop: "15px", borderTop: "1px dashed #ccc", overflow: "hidden" }}>
                        <div style={{ marginBottom: "10px", color: "#0f3460", fontWeight: "bold", fontSize: "14px" }}>Detaylı Bilgiler</div>
                        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "8px", fontSize: "13px", color: "#555" }}>
                          <div><strong>Maliyet:</strong> {m.satin_alma_maliyeti || "-"} ₺</div>
                          <div><strong>Çalışma Saatleri:</strong> {m.top_calisma_saati || 0} Saat</div>
                          <div><strong>Lokasyon ID:</strong> {m.lo_id || "-"}</div>
                          <div><strong>Tür ID:</strong> {m.m_tur_id || "-"}</div>
                          <div><strong>Seri No:</strong> {Array.isArray(m.seri_no) ? m.seri_no.join(", ") : m.seri_no || "-"}</div>
                          <div style={{ color: "#e94560", fontWeight: "bold" }}><strong>Servis PIN:</strong> {m.servis_pin || "####"}</div>
                          <div><strong>Garanti Süresi:</strong> {m.garanti_suresi ? m.garanti_suresi + " Ay" : "-"}</div>
                          {m.garanti_suresi > 0 && m.tedarikci && (
                            <>
                              <div><strong>Garanti Firması:</strong> {m.tedarikci.firma_adi || m.tedarikci.ad || "-"}</div>
                              <div><strong>Garanti Tel:</strong> {m.tedarikci.telefon || "-"}</div>
                            </>
                          )}
                          <div style={{ gridColumn: "span 2" }}><strong>Özellikler:</strong> {m.makine_ozellikleri?.teknik_ozellikler ? Object.entries(m.makine_ozellikleri.teknik_ozellikler).map(([k,v]) => `${k}: ${v}`).join(" | ") : "Belirtilmemiş"}</div>
                        </div>
                      </div>
                    )}

                    {/* QR KOD VE AKSİYONLAR: Her makine için dinamik QR kod oluşturma */}
                    <div style={{ marginTop: "20px", display: "flex", flexDirection: "column", alignItems: "center", background: "#f8f9fa", padding: "15px", borderRadius: "8px" }} onClick={(e) => e.stopPropagation()}>
                      <div className={`qr-container-${m.id}`}>
                        <QRCodeCanvas value={`${window.location.origin}/checklist-giris/${m.makine_qr}`} size={100} />
                      </div>
                      
                      {/* QR Çıktı Al: QR kodu yeni pencerede yazdırılabilir formatta açar */}
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          const container = document.querySelector(`.qr-container-${m.id}`);
                          const canvas = container?.querySelector('canvas');
                          if (!canvas) return;
                          const imgData = canvas.toDataURL('image/png');
                          const printWindow = window.open('', '_blank');
                          printWindow.document.write(`
                            <html>
                              <head><title>QR Kod Çıktısı - ${m.makine_ad}</title></head>
                              <body style="display:flex; flex-direction:column; align-items:center; justify-content:center; height:100vh; margin:0; font-family: sans-serif;">
                                <h2>${m.makine_ad}</h2>
                                <img src="${imgData}" style="width:200px; height:200px;" />
                                <p style="font-size:14px; color:gray; margin-top:15px;">Makine ID: ${m.makineid}</p>
                              </body>
                            </html>
                          `);
                          printWindow.document.close();
                          printWindow.focus();
                          printWindow.print();
                          printWindow.close();
                        }}
                        style={printBtnStyle}
                      >
                        QR Çıktı Al
                      </button>

                      {/* Detay Sayfasına Git Butonu */}
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          navigate(`/makine/${m.id}`);
                        }}
                        style={{ ...printBtnStyle, background: "gray", marginTop: "10px" }}
                      >
                        Tüm Detayları Gör
                      </button>
                    </div>
                  </div>
                </div>
              ))}
          </div>

          {/* MAKİNE EKLE MODAL */}
          {isModalOpen && (
            <div style={modalOverlayStyle}>
              <div style={modalContentStyle}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "20px", borderBottom: "1px solid #eee", paddingBottom: "15px" }}>
                  <h3 style={{ margin: 0, color: "#0f3460", fontSize: "20px" }}>Yeni Makine Ekle</h3>
                  <button onClick={() => setIsModalOpen(false)} style={closeBtnStyle}>✕</button>
                </div>

                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "15px", maxHeight: "60vh", overflowY: "auto", paddingRight: "10px" }}>
                  <input name="makine_ad" placeholder="Makine Adı (Zorunlu)" value={form.makine_ad} onChange={handleChange} style={inputStyle} />
                  <input name="firma_id" type="number" placeholder="Firma ID" value={form.firma_id} onChange={handleChange} style={inputStyle} />
                  <input name="m_tur_id" type="number" placeholder="Makine Tür ID" value={form.m_tur_id} onChange={handleChange} style={inputStyle} />
                  <input name="seri_no" placeholder="Seri No" value={form.seri_no} onChange={handleChange} style={inputStyle} />
                  <input name="satin_alma_tarihi" type="date" placeholder="Satın Alma Tarihi" value={form.satin_alma_tarihi} onChange={handleChange} style={inputStyle} />
                  <input name="satin_alma_maliyeti" type="number" placeholder="Satın Alma Maliyeti" value={form.satin_alma_maliyeti} onChange={handleChange} style={inputStyle} />

                  <select name="lo_id" value={form.lo_id} onChange={handleChange} style={inputStyle}>
                    <option value="">Lokasyon Seçiniz</option>
                    <option value="LO-A1">LO-A1 (Blok A)</option>
                    <option value="LO-B2">LO-B2 (Blok B)</option>
                    <option value="LO-C3">LO-C3 (Blok C)</option>
                    <option value="LO-D4">LO-D4 (Blok D)</option>
                    <option value="LO-E5">LO-E5 (Blok E)</option>
                    <option value="LO-OF">Ofis / Arge</option>
                  </select>

                  <input name="garanti_suresi" type="number" placeholder="Garanti Süresi (Ay)" value={form.garanti_suresi} onChange={handleChange} style={inputStyle} />

                  {/* GARANTİ VARSA GÖRÜNEN EK ALANLAR */}
                  {Number(form.garanti_suresi) > 0 && (
                    <div style={{ gridColumn: "span 2", display: "grid", gridTemplateColumns: "1fr 1fr", gap: "15px", border: "1px dashed #2ecc71", padding: "15px", borderRadius: "10px", marginTop: "10px", marginBottom: "10px" }}>
                      <div style={{ gridColumn: "span 2", color: "#27ae60", fontWeight: "bold", fontSize: "14px", marginBottom: "5px" }}>🛡️ Garanti & Servis İletişim Bilgileri</div>
                      <input name="servis_firma_adi" placeholder="Servis Firma Adı" value={form.servis_firma_adi} onChange={handleChange} style={inputStyle} />
                      <input name="servis_telefon" placeholder="Servis Telefon" value={form.servis_telefon} onChange={handleChange} style={inputStyle} />
                      <input name="servis_il_ilce" placeholder="İl / İlçe" value={form.servis_il_ilce} onChange={handleChange} style={inputStyle} />
                      <textarea name="servis_adres" placeholder="Açık Adres" value={form.servis_adres} onChange={handleChange} style={{ ...inputStyle, gridColumn: "span 2", height: "60px" }} />
                    </div>
                  )}

                  <select name="aktiflik_durumu" value={form.aktiflik_durumu} onChange={handleChange} style={inputStyle}>
                    <option value="Aktif">Aktif</option>
                    <option value="Bakımda">Bakımda</option>
                    <option value="Arızalı">Arızalı</option>
                    <option value="Pasif">Pasif</option>
                  </select>
                </div>

                <div style={{ display: "flex", justifyContent: "flex-end", gap: "15px", marginTop: "25px", paddingTop: "15px", borderTop: "1px solid #eee" }}>
                  <button onClick={() => setIsModalOpen(false)} style={cancelBtnStyle}>İptal</button>
                  <button onClick={addMachine} style={saveBtnStyle}>Makineyi Kaydet</button>
                </div>
              </div>
            </div>
          )}

        </div>
      </div>
    </div>
  );
}

// STYLES
const kpiContainer = { display: "flex", gap: "25px", flexWrap: "wrap" };
const kpiBox = { flex: 1, minWidth: "150px", background: "white", padding: "20px", borderRadius: "10px", boxShadow: "0 2px 10px rgba(0,0,0,0.05)", display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "center" };
const kpiTitle = { color: "#7f8c8d", fontSize: "13px", fontWeight: "bold", textTransform: "uppercase", marginBottom: "8px", letterSpacing: "0.5px" };

const cardStyle = { background: "white", padding: "20px", borderRadius: "10px", boxShadow: "0 4px 15px rgba(0,0,0,0.05)", transition: "transform 0.2s" };

const ekleButonStyle = { padding: "12px 20px", background: "#e94560", color: "white", fontSize: "15px", fontWeight: "bold", border: "none", borderRadius: "8px", cursor: "pointer", boxShadow: "0 4px 10px rgba(233, 69, 96, 0.3)" };
const printBtnStyle = { marginTop: "15px", padding: "8px 15px", background: "#34495e", color: "white", border: "none", borderRadius: "6px", cursor: "pointer", fontWeight: "bold", fontSize: "13px", width: "100%" };

const modalOverlayStyle = { position: "absolute", top: 0, left: 0, right: 0, bottom: 0, background: "rgba(0,0,0,0.5)", display: "flex", justifyContent: "center", alignItems: "flex-start", paddingTop: "50px", zIndex: 100, backdropFilter: "blur(4px)" };
const modalContentStyle = { background: "white", padding: "30px", borderRadius: "12px", width: "100%", maxWidth: "700px", boxShadow: "0 10px 40px rgba(0,0,0,0.2)" };

const inputStyle = { padding: "12px", border: "1px solid #e1e5eb", borderRadius: "8px", fontSize: "14px", outline: "none", background: "#fafafa", width: "100%", boxSizing: "border-box", color: "#333" };
const closeBtnStyle = { background: "transparent", border: "none", fontSize: "20px", cursor: "pointer", color: "#999" };
const cancelBtnStyle = { padding: "12px 20px", background: "#f1f2f6", color: "#333", border: "none", borderRadius: "8px", fontWeight: "bold", cursor: "pointer" };
const saveBtnStyle = { padding: "12px 20px", background: "#0f3460", color: "white", border: "none", borderRadius: "8px", fontWeight: "bold", cursor: "pointer" };
const garantiRozetStyle = {
  padding: "4px 10px",
  background: "linear-gradient(135deg, #3498db 0%, #2980b9 100%)",
  color: "white",
  borderRadius: "20px",
  fontSize: "11px",
  fontWeight: "bold",
  boxShadow: "0 2px 5px rgba(52, 152, 219, 0.3)",
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  gap: "3px",
  minWidth: "95px" // Genişlik eşitlendi
};