import React, { useState, useEffect } from "react";
import { useParams } from "react-router-dom";
import { api } from "./services/api";
import { getSoruDetay } from "./checklistSorulari";

/**
 * Dinamik Operatör Checklist Sayfası
 */
export default function Checklist() {
  const { id } = useParams();

  const [loading, setLoading] = useState(true);
  const [makineAdi, setMakineAdi] = useState("");
  const [makineTuru, setMakineTuru] = useState("");
  const [sablonId, setSablonId] = useState(null);
  const [sablonAdi, setSablonAdi] = useState("");
  const [sorular, setSorular] = useState([]);
  const [cevaplar, setCevaplar] = useState({});
  const [genelNot, setGenelNot] = useState("");
  const [saved, setSaved] = useState(false);
  const [hata, setHata] = useState(null);


  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true);
        const data = await api.getChecklistByMachine(id);
        setMakineAdi(data.makine_adi || `Makine #${id}`);
        setMakineTuru(data.makine_turu || "Bilinmiyor");
        setSablonId(data.sablon_id);
        setSablonAdi(data.sablon_adi || "");
        setSorular(data.sorular || []);
        setHata(null);
      } catch (err) {
        console.error("Checklist verileri yüklenemedi:", err);
        setHata("HATA: " + err.message);
      } finally {
        setLoading(false);
      }
    };
    if (id) fetchData();
  }, [id]);


  const setCevap = (madde_id, seviye) => {
    setCevaplar(prev => ({ ...prev, [madde_id]: seviye }));
    setSaved(false);
  };

  const saveChecklist = async () => {
    // form_doldurma_suresi_sn ekranda gösterilmiyor, validasyondan hariç tut
    const yanitlanabilirSorular = sorular.filter(s => s.teknik_parametre !== "form_doldurma_suresi_sn");
    const cevaplanmamis = yanitlanabilirSorular.filter(s => cevaplar[s.madde_id] === undefined);
    if (cevaplanmamis.length > 0) {
      alert(`Lütfen tüm soruları yanıtlayın! (${cevaplanmamis.length} soru eksik)`);
      return;
    }

    const answersPayload = yanitlanabilirSorular.map(s => ({
      madde_id: s.madde_id,
      girilen_deger: String(cevaplar[s.madde_id]),
      durum: cevaplar[s.madde_id] === 0 ? "NORMAL" : cevaplar[s.madde_id] === 1 ? "UYARI" : "KRITIK",
      aciklama: null
    }));

    const payload = {
      makine_id: Number(id),
      sablon_id: sablonId,
      genel_not: genelNot,
      cevaplar: answersPayload
    };

    try {
      await api.submitChecklist(payload);
      setSaved(true);
      alert("✅ Checklist kaydedildi!");
    } catch (err) {
      alert("Kaydetme başarısız: " + (err.message || "Hata"));
    }
  };

  const getTurRenk = (tur) => {
    if (tur?.includes("CNC")) return { bg: "#1e3a5f", text: "#5dade2" };
    if (tur?.includes("Pres")) return { bg: "#4a1942", text: "#c39bd3" };
    if (tur?.includes("Enjeksiyon")) return { bg: "#0e4429", text: "#52c41a" };
    return { bg: "#2c3e50", text: "#bdc3c7" };
  };

  const turRenk = getTurRenk(makineTuru);
  const toplamRisk = Object.values(cevaplar).reduce((acc, val) => acc + val, 0);
  const maxRisk = sorular.filter(s => s.teknik_parametre !== "form_doldurma_suresi_sn").length * 2;
  const riskYuzdesi = maxRisk > 0 ? Math.round((toplamRisk / maxRisk) * 100) : 0;

  if (loading) {
    return (
      <div style={sayfaStil}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "center", height: "60vh" }}>
          <div style={spinnerStil}></div>
        </div>
      </div>
    );
  }

  if (hata) {
    return (
      <div style={sayfaStil}>
        <div style={{ textAlign: "center", padding: "60px", color: "#e74c3c" }}>
          <h2>❌ Hata</h2>
          <p>{hata}</p>
          <button onClick={() => window.location.reload()} style={{ padding: "10px 20px", background: "#e74c3c", color: "white", border: "none", borderRadius: "8px", marginTop: "20px", cursor: "pointer" }}>Tekrar Dene</button>
        </div>
      </div>
    );
  }

  const ortakParametreKeys = ["sicaklik", "titresim", "ses_anomalisi", "yag_durumu"];
  const ortakSorular = sorular.filter(s => ortakParametreKeys.includes(s.teknik_parametre));
  const ozelSorular = sorular.filter(s => !ortakParametreKeys.includes(s.teknik_parametre) && s.teknik_parametre !== "form_doldurma_suresi_sn");

  return (
    <div className="app-container" style={sayfaStil}>
      <div className="app-content-wrapper app-content" style={konteynerStil}>

        {/* BAŞLIK ALANI */}
        <div style={baslikKartStil}>
          <div style={{ display: "flex", alignItems: "center", gap: "15px", flexWrap: "wrap" }}>
            <div>
              <h2 style={{ margin: 0, color: "white", fontSize: "20px", fontWeight: "700" }}>{makineAdi}</h2>
              <div style={{ display: "flex", gap: "8px", marginTop: "6px", flexWrap: "wrap" }}>
                <span style={{ ...rozetStil, background: turRenk.bg, color: turRenk.text, border: `1px solid ${turRenk.text}40` }}>{makineTuru}</span>
                <span style={{ ...rozetStil, background: "rgba(255,255,255,0.1)", color: "#a0aec0" }}>ID: {id}</span>
              </div>
            </div>
          </div>
        </div>

        {/* ORTAK PARAMETRELER */}
        {ortakSorular.length > 0 && (
          <div style={bolumKartStil}>
            <div style={bolumBaslikStil}>
              <h3 style={{ margin: 0, color: "#2d3748", fontSize: "16px", fontWeight: "700" }}>Ortak Sistem Parametreleri</h3>
              <span style={{ fontSize: "12px", color: "#a0aec0", marginLeft: "auto" }}>Tüm Makineler</span>
            </div>
            {ortakSorular.map((soru, idx) => (
              <SoruKarti key={soru.madde_id} soru={soru} index={idx + 1} cevap={cevaplar[soru.madde_id]} onCevapSec={(v) => setCevap(soru.madde_id, v)} />
            ))}
          </div>
        )}

        {/* ÖZEL PARAMETRELER */}
        {ozelSorular.length > 0 && (
          <div style={bolumKartStil}>
            <div style={bolumBaslikStil}>
              <span style={{ fontSize: "18px" }}>{makineTuru?.includes("CNC") ? "⚙️" : makineTuru?.includes("Pres") ? "🔨" : "💉"}</span>
              <h3 style={{ margin: 0, color: "#2d3748", fontSize: "16px", fontWeight: "700" }}>{makineTuru} Özel Parametreleri</h3>
            </div>
            {ozelSorular.map((soru, idx) => (
              <SoruKarti key={soru.madde_id} soru={soru} index={idx + 1} cevap={cevaplar[soru.madde_id]} onCevapSec={(v) => setCevap(soru.madde_id, v)} />
            ))}
          </div>
        )}

        {/* BUTONLAR VE NOTLAR */}
        <div style={bolumKartStil}>
          <div style={notKonteynerStil}>
            <label style={notEtiketStil}><span style={{ marginRight: "8px" }}>⚠️</span>Acil Durum / Yapılan İşlem Açıklaması</label>
            <textarea
              style={notTextareaStil}
              placeholder="Acil bir durum veya anormallik fark ettiyseniz buraya detaylıca yazınız..."
              value={genelNot}
              onChange={(e) => setGenelNot(e.target.value)}
            />
          </div>
          <div style={{ marginTop: "20px", display: "flex", flexDirection: "column", gap: "10px" }}>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", flexWrap: "wrap", gap: "15px", marginTop: "10px" }}>
              <div style={{ fontSize: "13px", color: "#718096" }}>
                <span style={{ fontWeight: "bold", color: Object.keys(cevaplar).length === sorular.filter(s => s.teknik_parametre !== "form_doldurma_suresi_sn").length ? "#2ecc71" : "#f39c12" }}>{Object.keys(cevaplar).length}</span>
                {" / "}{sorular.filter(s => s.teknik_parametre !== "form_doldurma_suresi_sn").length} soru yanıtlandı
              </div>
              <button
                onClick={saveChecklist}
                disabled={saved}
                style={{ ...kaydetButonStil, flex: 1, background: saved ? "linear-gradient(135deg, #2ecc71, #27ae60)" : "linear-gradient(135deg, #0f3460, #16213e)", opacity: saved ? 0.8 : 1, cursor: saved ? "default" : "pointer" }}
              >
                {saved ? "✔ Kaydedildi" : "Kaydet ve Gönder"}
              </button>
            </div>
          </div>
        </div>

      </div>
    </div>
  );
}

