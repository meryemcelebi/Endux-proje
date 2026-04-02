import React, { useState } from "react";
import Sidebar from "./Sidebar";
import Navbar from "./Navbar";

export default function TedarikciListesi() {
  // Mock Data (based on Prisma schema: tedarikci_id, firma_adi, telefon, email, adres, aktiflik)
  const [tedarikciler] = useState([
    {
      tedarikci_id: 101,
      firma_adi: "ABC Makine Parçaları A.Ş.",
      telefon: "0212 555 1234",
      email: "iletisim@abcmakine.com",
      adres: "Ostim OSB, Ankara",
      aktiflik: true,
    },
    {
      tedarikci_id: 102,
      firma_adi: "Marmara Endüstriyel Yağlar",
      telefon: "0216 444 8899",
      email: "satis@marmarayag.com",
      adres: "Gebze OSB, Kocaeli",
      aktiflik: true,
    },
    {
      tedarikci_id: 103,
      firma_adi: "Kaan Sensör ve Otomasyon",
      telefon: "0232 333 4455",
      email: "info@kaansensor.net",
      adres: "Kemalpaşa, İzmir",
      aktiflik: false,
    },
  ]);

  const [searchTerm, setSearchTerm] = useState("");

  const filteredTedarikciler = tedarikciler.filter(
    (t) => t.firma_adi.toLowerCase().includes(searchTerm.toLowerCase()) ||
      t.email?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div style={{ display: "flex", background: "#f5f6fa", minHeight: "100vh" }}>
      <Sidebar />

      <div style={{ flex: 1, display: "flex", flexDirection: "column", height: "100vh", overflow: "hidden" }}>
        <Navbar />

        <div style={{ padding: "30px", flex: 1, overflowY: "auto" }}>

          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "30px" }}>
            <div>
              <h2 style={{ margin: 0, color: "#0f3460", fontSize: "24px" }}>Tedarikçi Listesi</h2>
              <p style={{ margin: "5px 0 0 0", color: "#7f8c8d" }}>Sistemde kayıtlı olan yedek parça ve hizmet tedarikçileri.</p>
            </div>

            <div>
              <input
                type="text"
                placeholder="🔍 Firma adı veya e-posta ara..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                style={searchInputStyle}
              />
            </div>
          </div>

          <div style={cardStyle}>
            <table style={tableStyle}>
              <thead>
                <tr>
                  <th style={thStyle}>ID</th>
                  <th style={thStyle}>Firma Adı</th>
                  <th style={thStyle}>Telefon</th>
                  <th style={thStyle}>E-Posta</th>
                  <th style={thStyle}>Adres</th>
                  <th style={thStyle}>Durum</th>
                </tr>
              </thead>
              <tbody>
                {filteredTedarikciler.length > 0 ? (
                  filteredTedarikciler.map((t) => (
                    <tr key={t.tedarikci_id} style={trStyle} onMouseOver={(e) => e.currentTarget.style.background = "#fafafa"} onMouseOut={(e) => e.currentTarget.style.background = "transparent"}>
                      <td style={tdStyle}><strong>#{t.tedarikci_id}</strong></td>
                      <td style={{ ...tdStyle, color: "#0f3460", fontWeight: "bold" }}>{t.firma_adi}</td>
                      <td style={tdStyle}>{t.telefon}</td>
                      <td style={tdStyle}>{t.email || "-"}</td>
                      <td style={tdStyle}>{t.adres}</td>
                      <td style={tdStyle}>
                        <span style={{
                          padding: "6px 12px",
                          borderRadius: "20px",
                          fontSize: "12px",
                          fontWeight: "bold",
                          background: t.aktiflik ? "rgba(46, 204, 113, 0.2)" : "rgba(231, 76, 60, 0.2)",
                          color: t.aktiflik ? "#27ae60" : "#c0392b"
                        }}>
                          {t.aktiflik ? "Aktif" : "Pasif"}
                        </span>
                      </td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan="6" style={{ padding: "40px", textAlign: "center", color: "#95a5a6" }}>
                      Arama kriterlerine uygun tedarikçi bulunamadı.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

        </div>
      </div>
    </div>
  );
}

// STILLER
const cardStyle = {
  background: "white",
  padding: "20px",
  borderRadius: "12px",
  boxShadow: "0 4px 15px rgba(0,0,0,0.05)",
  overflowX: "auto"
};

const searchInputStyle = {
  padding: "12px 20px",
  border: "1px solid #ddd",
  borderRadius: "30px",
  fontSize: "14px",
  outline: "none",
  width: "300px",
  background: "#fff",
  boxShadow: "0 2px 10px rgba(0,0,0,0.05)",
  color: "#333"
};

const tableStyle = { width: "100%", borderCollapse: "collapse", minWidth: "800px" };
const thStyle = {
  textAlign: "left",
  padding: "15px",
  background: "#f8f9fa",
  color: "#34495e",
  fontWeight: "bold",
  fontSize: "14px",
  borderBottom: "2px solid #e1e5eb"
};
const tdStyle = {
  padding: "15px",
  fontSize: "14px",
  color: "#555",
  borderBottom: "1px solid #f1f2f6"
};
const trStyle = { transition: "background 0.2s" };
