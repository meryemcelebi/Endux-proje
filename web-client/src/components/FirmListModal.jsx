import React from "react";

/**
 * Kayıtlı Servis Firmaları Listesi Modalı
 * Sistemdeki 'Servis' tipindeki firmaları listeler, ortalama puanlarına göre sıralar
 * ve yöneticinin bu firmaları hızlıca puanlamasına olanak tanır.
 */
export default function FirmListModal({ isOpen, onClose, firms, onPuanla }) {
  if (!isOpen) return null;

  // Sadece servis firmalarını ayıkla ve puanı en yüksek olandan başlayarak sırala
  const serviceFirms = firms.filter(f => f.tip === "Servis");
  const sortedFirms = [...serviceFirms].sort((a, b) => (b.ortalama_puan || 0) - (a.ortalama_puan || 0));

  return (
    <div style={overlayStil}>
      <div style={modalStil}>
        <div style={headerStil}>
          <h3 style={{ margin: 0, color: "#0f3460", fontSize: "20px" }}>Çalıştığımız Servis Firmaları & Kalite Listesi</h3>
          <button onClick={onClose} style={kapatButonStil}>✕</button>
        </div>

        <div style={icerikStil}>
          <table style={tabloStil}>
            <thead>
              <tr>
                <th style={thStil}>Firma & Uzmanlık</th>
                <th style={thStil}>İletişim Bilgileri</th>
                <th style={thStil}>Sorumlu Teknisyen</th>
                <th style={thStil}>Puanlama</th>
                <th style={thStil}>Durum</th>
              </tr>
            </thead>
            <tbody>
              {sortedFirms.map(f => (
                <tr key={f.id} style={{ borderBottom: "1px solid #f1f2f6" }}>
                  <td style={tdStil}>
                    <div style={{ fontWeight: "bold", color: "#2c3e50" }}>{f.ad}</div>
                    <div style={uzmanlikBadgeStil}>{f.uzmanlik_alani || "Genel Bakım"}</div>
                  </td>
                  <td style={tdStil}>
                    <div style={{ fontSize: "13px", color: "#333" }}>📞 {f.telefon}</div>
                    <div style={{ fontSize: "13px", color: "#7f8c8d", marginTop: "2px" }}>✉️ {f.email}</div>
                  </td>
                  <td style={tdStil}>
                    <div style={{ fontWeight: "bold", color: "#34495e" }}>{f.sorumlu_ad} {f.sorumlu_soyad}</div>
                    <div style={{ fontSize: "12px", color: "#95a5a6", marginTop: "2px" }}>📱 {f.sorumlu_tel || "-"}</div>
                  </td>
                  <td style={tdStil}>
                    <div style={{ display: "flex", gap: "2px", alignItems: "center" }}>
                      {[1, 2, 3, 4, 5].map(star => (
                        <span key={star}
                          onClick={() => onPuanla(f.id, star)}
                          style={{
                            cursor: "pointer",
                            fontSize: "20px",
                            color: Math.round(f.ortalama_puan || 0) >= star ? "#f39c12" : "#dfe6e9",
                            transition: "0.2s"
                          }}
                          onMouseOver={(e) => e.target.style.transform = "scale(1.2)"}
                          onMouseOut={(e) => e.target.style.transform = "scale(1)"}
                        >
                          ★
                        </span>
                      ))}
                      <strong style={{ marginLeft: "10px", color: "#0f3460" }}>{(f.ortalama_puan || 0).toFixed(1)}</strong>
                    </div>
                  </td>
                  <td style={tdStil}>
                    <span style={f.aktiflik !== false ? aktifBadgeStil : pasifBadgeStil}>
                      {f.aktiflik !== false ? "Aktif" : "Pasif"}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {sortedFirms.length === 0 && (
            <div style={{ textAlign: "center", padding: "40px", color: "#95a5a6" }}>
              Kayıtlı servis firması bulunamadı.
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

const overlayStil = {
  position: "fixed",
  top: 0,
  left: 0,
  right: 0,
  bottom: 0,
  background: "rgba(0,0,0,0.6)",
  display: "flex",
  justifyContent: "center",
  alignItems: "center",
  zIndex: 1000,
  backdropFilter: "blur(4px)"
};

const modalStil = {
  background: "white",
  width: "90%",
  maxWidth: "1100px",
  height: "85vh",
  borderRadius: "16px",
  display: "flex",
  flexDirection: "column",
  boxShadow: "0 15px 50px rgba(0,0,0,0.3)",
  overflow: "hidden"
};

const headerStil = {
  padding: "20px 30px",
  background: "#f8f9fa",
  borderBottom: "1px solid #eee",
  display: "flex",
  justifyContent: "space-between",
  alignItems: "center"
};

const icerikStil = {
  padding: "30px",
  flex: 1,
  overflowY: "auto"
};

const kapatButonStil = {
  background: "none",
  border: "none",
  fontSize: "24px",
  cursor: "pointer",
  color: "#95a5a6"
};

const tabloStil = {
  width: "100%",
  borderCollapse: "collapse",
  textAlign: "left"
};

const thStil = {
  padding: "12px",
  background: "#f8f9fa",
  color: "#7f8c8d",
  fontWeight: "bold",
  fontSize: "13px",
  textTransform: "uppercase",
  letterSpacing: "0.5px",
  borderBottom: "2px solid #e1e5eb"
};

const tdStil = {
  padding: "16px 12px",
  fontSize: "14px",
  color: "#2c3e50",
  verticalAlign: "middle"
};

const uzmanlikBadgeStil = {
  display: "inline-block",
  padding: "2px 8px",
  background: "rgba(243, 156, 18, 0.12)",
  color: "#e67e22",
  borderRadius: "4px",
  fontSize: "11px",
  fontWeight: "bold",
  marginTop: "5px"
};

const aktifBadgeStil = {
  padding: "4px 10px",
  background: "rgba(46, 204, 113, 0.15)",
  color: "#27ae60",
  borderRadius: "12px",
  fontSize: "12px",
  fontWeight: "bold"
};

const pasifBadgeStil = {
  padding: "4px 10px",
  background: "rgba(231, 76, 60, 0.15)",
  color: "#c0392b",
  borderRadius: "12px",
  fontSize: "12px",
  fontWeight: "bold"
};
