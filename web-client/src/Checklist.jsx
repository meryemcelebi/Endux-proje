import React, { useState, useEffect } from "react";
import { useParams } from "react-router-dom";
import { api } from "./services/api";
import { getSoruDetay } from "./checklistSorulari";

/**
 * Dinamik Operatör Checklist Sayfası
 * Makine türüne göre otomatik olarak ilgili şablonun sorularını getirir.
 * Her soru için 0 (Normal), 1 (Uyarı), 2 (Kritik) şiddet seviyesi seçtirilir.
 * Ortak parametreler + makine özel parametreleri birlikte gösterilir.
 */
export default function Checklist() {
  const { id } = useParams(); // URL'den makine ID'sini al

  // --- STATE TANIMLAMALARI ---
  const [loading, setLoading] = useState(true);
  const [makineAdi, setMakineAdi] = useState("");
  const [makineTuru, setMakineTuru] = useState("");
  const [sablonId, setSablonId] = useState(null);
  const [sablonAdi, setSablonAdi] = useState("");
  const [sorular, setSorular] = useState([]); // API'den gelen kontrol maddeleri
  const [cevaplar, setCevaplar] = useState({}); // { madde_id: 0|1|2 }
  const [genelNot, setGenelNot] = useState("");
  const [saved, setSaved] = useState(false);
  const [hata, setHata] = useState(null);

  // Sayfa yüklendiğinde makine türüne göre soruları getir
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

  // --- CEVAP KAYDETME ---
  const setCevap = (madde_id, seviye) => {
    setCevaplar(prev => ({ ...prev, [madde_id]: seviye }));
    setSaved(false);
  };

  // --- FORM GÖNDER ---
  const saveChecklist = async () => {
    // Tüm soruların cevaplanıp cevaplanmadığını kontrol et
    const cevaplanmamis = sorular.filter(s => cevaplar[s.madde_id] === undefined);
    if (cevaplanmamis.length > 0) {
      alert(`Lütfen tüm soruları yanıtlayın! (${cevaplanmamis.length} soru eksik)`);
      return;
    }

    // Yüksek risk kontrolü
    const kritikSorular = sorular.filter(s => cevaplar[s.madde_id] === 2);
    if (kritikSorular.length > 0) {
      const devam = window.confirm(
        `⚠️ ${kritikSorular.length} adet KRİTİK (seviye 2) parametre tespit edildi!\n\nDevam etmek istiyor musunuz?`
      );
      if (!devam) return;
    }

    // API formatına dönüştür
    const answersPayload = sorular.map(s => ({
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
      console.error("Checklist kaydedilemedi:", err);
      alert("Kaydetme başarısız: " + (err.message || "Bilinmeyen hata"));
    }
  };

  // Makine türü rozet rengi
  const getTurRenk = (tur) => {
    if (tur?.includes("CNC")) return { bg: "#1e3a5f", text: "#5dade2" };
    if (tur?.includes("Pres")) return { bg: "#4a1942", text: "#c39bd3" };
    if (tur?.includes("Enjeksiyon")) return { bg: "#0e4429", text: "#52c41a" };
    return { bg: "#2c3e50", text: "#bdc3c7" };
  };

  // Ortak ve özel soruları ayır
  const ortakParametreKeys = ["sicaklik", "titresim", "ses_anomalisi", "yag_durumu"];
  const ortakSorular = sorular.filter(s => ortakParametreKeys.includes(s.teknik_parametre));
  const ozelSorular = sorular.filter(s => !ortakParametreKeys.includes(s.teknik_parametre) && s.teknik_parametre !== "form_doldurma_suresi_sn");

  const turRenk = getTurRenk(makineTuru);

  // Toplam risk skoru hesapla
  const toplamRisk = Object.values(cevaplar).reduce((acc, val) => acc + val, 0);
  const maxRisk = sorular.filter(s => s.teknik_parametre !== "form_doldurma_suresi_sn").length * 2;
  const riskYuzdesi = maxRisk > 0 ? Math.round((toplamRisk / maxRisk) * 100) : 0;

  if (loading) {
    return (
      <div style={sayfaStil}>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", height: "60vh" }}>
          <div style={spinnerStil}></div>
          <p style={{ color: "#a0aec0", marginTop: "20px", fontSize: "16px" }}>Checklist soruları yükleniyor...</p>
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
        </div>
      </div>
    );
  }

  return (
    <div style={sayfaStil}>
      <div style={konteynerStil}>

        {/* BAŞLIK ALANI */}
        <div style={baslikKartStil}>
          <div style={{ display: "flex", alignItems: "center", gap: "15px", flexWrap: "wrap" }}>
            <div style={{ width: "50px", height: "50px", borderRadius: "14px", background: `linear-gradient(135deg, ${turRenk.bg}, ${turRenk.text}30)`, display: "flex", alignItems: "center", justifyContent: "center", fontSize: "24px" }}>
              {makineTuru?.includes("CNC") ? "⚙️" : makineTuru?.includes("Pres") ? "🔨" : "💉"}
            </div>
            <div>
              <h2 style={{ margin: 0, color: "white", fontSize: "20px", fontWeight: "700" }}>
                {makineAdi}
              </h2>
              <div style={{ display: "flex", gap: "8px", marginTop: "6px", flexWrap: "wrap" }}>
                <span style={{ ...rozetStil, background: turRenk.bg, color: turRenk.text, border: `1px solid ${turRenk.text}40` }}>
                  {makineTuru}
                </span>
                <span style={{ ...rozetStil, background: "rgba(255,255,255,0.1)", color: "#a0aec0" }}>
                  ID: {id}
                </span>
                {sablonAdi && (
                  <span style={{ ...rozetStil, background: "rgba(52,152,219,0.15)", color: "#5dade2" }}>
                    📋 {sablonAdi}
                  </span>
                )}
              </div>
            </div>
          </div>

          {/* Risk Göstergesi */}
          {Object.keys(cevaplar).length > 0 && (
            <div style={{ textAlign: "center", minWidth: "100px" }}>
              <div style={{
                fontSize: "28px", fontWeight: "800",
                color: riskYuzdesi < 25 ? "#2ecc71" : riskYuzdesi < 50 ? "#f39c12" : "#e74c3c"
              }}>
                %{riskYuzdesi}
              </div>
              <div style={{ fontSize: "11px", color: "#718096", textTransform: "uppercase", letterSpacing: "1px" }}>Risk Skoru</div>
            </div>
          )}
        </div>

        {/* ═══════════ ORTAK SİSTEM PARAMETRELERİ ═══════════ */}
        {ortakSorular.length > 0 && (
          <div style={bolumKartStil}>
            <div style={bolumBaslikStil}>
              <span style={{ fontSize: "18px" }}>🔧</span>
              <h3 style={{ margin: 0, color: "#2d3748", fontSize: "16px", fontWeight: "700" }}>
                Ortak Sistem Parametreleri
              </h3>
              <span style={{ fontSize: "12px", color: "#a0aec0", marginLeft: "auto" }}>Tüm Makineler</span>
            </div>

            {ortakSorular.map((soru, idx) => (
              <SoruKarti
                key={soru.madde_id}
                soru={soru}
                index={idx + 1}
                cevap={cevaplar[soru.madde_id]}
                onCevapSec={(seviye) => setCevap(soru.madde_id, seviye)}
              />
            ))}
          </div>
        )}

        {/* ═══════════ MAKİNE ÖZEL PARAMETRELERİ ═══════════ */}
        {ozelSorular.length > 0 && (
          <div style={bolumKartStil}>
            <div style={bolumBaslikStil}>
              <span style={{ fontSize: "18px" }}>
                {makineTuru?.includes("CNC") ? "⚙️" : makineTuru?.includes("Pres") ? "🔨" : "💉"}
              </span>
              <h3 style={{ margin: 0, color: "#2d3748", fontSize: "16px", fontWeight: "700" }}>
                {makineTuru} Özel Parametreleri
              </h3>
              <span style={{ fontSize: "12px", color: turRenk.text, marginLeft: "auto", background: `${turRenk.bg}60`, padding: "3px 10px", borderRadius: "12px" }}>
                {ozelSorular.length} Soru
              </span>
            </div>

            {ozelSorular.map((soru, idx) => (
              <SoruKarti
                key={soru.madde_id}
                soru={soru}
                index={idx + 1}
                cevap={cevaplar[soru.madde_id]}
                onCevapSec={(seviye) => setCevap(soru.madde_id, seviye)}
              />
            ))}
          </div>
        )}

        {/* ═══════════ GENEL NOT ═══════════ */}
        <div style={bolumKartStil}>
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

          {/* İlerleme ve Kaydet */}
          <div style={{ marginTop: "20px", display: "flex", alignItems: "center", justifyContent: "space-between", flexWrap: "wrap", gap: "15px" }}>
            <div style={{ fontSize: "13px", color: "#718096" }}>
              <span style={{ fontWeight: "bold", color: Object.keys(cevaplar).length === sorular.filter(s => s.teknik_parametre !== "form_doldurma_suresi_sn").length ? "#2ecc71" : "#f39c12" }}>
                {Object.keys(cevaplar).length}
              </span>
              {" / "}
              {sorular.filter(s => s.teknik_parametre !== "form_doldurma_suresi_sn").length} soru yanıtlandı
            </div>

            <button
              onClick={saveChecklist}
              disabled={saved}
              style={{
                ...kaydetButonStil,
                background: saved
                  ? "linear-gradient(135deg, #2ecc71, #27ae60)"
                  : "linear-gradient(135deg, #0f3460, #16213e)",
                opacity: saved ? 0.8 : 1,
                cursor: saved ? "default" : "pointer",
              }}
            >
              {saved ? "✔ Kaydedildi" : "📤 Kaydet ve Gönder"}
            </button>
          </div>
        </div>

      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════
// SORU KARTI BİLEŞENİ
// Her checklist sorusu için 0/1/2 seçenekli kart
// ═══════════════════════════════════════════════════════════════
function SoruKarti({ soru, index, cevap, onCevapSec }) {
  const detay = getSoruDetay(soru.teknik_parametre);
  const soruAdi = detay?.baslik || soru.madde_adi || "Bilinmeyen Soru";
  const ikon = detay?.ikon || "📋";
  const secenekler = detay?.secenekler || {
    0: "Normal / Sorun Yok",
    1: "Hafif Anormallik Var",
    2: "Ciddi / Kritik Sorun"
  };

  // Seviye renkleri
  const seviyeRenkleri = {
    0: { bg: "#f0fdf4", border: "#bbf7d0", text: "#166534", accent: "#22c55e", label: "Normal" },
    1: { bg: "#fffbeb", border: "#fde68a", text: "#92400e", accent: "#f59e0b", label: "Uyarı" },
    2: { bg: "#fef2f2", border: "#fecaca", text: "#991b1b", accent: "#ef4444", label: "Kritik" }
  };

  return (
    <div style={{
      ...soruKartStil,
      borderLeft: cevap !== undefined
        ? `4px solid ${seviyeRenkleri[cevap].accent}`
        : "4px solid #e2e8f0"
    }}>
      {/* Soru Başlığı */}
      <div style={{ display: "flex", alignItems: "center", gap: "10px", marginBottom: "12px" }}>
        <span style={{ fontSize: "20px" }}>{ikon}</span>
        <div style={{ flex: 1 }}>
          <span style={{ fontWeight: "700", color: "#2d3748", fontSize: "15px" }}>
            {index}. {soruAdi}
          </span>
          {soru.teknik_parametre && (
            <span style={{ display: "block", fontSize: "11px", color: "#a0aec0", marginTop: "2px", fontFamily: "monospace" }}>
              {soru.teknik_parametre}
            </span>
          )}
        </div>
        {cevap !== undefined && (
          <span style={{
            padding: "3px 10px",
            borderRadius: "20px",
            fontSize: "11px",
            fontWeight: "700",
            background: seviyeRenkleri[cevap].bg,
            color: seviyeRenkleri[cevap].text,
            border: `1px solid ${seviyeRenkleri[cevap].border}`
          }}>
            {seviyeRenkleri[cevap].label}
          </span>
        )}
      </div>

      {/* Seçenekler */}
      <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
        {[0, 1, 2].map(seviye => {
          const r = seviyeRenkleri[seviye];
          const secili = cevap === seviye;

          return (
            <button
              key={seviye}
              onClick={() => onCevapSec(seviye)}
              style={{
                display: "flex",
                alignItems: "flex-start",
                gap: "10px",
                padding: "10px 14px",
                borderRadius: "10px",
                border: secili ? `2px solid ${r.accent}` : "2px solid #e8ecf1",
                background: secili ? r.bg : "#fafbfc",
                cursor: "pointer",
                textAlign: "left",
                transition: "all 0.2s ease",
                outline: "none",
              }}
            >
              {/* Seviye Numarası */}
              <div style={{
                width: "26px", height: "26px", borderRadius: "50%",
                display: "flex", alignItems: "center", justifyContent: "center",
                fontWeight: "800", fontSize: "13px", flexShrink: 0,
                background: secili ? r.accent : "#e2e8f0",
                color: secili ? "white" : "#a0aec0",
                transition: "all 0.2s ease",
              }}>
                {seviye}
              </div>
              {/* Açıklama */}
              <span style={{
                fontSize: "13px",
                color: secili ? r.text : "#4a5568",
                fontWeight: secili ? "600" : "400",
                lineHeight: "1.4",
              }}>
                {secenekler[seviye]}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}


// ═══════════════════════════════════════════════════════════════
// GÖRSEL STİLLER
// ═══════════════════════════════════════════════════════════════
const sayfaStil = {
  minHeight: "100vh",
  background: "linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%)",
  padding: "20px",
  boxSizing: "border-box",
};

const konteynerStil = {
  maxWidth: "800px",
  margin: "0 auto",
};

const baslikKartStil = {
  display: "flex",
  justifyContent: "space-between",
  alignItems: "center",
  marginBottom: "20px",
  padding: "20px 25px",
  background: "rgba(255,255,255,0.08)",
  borderRadius: "16px",
  backdropFilter: "blur(10px)",
  border: "1px solid rgba(255,255,255,0.08)",
  flexWrap: "wrap",
  gap: "15px",
};

const rozetStil = {
  padding: "4px 12px",
  borderRadius: "20px",
  fontSize: "12px",
  fontWeight: "600",
  display: "inline-block",
};

const bolumKartStil = {
  background: "white",
  padding: "24px",
  borderRadius: "16px",
  boxShadow: "0 4px 24px rgba(0,0,0,0.08)",
  marginBottom: "20px",
};

const bolumBaslikStil = {
  display: "flex",
  alignItems: "center",
  gap: "10px",
  marginBottom: "20px",
  paddingBottom: "15px",
  borderBottom: "2px solid #f1f5f9",
};

const soruKartStil = {
  padding: "16px",
  marginBottom: "16px",
  background: "#fafbfc",
  borderRadius: "12px",
  transition: "all 0.2s ease",
};

const kaydetButonStil = {
  padding: "14px 32px",
  color: "white",
  border: "none",
  borderRadius: "12px",
  fontSize: "15px",
  fontWeight: "700",
  transition: "all 0.3s ease",
  boxShadow: "0 4px 15px rgba(15, 52, 96, 0.3)",
  letterSpacing: "0.5px",
};

const notKonteynerStil = {
  padding: "15px",
  background: "#fef2f2",
  borderRadius: "12px",
  border: "1px solid #fecdd2",
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
  borderRadius: "10px",
  border: "1px solid #e2e8f0",
  fontSize: "14px",
  fontFamily: "inherit",
  resize: "vertical",
  outline: "none",
  transition: "border-color 0.2s",
  background: "white",
};

const spinnerStil = {
  width: "40px",
  height: "40px",
  border: "4px solid rgba(255,255,255,0.1)",
  borderTop: "4px solid #5dade2",
  borderRadius: "50%",
  animation: "spin 1s linear infinite",
};

// CSS animasyon için global stil ekle
if (typeof document !== 'undefined' && !document.getElementById('checklist-spinner-style')) {
  const style = document.createElement('style');
  style.id = 'checklist-spinner-style';
  style.textContent = `@keyframes spin { to { transform: rotate(360deg); } }`;
  document.head.appendChild(style);
}
