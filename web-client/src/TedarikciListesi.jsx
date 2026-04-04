import React, { useState, useEffect } from "react";
import Sidebar from "./Sidebar";
import Navbar from "./Navbar";
import { api } from "./services/api";
import FirmModal from "./components/FirmModal";

export default function TedarikciListesi() {
  const [activeTab, setActiveTab] = useState("tedarikciler");
  const [searchTerm, setSearchTerm] = useState("");
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [tedarikciRatingId, setTedarikciRatingId] = useState(null);
  const [tedarikciRatingValue, setTedarikciRatingValue] = useState(0);
  const [tedarikciRatingComment, setTedarikciRatingComment] = useState("");

  const [tedarikciler, setTedarikciler] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchSuppliers = async () => {
      try {
        const allFirms = await api.getFirms();
        const suppliersOnly = allFirms.filter(f => f.tip === "Tedarikçi");
        setTedarikciler(suppliersOnly);
      } catch (error) {
        console.error("Tedarikçi verileri çekilirken hata:", error);
      } finally {
        setLoading(false);
      }
    };
    fetchSuppliers();
  }, []);

  const handleSaveFirm = async (firmData) => {
    try {
      const newFirm = await api.addFirm(firmData);
      // Map to the format used in this component
      const newSupplier = {
        tedarikci_id: newFirm.id,
        firma_adi: newFirm.ad,
        telefon: newFirm.telefon,
        email: newFirm.email,
        adres: newFirm.adres,
        aktiflik: true
      };
      setTedarikciler([...tedarikciler, newSupplier]);
      setIsModalOpen(false);
      alert("Tedarikçi başarıyla eklendi!");
    } catch (error) {
      alert("Tedarikçi eklenirken hata oluştu!");
    }
  };

  const handleTedarikciRateSave = (id) => {
    setTedarikciler(tedarikciler.map(t => (t.tedarikci_id || t.id) === id ? { ...t, ortalama_puan: tedarikciRatingValue, yorum: tedarikciRatingComment } : t));
    setTedarikciRatingId(null);
    setTedarikciRatingValue(0);
    setTedarikciRatingComment("");
    alert("Puanlama ve yorum kaydedildi!");
  };



  // bozulmaSayisi >= 3 is the critical alert trigger
  const [parcaStoklari] = useState([
    { id: 201, ad: "M6 Rulman", makineTuru: "CNC Lazer Kesim - L202", tedarikci: "ABC Makine Parçaları A.Ş.", stok: 150, bozulmaSayisi: 0, tahminiOmur: 5000, parcaMaliyeti: 450, tedarikSuresi: 2 },
    { id: 202, ad: "Hidrolik Filtre", makineTuru: "Pres Makinesi - A101", tedarikci: "Marmara Endüstriyel Yağlar", stok: 20, bozulmaSayisi: 1, tahminiOmur: 2000, parcaMaliyeti: 1200, tedarikSuresi: 5 },
    { id: 203, ad: "Pto Sensör X-V2", makineTuru: "Enjeksiyon Makinesi - E500", tedarikci: "Kaan Sensör ve Otomasyon", stok: 5, bozulmaSayisi: 3, tahminiOmur: 8000, parcaMaliyeti: 2800, tedarikSuresi: 10 },
    { id: 204, ad: "Spindle Motoru", makineTuru: "Hidrolik Güç Ünitesi - H05", tedarikci: "Delta Motor Revizyon", stok: 2, bozulmaSayisi: 4, tahminiOmur: 12000, parcaMaliyeti: 15000, tedarikSuresi: 15 },
  ]);

  // Tab Filtering
  const filteredTedarikciler = tedarikciler.filter(
    (t) => (t.firma_adi || t.ad || "").toLowerCase().includes(searchTerm.toLowerCase()) ||
      (t.email || "").toLowerCase().includes(searchTerm.toLowerCase())
  );

  const renderTabs = () => (
    <div style={tabContainerStyle}>
      <button 
        style={activeTab === "tedarikciler" ? activeTabStyle : inactiveTabStyle}
        onClick={() => setActiveTab("tedarikciler")}
        onMouseOver={(e) => { if(activeTab !== "tedarikciler") e.target.style.background = "rgba(255,255,255,0.15)"; }}
        onMouseOut={(e) => { if(activeTab !== "tedarikciler") e.target.style.background = "rgba(255,255,255,0.05)"; }}
      >
        Tedarikçi Listesi
      </button>

      <button 
        style={activeTab === "stok" ? activeTabStyle : inactiveTabStyle}
        onClick={() => setActiveTab("stok")}
        onMouseOver={(e) => { if(activeTab !== "stok") e.target.style.background = "rgba(255,255,255,0.15)"; }}
        onMouseOut={(e) => { if(activeTab !== "stok") e.target.style.background = "rgba(255,255,255,0.05)"; }}
      >
        Parça Stok ve Performans
      </button>
    </div>
  );

  return (
    <div style={{ display: "flex", background: "#f5f6fa", minHeight: "100vh" }}>
      <Sidebar />

      <div style={{ flex: 1, display: "flex", flexDirection: "column", height: "100vh", overflow: "hidden" }}>
        <Navbar />

        <div style={{ padding: "30px", flex: 1, overflowY: "auto" }}>

          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-end", marginBottom: "25px" }}>
            <div>
              <h2 style={{ margin: 0, color: "#0f3460", fontSize: "28px", letterSpacing: "1px" }}>Tedarikçi ve Stok Yönetimi</h2>
              <p style={{ margin: "5px 0 0 0", color: "#7f8c8d", fontSize: "14px" }}>
                Tedarikçileri, dış servis puanlarını ve parça stok/arıza istatistiklerini buradan yönetin.
              </p>
            </div>

            {/* Sağ üst köşedeki yönetim butonları */}
            <div style={{ display: "flex", gap: "15px", alignItems: "center" }}>
              {/* Yeni Tedarikçi eklemek için modalı açan buton */}
              <button 
                onClick={() => setIsModalOpen(true)}
                style={{
                  padding: "12px 25px",
                  background: "#27ae60",
                  color: "white",
                  border: "none",
                  borderRadius: "10px",
                  fontWeight: "bold",
                  cursor: "pointer",
                  boxShadow: "0 4px 15px rgba(39, 174, 96, 0.3)"
                }}
              >
                + Tedarikçi Ekle
              </button>
              {activeTab === "tedarikciler" && (
                <input
                  type="text"
                  placeholder="🔍 Firma adı veya e-posta ara..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  style={searchInputStyle}
                />
              )}
            </div>
          </div>

          {renderTabs()}

          <div style={contentCardStyle} className="glass-card-animation">
            {activeTab === "tedarikciler" && (
              <table style={tableStyle}>
                <thead>
                  <tr>
                    <th style={thStyle}>Firma Adı</th>
                    <th style={thStyle}>Yetkili Kişi</th>
                    <th style={thStyle}>İletişim Bilgileri</th>
                    <th style={thStyle}>Veri / Vergi No</th>
                    <th style={thStyle}>Güvenilirlik</th>
                    <th style={thStyle}>Değerlendirme</th>
                    <th style={thStyle}>Durum</th>
                    <th style={thStyle}>İşlem</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredTedarikciler.length > 0 ? (
                    filteredTedarikciler.map((t) => (
                      <React.Fragment key={t.tedarikci_id || t.id}>
                      <tr style={trStyle}>
                        <td style={{ ...tdStyle, fontWeight: "bold", color: "#0f3460" }}>
                          {t.firma_adi || t.ad}
                          <div style={{ fontSize: "11px", color: "#95a5a6", fontWeight: "normal" }}>Kayıt: {t.kayit_tarihi ? new Date(t.kayit_tarihi).toLocaleDateString("tr-TR") : "-"}</div>
                        </td>
                        <td style={tdStyle}>{t.yetkili_kisi || "-"}</td>
                        <td style={tdStyle}>
                          <div style={{ fontSize: "13px" }}>📞 {t.telefon}</div>
                          <div style={{ fontSize: "12px", color: "#7f8c8d" }}>✉️ {t.email}</div>
                        </td>
                        <td style={tdStyle}>
                          <code style={{ background: "#f8f9fa", padding: "2px 6px", borderRadius: "4px", fontSize: "12px" }}>{t.veri_no || "BELİRTİLMEMİŞ"}</code>
                        </td>
                        <td style={tdStyle}>
                           <div style={{
                             display: "inline-block",
                             padding: "4px 10px",
                             borderRadius: "20px",
                             fontSize: "12px",
                             fontWeight: "bold",
                             background: t.guvenilirlik_skoru >= 90 ? "rgba(46, 204, 113, 0.15)" : t.guvenilirlik_skoru >= 70 ? "rgba(241, 196, 15, 0.15)" : "rgba(231, 76, 60, 0.15)",
                             color: t.guvenilirlik_skoru >= 90 ? "#27ae60" : t.guvenilirlik_skoru >= 70 ? "#f39c12" : "#e74c3c"
                           }}>
                             %{t.guvenilirlik_skoru || 0} Güven
                           </div>
                        </td>
                        <td style={tdStyle}>
                          <div style={{ display: "flex", gap: "2px", alignItems: "center" }}>
                            {[1, 2, 3, 4, 5].map((star) => (
                              <span key={star} style={{ fontSize: "18px", color: star <= Math.round(t.ortalama_puan || 0) ? "#f39c12" : "#dfe6e9" }}>
                                ★
                              </span>
                            ))}
                            {t.ortalama_puan > 0 && <strong style={{ marginLeft: "6px", color: "#0f3460", fontSize: "13px" }}>{t.ortalama_puan}</strong>}
                          </div>
                          {t.yorum && <div style={{ fontSize: "12px", color: "#7f8c8d", marginTop: "4px", fontStyle: "italic" }}>💬 {t.yorum}</div>}
                        </td>
                        <td style={tdStyle}>
                          <span style={t.aktiflik !== false ? badgeActive : badgeInactive}>
                            {t.aktiflik !== false ? "Aktif" : "Pasif"}
                          </span>
                        </td>
                        <td style={tdStyle}>
                          <button onClick={() => { setTedarikciRatingId(tedarikciRatingId === (t.tedarikci_id || t.id) ? null : (t.tedarikci_id || t.id)); setTedarikciRatingValue(Math.round(t.ortalama_puan || 0)); setTedarikciRatingComment(t.yorum || ""); }} style={{ padding: "8px 18px", color: "white", border: "none", borderRadius: "8px", fontWeight: "bold", cursor: "pointer", fontSize: "13px", background: tedarikciRatingId === (t.tedarikci_id || t.id) ? "#e74c3c" : "#e94560" }}>
                            {tedarikciRatingId === (t.tedarikci_id || t.id) ? "Kapat" : "⭐ Puanla"}
                          </button>
                        </td>
                      </tr>
                      {tedarikciRatingId === (t.tedarikci_id || t.id) && (
                        <tr>
                          <td colSpan="8" style={{ padding: "0 16px 20px 16px", background: "#f8f9fa", borderBottom: "2px solid #e1e5eb" }}>
                            <div style={{ padding: "20px", background: "white", borderRadius: "12px", border: "1px solid #e1e5eb", marginTop: "10px" }}>
                              <div style={{ marginBottom: "12px", fontWeight: "bold", color: "#0f3460", fontSize: "15px" }}>Tedarikçi Puanlaması - {t.firma_adi || t.ad}</div>
                              <div style={{ display: "flex", gap: "6px", marginBottom: "15px" }}>
                                {[1, 2, 3, 4, 5].map(star => (
                                  <span key={star} onClick={() => setTedarikciRatingValue(star)} style={{ cursor: "pointer", fontSize: "28px", color: tedarikciRatingValue >= star ? "#f39c12" : "#dfe6e9", transition: "0.2s" }}>★</span>
                                ))}
                                {tedarikciRatingValue > 0 && <span style={{ alignSelf: "center", marginLeft: "10px", fontWeight: "bold", color: "#f39c12", fontSize: "18px" }}>{tedarikciRatingValue}/5</span>}
                              </div>
                              <textarea value={tedarikciRatingComment} onChange={(e) => setTedarikciRatingComment(e.target.value)} placeholder="Yorum yazınız..." style={{ width: "100%", padding: "12px", borderRadius: "8px", border: "1px solid #ddd", outline: "none", minHeight: "70px", fontSize: "14px", resize: "vertical", boxSizing: "border-box" }} />
                              <div style={{ display: "flex", justifyContent: "flex-end", marginTop: "12px" }}>
                                <button onClick={() => handleTedarikciRateSave(t.tedarikci_id || t.id)} disabled={tedarikciRatingValue === 0} style={{ padding: "10px 25px", background: "#27ae60", color: "white", border: "none", borderRadius: "8px", fontWeight: "bold", cursor: "pointer", fontSize: "14px", opacity: tedarikciRatingValue === 0 ? 0.5 : 1 }}>Kaydet</button>
                              </div>
                            </div>
                          </td>
                        </tr>
                      )}
                    </React.Fragment>
                    ))
                  ) : (
                    <tr>
                      <td colSpan="8" style={{ padding: "40px", textAlign: "center", color: "#95a5a6" }}>
                        Arama kriterlerine uygun tedarikçi bulunamadı.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            )}


            {activeTab === "stok" && (
              <div style={{ animation: "fadeIn 0.5s ease-out" }}>
                {/* UYARI KISMI: 3 KEZ BOZULAN PARÇALAR */}
                {parcaStoklari.filter(p => p.bozulmaSayisi >= 3).map(p => (
                  <div key={`alert-${p.id}`} style={alertBoxStyle}>
                    <div style={{ fontSize: "24px" }}><span style={iconBlinkStyle}>⚠️</span></div>
                    <div>
                        <div style={{ fontWeight: "bold", fontSize: "16px", marginBottom: "4px" }}>Sistem Ciddi Uyarı Olayı Bildirdi!</div>
                        <div>"{p.ad}" adlı parça, "{p.tedarikci}" tedarikçisinden alındığı halde <strong>üst üste {p.bozulmaSayisi} kez arızalanmıştır!</strong> Tedarikçi firmanın derhal değiştirilmesi önerilmektedir.</div>
                    </div>
                  </div>
                ))}

                <table style={tableStyle}>
                  <thead>
                    <tr>
                      <th style={thStyle}>Parça Adı</th>
                      <th style={thStyle}>Kullanıldığı Makine</th>
                      <th style={thStyle}>Sağlayıcı (Tedarikçi)</th>
                      <th style={thStyle}>Tahmini Ömür</th>
                      <th style={thStyle}>Parça Maliyeti</th>
                      <th style={thStyle}>Tedarik Süresi</th>
                      <th style={thStyle}>Stok Seviyesi</th>
                      <th style={thStyle}>Arıza/Bozulma</th>
                      <th style={thStyle}>Sistem Notu</th>
                    </tr>
                  </thead>
                  <tbody>
                    {parcaStoklari.map((p) => {
                      const isKritik = p.bozulmaSayisi >= 3;
                      return (
                        <tr key={p.id} style={{ ...trStyle, background: isKritik ? "rgba(231, 76, 60, 0.08)" : "transparent" }}>
                          <td style={{ ...tdStyle, color: "#0f3460", fontWeight: "bold", fontSize: "15px" }}>
                            {p.ad}
                            {isKritik && <span style={iconBlinkStyle}> ⚠️</span>}
                          </td>
                          <td style={tdStyle}>{p.makineTuru}</td>
                           <td style={{ ...tdStyle, color: isKritik ? "#ff7675" : "#555" }}>{p.tedarikci}</td>
                           <td style={tdStyle}>
                              <div style={{ color: "#2980b9", fontWeight: "bold" }}>{p.tahminiOmur} Saat</div>
                              <div style={{ fontSize: "11px", color: "#95a5a6" }}>Çalışma Ömrü</div>
                           </td>
                           <td style={tdStyle}>
                              <div style={{ color: "#27ae60", fontWeight: "bold" }}>{p.parcaMaliyeti.toLocaleString()} ₺</div>
                              <div style={{ fontSize: "11px", color: "#95a5a6" }}>Birim Fiyat</div>
                           </td>
                           <td style={tdStyle}>
                              <div style={{ color: "#e67e22", fontWeight: "bold" }}>{p.tedarikSuresi} Gün</div>
                              <div style={{ fontSize: "11px", color: "#95a5a6" }}>Lojistik Süre</div>
                           </td>
                          <td style={tdStyle}>
                            <div style={stokKapsayiciStyle}>
                              <div style={{
                                ...stokBar, 
                                width: `${Math.min((p.stok / 150) * 100, 100)}%`,
                                background: p.stok > 20 ? "linear-gradient(90deg, #27ae60, #2ecc71)" : p.stok > 5 ? "linear-gradient(90deg, #f39c12, #f1c40f)" : "linear-gradient(90deg, #c0392b, #e74c3c)"
                              }}></div>
                            </div>
                            <span style={{ fontSize: "12px", marginTop: "6px", display: "inline-block", color: "#bbb", fontWeight: "bold" }}>Miktar: {p.stok}</span>
                          </td>
                          <td style={{ ...tdStyle, color: isKritik ? "#ff4757" : "#aaa", fontWeight: isKritik ? "bold" : "normal" }}>
                            {p.bozulmaSayisi} Kez
                          </td>
                          <td style={tdStyle}>
                            {isKritik ? (
                               <button 
                                 style={degisimButtonStyle}
                                 onMouseOver={(e) => e.target.style.background = "rgba(255, 118, 117, 0.15)"}
                                 onMouseOut={(e) => e.target.style.background = "transparent"}
                               >
                                 Sözleşmeyi İptal Et
                               </button>
                            ) : (
                               <span style={{ color: "#2ecc71", display: "flex", alignItems: "center", gap: "5px" }}>
                                  <span style={{ fontSize: "18px" }}>✓</span> Sorunsuz
                               </span>
                            )}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>

          <FirmModal 
            isOpen={isModalOpen} 
            onClose={() => setIsModalOpen(false)} 
            onSave={handleSaveFirm} 
            initialType="Tedarikçi"
          />

        </div>
      </div>
    </div>
  );
}

// STYLES
const tabContainerStyle = {
  display: "flex",
  gap: "12px",
  marginBottom: "25px",
  borderBottom: "1px solid #e1e5eb",
  paddingBottom: "15px"
};

const activeTabStyle = {
  background: "linear-gradient(135deg, #e94560 0%, #c0392b 100%)",
  color: "white",
  border: "none",
  padding: "14px 28px",
  borderRadius: "10px",
  fontSize: "15px",
  fontWeight: "bold",
  cursor: "pointer",
  transition: "all 0.3s ease",
  boxShadow: "0 6px 20px rgba(233, 69, 96, 0.4)",
  transform: "translateY(-2px)"
};

const inactiveTabStyle = {
  background: "#eee",
  color: "#7f8c8d",
  border: "1px solid #ddd",
  padding: "14px 28px",
  borderRadius: "10px",
  fontSize: "15px",
  fontWeight: "bold",
  cursor: "pointer",
  transition: "all 0.3s ease",
};

const searchInputStyle = {
  padding: "14px 20px",
  border: "1px solid #ddd",
  borderRadius: "30px",
  fontSize: "14px",
  outline: "none",
  width: "320px",
  background: "white",
  boxShadow: "0 2px 10px rgba(0,0,0,0.05)",
  color: "#333",
  transition: "all 0.3s ease"
};

const contentCardStyle = {
  background: "white",
  padding: "30px",
  borderRadius: "20px",
  boxShadow: "0 10px 40px 0 rgba(0, 0, 0, 0.05)",
  border: "1px solid #eee",
  overflowX: "auto"
};

const tableStyle = { width: "100%", borderCollapse: "collapse", minWidth: "900px" };

const thStyle = {
  textAlign: "left",
  padding: "16px",
  background: "#f8f9fa",
  color: "#34495e",
  fontWeight: "bold",
  fontSize: "13px",
  textTransform: "uppercase",
  letterSpacing: "1px",
  borderBottom: "2px solid #e1e5eb",
  borderTopLeftRadius: "8px",
  borderTopRightRadius: "8px"
};

const tdStyle = {
  padding: "18px 16px",
  fontSize: "14px",
  color: "#555",
  borderBottom: "1px solid #f1f2f6",
  verticalAlign: "middle"
};

const trStyle = { 
  transition: "background 0.2s ease" 
};

const badgeActive = {
  padding: "6px 14px",
  borderRadius: "20px",
  fontSize: "12px",
  fontWeight: "bold",
  background: "rgba(46, 204, 113, 0.15)",
  color: "#2ecc71",
  boxShadow: "0 0 10px rgba(46, 204, 113, 0.2)",
  border: "1px solid rgba(46, 204, 113, 0.3)"
};

const badgeInactive = {
  padding: "6px 14px",
  borderRadius: "20px",
  fontSize: "12px",
  fontWeight: "bold",
  background: "rgba(231, 76, 60, 0.15)",
  color: "#e74c3c",
  border: "1px solid rgba(231, 76, 60, 0.3)"
};

const alertBoxStyle = {
  background: "linear-gradient(135deg, rgba(231, 76, 60, 0.95), rgba(192, 57, 43, 0.95))",
  color: "white",
  padding: "20px 25px",
  borderRadius: "15px",
  marginBottom: "25px",
  boxShadow: "0 8px 25px rgba(231, 76, 60, 0.4)",
  borderLeft: "6px solid #ff9ff3",
  fontSize: "15px",
  display: "flex",
  alignItems: "center",
  gap: "15px",
};

const iconBlinkStyle = {
  display: "inline-block",
  animation: "blink 1s infinite alternate"
};

const stokKapsayiciStyle = {
  height: "6px",
  width: "100%",
  background: "#f1f2f6",
  borderRadius: "10px",
  overflow: "hidden",
  display: "flex",
  boxShadow: "inset 0 1px 3px rgba(0,0,0,0.1)"
};

const stokBar = {
  height: "100%",
  borderRadius: "10px",
  transition: "width 1.5s cubic-bezier(0.4, 0, 0.2, 1)",
  boxShadow: "0 0 10px rgba(255,255,255,0.3)"
};

const degisimButtonStyle = {
  background: "transparent",
  color: "#ff7675",
  border: "1px solid rgba(255, 118, 117, 0.5)",
  padding: "8px 14px",
  borderRadius: "8px",
  fontSize: "13px",
  fontWeight: "bold",
  cursor: "pointer",
  transition: "all 0.3s ease",
  boxShadow: "0 2px 10px rgba(255, 118, 117, 0.1)"
};

// Keyframes
if (typeof document !== "undefined") {
  const style = document.createElement("style");
  style.innerHTML = `
    @keyframes blink {
      0% { opacity: 1; text-shadow: 0 0 15px rgba(255,0,0,0.8); }
      100% { opacity: 0.4; }
    }
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(10px); }
      to { opacity: 1; transform: translateY(0); }
    }
    .glass-card-animation {
      animation: fadeIn 0.4s ease-out;
    }
    tr:hover {
      background: rgba(255, 255, 255, 0.03) !important;
    }
  `;
  document.head.appendChild(style);
}
