import React, { useState, useEffect } from "react";
import Sidebar from "./Sidebar";
import Navbar from "./Navbar";
import { api } from "./services/api";

export default function SistemAyarlari() {
  const [vardiyalar, setVardiyalar] = useState([
    { vardiya_adi: "1. Vardiya (Gunduz)", baslangic_saati: "08:00", bitis_saati: "16:00" },
    { vardiya_adi: "2. Vardiya (Aksam)", baslangic_saati: "16:00", bitis_saati: "00:00" },
    { vardiya_adi: "3. Vardiya (Gece)", baslangic_saati: "00:00", bitis_saati: "08:00" },
  ]);
  const [makineTurleri, setMakineTurleri] = useState([]);
  const [loading, setLoading] = useState(true);
  const [savingVardiya, setSavingVardiya] = useState(false);
  const [savingDurus, setSavingDurus] = useState(false);

  useEffect(() => {
    const fetchAyarlar = async () => {
      try {
        const [vardiyaData, durusMaliyetleri] = await Promise.all([
          api.getVardiyaSaatleri(),
          api.getMakineTuruDurusMaliyetleri(),
        ]);

        if (vardiyaData && vardiyaData.length > 0) {
          setVardiyalar(vardiyaData);
        }

        if (durusMaliyetleri && durusMaliyetleri.length > 0) {
          setMakineTurleri(durusMaliyetleri);
        } else {
          const makineTuruFallback = await api.getSystemMachineTypes();
          setMakineTurleri(makineTuruFallback || []);
        }
      } catch (err) {
        console.error("Operasyonel ayarlar cekilemedi:", err);
      } finally {
        setLoading(false);
      }
    };

    fetchAyarlar();
  }, []);

  const handleVardiyaChange = (index, field, value) => {
    const newVardiyalar = [...vardiyalar];
    newVardiyalar[index][field] = value;
    setVardiyalar(newVardiyalar);
  };

  const handleDurusMaliyetiChange = (index, value) => {
    const newTurler = [...makineTurleri];
    newTurler[index] = {
      ...newTurler[index],
      saatlik_durus_maliyeti: value,
    };
    setMakineTurleri(newTurler);
  };

  const handleSaveVardiyalar = async () => {
    setSavingVardiya(true);
    try {
      await api.updateVardiyaSaatleri(vardiyalar);
      alert("Vardiya saatleri basariyla guncellendi.");
    } catch (err) {
      alert("Kaydedilirken hata olustu: " + err.message);
    } finally {
      setSavingVardiya(false);
    }
  };

  const handleSaveDurusMaliyetleri = async () => {
    setSavingDurus(true);
    try {
      await api.updateMakineTuruDurusMaliyetleri(
        makineTurleri.map((tur) => ({
          makine_tur_id: tur.makine_tur_id,
          saatlik_durus_maliyeti: Number(tur.saatlik_durus_maliyeti) || 0,
        }))
      );
      alert("Saatlik durus maliyetleri basariyla guncellendi.");
    } catch (err) {
      alert("Kaydedilirken hata olustu: " + err.message);
    } finally {
      setSavingDurus(false);
    }
  };

  if (loading) return <div style={loadingStyle}>Ayarlar Yukleniyor...</div>;

  return (
    <div style={containerStyle}>
      <Sidebar />
      <div style={mainStyle}>
        <Navbar title="Operasyonel Ayarlar" />

        <div style={contentStyle}>
          <div style={cardStyle}>
            <div style={cardHeaderStyle}>
              <h3 style={cardTitleStyle}>Vardiya Saatleri</h3>
              <p style={cardSubTitleStyle}>Durus sureleri ve OEE verileri bu calisma saatlerine gore hesaplanir.</p>
            </div>

            <div style={formGridStyle}>
              {vardiyalar.map((vardiya, index) => (
                <div key={index} style={vardiyaRowStyle}>
                  <div style={inputGroupStyle}>
                    <label style={labelStyle}>Vardiya Adi</label>
                    <input
                      type="text"
                      value={vardiya.vardiya_adi}
                      onChange={(e) => handleVardiyaChange(index, "vardiya_adi", e.target.value)}
                      style={inputStyle}
                      placeholder="Orn: Gunduz Vardiyasi"
                    />
                  </div>
                  <div style={inputGroupStyle}>
                    <label style={labelStyle}>Baslangic</label>
                    <input
                      type="time"
                      value={vardiya.baslangic_saati}
                      onChange={(e) => handleVardiyaChange(index, "baslangic_saati", e.target.value)}
                      style={inputStyle}
                    />
                  </div>
                  <div style={inputGroupStyle}>
                    <label style={labelStyle}>Bitis</label>
                    <input
                      type="time"
                      value={vardiya.bitis_saati}
                      onChange={(e) => handleVardiyaChange(index, "bitis_saati", e.target.value)}
                      style={inputStyle}
                    />
                  </div>
                </div>
              ))}
            </div>

            <div style={actionAreaStyle}>
              <button onClick={handleSaveVardiyalar} disabled={savingVardiya} style={savingVardiya ? disabledButtonStyle : buttonStyle}>
                {savingVardiya ? "Guncelleniyor..." : "Vardiya Saatlerini Kaydet"}
              </button>
            </div>
          </div>

          <div style={cardStyle}>
            <div style={cardHeaderStyle}>
              <h3 style={cardTitleStyle}>Makine Turune Gore Saatlik Durus Maliyeti</h3>
              <p style={cardSubTitleStyle}>Her makine turu icin bir saatlik uretim durusunun maliyetini backend uzerinde saklar.</p>
            </div>

            <div style={tableStyle}>
              {makineTurleri.map((tur, index) => (
                <div key={tur.makine_tur_id} style={costRowStyle}>
                  <div>
                    <div style={machineTypeStyle}>{tur.makine_tur_adi}</div>
                    <div style={mutedStyle}>Saatlik durus maliyeti</div>
                  </div>
                  <div style={costInputWrapStyle}>
                    <span style={currencyStyle}>TL/saat</span>
                    <input
                      type="number"
                      min="0"
                      step="0.01"
                      value={tur.saatlik_durus_maliyeti ?? ""}
                      onChange={(e) => handleDurusMaliyetiChange(index, e.target.value)}
                      style={costInputStyle}
                    />
                  </div>
                </div>
              ))}

              {makineTurleri.length === 0 && (
                <div style={emptyStateStyle}>Kayitli makine turu bulunamadi.</div>
              )}
            </div>

            <div style={actionAreaStyle}>
              <button onClick={handleSaveDurusMaliyetleri} disabled={savingDurus} style={savingDurus ? disabledButtonStyle : buttonStyle}>
                {savingDurus ? "Guncelleniyor..." : "Durus Maliyetlerini Kaydet"}
              </button>
            </div>
          </div>

          <div style={infoCardStyle}>
            <h4 style={{ margin: "0 0 10px 0", color: "#3498db" }}>Neden Onemli?</h4>
            <p style={{ margin: 0, fontSize: "13px", lineHeight: "1.6", color: "#64748b" }}>
              Durus maliyeti sabit bir katsayi yerine makinenin turune tanimlanan saatlik degerle hesaplanir. Boylece ayni ariza suresi farkli ekipmanlarda farkli finansal etki olusturabilir.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

const containerStyle = { display: "flex", minHeight: "100vh", background: "#f8fafc" };
const mainStyle = { flex: 1, display: "flex", flexDirection: "column" };
const contentStyle = { padding: "40px", maxWidth: "980px", display: "flex", flexDirection: "column", gap: "25px" };
const loadingStyle = { display: "flex", justifyContent: "center", alignItems: "center", height: "100vh", fontSize: "18px", fontWeight: "bold" };
const cardStyle = { background: "#fff", borderRadius: "12px", boxShadow: "0 10px 25px rgba(0,0,0,0.05)", padding: "30px", border: "1px solid #e2e8f0" };
const cardHeaderStyle = { marginBottom: "24px", borderBottom: "1px solid #f1f5f9", paddingBottom: "18px" };
const cardTitleStyle = { margin: 0, fontSize: "20px", fontWeight: "800", color: "#1e293b" };
const cardSubTitleStyle = { margin: "8px 0 0 0", fontSize: "14px", color: "#64748b" };
const formGridStyle = { display: "flex", flexDirection: "column", gap: "20px" };
const vardiyaRowStyle = { display: "grid", gridTemplateColumns: "2fr 1fr 1fr", gap: "15px", background: "#f8fafc", padding: "20px", borderRadius: "8px", border: "1px solid #f1f5f9" };
const inputGroupStyle = { display: "flex", flexDirection: "column", gap: "8px" };
const labelStyle = { fontSize: "12px", fontWeight: "700", color: "#475569", textTransform: "uppercase" };
const inputStyle = { padding: "12px", borderRadius: "8px", border: "1px solid #cbd5e1", fontSize: "14px", outline: "none" };
const tableStyle = { display: "flex", flexDirection: "column", gap: "12px" };
const costRowStyle = { display: "grid", gridTemplateColumns: "1fr 190px", alignItems: "center", gap: "18px", background: "#f8fafc", border: "1px solid #f1f5f9", borderRadius: "8px", padding: "16px 18px" };
const machineTypeStyle = { color: "#1e293b", fontSize: "15px", fontWeight: "800" };
const mutedStyle = { marginTop: "4px", color: "#64748b", fontSize: "12px", fontWeight: "600" };
const costInputWrapStyle = { display: "flex", alignItems: "center", gap: "8px" };
const currencyStyle = { color: "#64748b", fontSize: "12px", fontWeight: "800", whiteSpace: "nowrap" };
const costInputStyle = { ...inputStyle, width: "100%", textAlign: "right", fontWeight: "800" };
const emptyStateStyle = { padding: "26px", textAlign: "center", color: "#64748b", background: "#f8fafc", borderRadius: "8px" };
const actionAreaStyle = { marginTop: "24px", display: "flex", justifyContent: "flex-end" };
const buttonStyle = { background: "#3498db", color: "#fff", padding: "14px 28px", borderRadius: "8px", border: "none", fontWeight: "bold", cursor: "pointer", boxShadow: "0 4px 12px rgba(52, 152, 219, 0.3)" };
const disabledButtonStyle = { ...buttonStyle, background: "#94a3b8", cursor: "not-allowed", boxShadow: "none" };
const infoCardStyle = { background: "rgba(52, 152, 219, 0.05)", padding: "20px", borderRadius: "8px", borderLeft: "4px solid #3498db" };