function SoruKarti({ soru, index, cevap, onCevapSec }) {
  const detay = getSoruDetay(soru.teknik_parametre);
  const soruAdi = detay?.baslik || soru.madde_adi || "Bilinmeyen Soru";
  const ikon = detay?.ikon || "📋";
  const secenekler = detay?.secenekler || { 0: "Normal / Sorun Yok", 1: "Hafif Anormallik Var", 2: "Ciddi / Kritik Sorun" };
  const seviyeRenkleri = {
    0: { bg: "#f0fdf4", border: "#bbf7d0", text: "#166534", accent: "#22c55e", label: "Normal" },
    1: { bg: "#fffbeb", border: "#fde68a", text: "#92400e", accent: "#f59e0b", label: "Uyarı" },
    2: { bg: "#fef2f2", border: "#fecaca", text: "#991b1b", accent: "#ef4444", label: "Kritik" }
  };

  return (
    <div style={{ ...soruKartStil, borderLeft: cevap !== undefined ? `4px solid ${seviyeRenkleri[cevap].accent}` : "4px solid #e2e8f0" }}>
      <div style={{ display: "flex", alignItems: "center", gap: "10px", marginBottom: "12px" }}>
        <span style={{ fontSize: "20px" }}>{ikon}</span>
        <div style={{ flex: 1 }}>
          <span style={{ fontWeight: "700", color: "#2d3748", fontSize: "15px" }}>{index}. {soruAdi}</span>
        </div>
        {cevap !== undefined && <span style={{ padding: "3px 10px", borderRadius: "20px", fontSize: "11px", fontWeight: "700", background: seviyeRenkleri[cevap].bg, color: seviyeRenkleri[cevap].text, border: `1px solid ${seviyeRenkleri[cevap].border}` }}>{seviyeRenkleri[cevap].label}</span>}
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
        {[0, 1, 2].map(v => (
          <button key={v} onClick={() => onCevapSec(v)} style={{ display: "flex", alignItems: "flex-start", gap: "10px", padding: "10px 14px", borderRadius: "10px", border: cevap === v ? `2px solid ${seviyeRenkleri[v].accent}` : "2px solid #e8ecf1", background: cevap === v ? seviyeRenkleri[v].bg : "#fafbfc", cursor: "pointer", textAlign: "left", outline: "none" }}>
            <div style={{ width: "26px", height: "26px", borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center", fontWeight: "800", fontSize: "13px", flexShrink: 0, background: cevap === v ? seviyeRenkleri[v].accent : "#e2e8f0", color: cevap === v ? "white" : "#a0aec0" }}>{v}</div>
            <span style={{ fontSize: "13px", color: cevap === v ? seviyeRenkleri[v].text : "#4a5568", fontWeight: cevap === v ? "600" : "400" }}>{secenekler[v]}</span>
          </button>
        ))}
      </div>
    </div>
  );
}

const sayfaStil = { minHeight: "100vh", background: "linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%)", padding: "20px", boxSizing: "border-box" };
const konteynerStil = { maxWidth: "800px", margin: "0 auto" };
const baslikKartStil = { display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "20px", padding: "20px 25px", background: "rgba(255,255,255,0.08)", borderRadius: "16px", backdropFilter: "blur(10px)", border: "1px solid rgba(255,255,255,0.08)", flexWrap: "wrap", gap: "15px" };
const rozetStil = { padding: "4px 12px", borderRadius: "20px", fontSize: "12px", fontWeight: "600", display: "inline-block" };
const bolumKartStil = { background: "white", padding: "24px", borderRadius: "16px", boxShadow: "0 4px 24px rgba(0,0,0,0.08)", marginBottom: "20px" };
const bolumBaslikStil = { display: "flex", alignItems: "center", gap: "10px", marginBottom: "20px", paddingBottom: "15px", borderBottom: "2px solid #f1f5f9" };
const soruKartStil = { padding: "16px", marginBottom: "16px", background: "#fafbfc", borderRadius: "12px" };
const kaydetButonStil = { width: "100%", padding: "14px", color: "white", border: "none", borderRadius: "12px", fontSize: "15px", fontWeight: "700", transition: "all 0.3s ease" };
const notKonteynerStil = { padding: "15px", background: "#fef2f2", borderRadius: "12px", border: "1px solid #fecdd2" };
const notEtiketStil = { display: "block", marginBottom: "10px", color: "#c62828", fontWeight: "bold", fontSize: "14px" };
const notTextareaStil = { width: "100%", height: "100px", padding: "12px", boxSizing: "border-box", borderRadius: "10px", border: "1px solid #e2e8f0", fontSize: "14px", fontFamily: "inherit", resize: "vertical", outline: "none", background: "white", color: "#333" };
const spinnerStil = { width: "40px", height: "40px", border: "4px solid rgba(255,255,255,0.1)", borderTop: "4px solid #5dade2", borderRadius: "50%", animation: "spin 1s linear infinite" };

const modalOverlayStil = { position: "fixed", top: 0, left: 0, right: 0, bottom: 0, background: "rgba(0,0,0,0.7)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 1000, backdropFilter: "blur(4px)" };
const modalKartStil = { background: "white", padding: "30px", borderRadius: "20px", width: "450px", maxWidth: "90%", boxShadow: "0 10px 40px rgba(0,0,0,0.2)" };
const modalEtiketStil = { display: "block", marginBottom: "8px", fontWeight: "bold", fontSize: "13px", color: "#4a5568" };
const modalInputStil = { width: "100%", padding: "12px", borderRadius: "10px", border: "1px solid #e2e8f0", fontSize: "14px", outline: "none", boxSizing: "border-box" };
const modalKaydetButonStil = { flex: 2, padding: "12px", background: "#27ae60", color: "white", border: "none", borderRadius: "10px", fontWeight: "bold", cursor: "pointer" };
const modalIptalButonStil = { flex: 1, padding: "12px", background: "#edf2f7", color: "#4a5568", border: "none", borderRadius: "10px", fontWeight: "bold", cursor: "pointer" };

if (typeof document !== 'undefined' && !document.getElementById('checklist-spinner-style')) {
  const style = document.createElement('style');
  style.id = 'checklist-spinner-style';
  style.textContent = `@keyframes spin {to {transform: rotate(360deg); } }`;
  document.head.appendChild(style);
}
