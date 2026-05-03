import React, { useState, useEffect } from "react";
import Sidebar from "./Sidebar";
import Navbar from "./Navbar";
import { api } from "./services/api";
import FirmModal from "./components/FirmModal";

export default function ServisMerkezi() {
  // --- STATE TANIMLAMALARI ---
  const [tasks, setTasks] = useState([]); // Teknik servis görev listesi (Bekleyen/Tamamlanan)
  const [firms, setFirms] = useState([]); // Sistemde kayıtlı servis firmaları ve tedarikçiler
  const [loading, setLoading] = useState(true); // Veri yükleme durumu
  const [activeTab, setActiveTab] = useState("gorevler"); // Aktif sekme kontrolü (gorevler, firmalar, onay-merkezi, disServis)
  const [isModalOpen, setIsModalOpen] = useState(false); // Firma ekleme modali durumu
  const [searchTerm, setSearchTerm] = useState(""); // Firma arama terimi
  const [modalType, setModalType] = useState("Servis"); // Modal tipi (Servis Firması mı yoksa Parça Tedarikçisi mi?)
  const [allHistory, setAllHistory] = useState([]); // Tüm servis geçmişi (Onay merkezi puanlamaları için)

  // --- DIŞ SERVİS PUANLAMA STATE'LERİ ---
  const [disRatingId, setDisRatingId] = useState(null); // Puanlanan bakım (işlem) ID'si
  const [disRatingValue, setDisRatingValue] = useState(0); // Verilen yıldız puanı

  // Dış servis listesi (allHistory'den türetilecek)
  const [disServisler, setDisServisler] = useState([]);

  let userPayload = { ad: "Bilinmeyen", rol_id: 2 };
  try {
    const payloadStr = localStorage.getItem("user_payload");
    if (payloadStr && payloadStr !== "undefined") {
      userPayload = JSON.parse(payloadStr);
    }
  } catch (err) {
    console.error("User payload parse hatası:", err);
  }
  const isAdmin = userPayload?.rol_id === 0 || userPayload?.rol_id === 1;

  // --- VERİ ÇEKME (API) ---
  useEffect(() => {
    const fetchData = async () => {
      try {
        // Görevler, firmalar ve servis geçmişini eşzamanlı olarak çek
        const [taskData, firmData, historyData] = await Promise.all([
          api.getTechTasks(),
          api.getFirms(),
          api.getAllServiceHistory()
        ]);

        const formattedTasks = taskData.map(t => ({
          ...t,
          makine_ad: t.makine?.makine_adi || t.makine_adi || "Bilinmeyen",
          ariza_notu: t.ariza_kaydi?.ariza_aciklama || t.aciklama || "Not yok",
          tarih: t.bakim_tarihi ? new Date(t.bakim_tarihi).toLocaleDateString("tr-TR") : (t.tarih || "-"),
          durum: t.durum || "ONAYLANDI"
        }));

        setTasks(formattedTasks);
        setFirms(firmData);
        setAllHistory(historyData);

        // Dış servis işlemleri (Backend verileri - Onaylanmamış olanlar)
        const liveHistory = historyData.filter(h => h.servis_firma_id && h.durum !== "TAMAMLANDI");

        setDisServisler(liveHistory);
      } catch (err) {
        console.error("Servis verileri yüklenirken hata oluştu:", err);
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, []);

  const handlePuanla = async (firmaId, puan) => {
    try {
      await api.rateFirm(firmaId, puan);
      setFirms(firms.map(f => f.id === firmaId ? { ...f, ortalama_puan: puan } : f));
    } catch (error) {
      alert("Puanlama sırasında hata oluştu!");
    }
  };



  const handleDisRateSave = async (bakimId) => {


    try {
      await api.rateMaintenance(bakimId, disRatingValue);

      // Listeyi güncelle
      const updatedHistory = allHistory.map(h =>
        h.bakim_id === bakimId
          ? { ...h, servis_puan: { ...(h.servis_puan || {}), puan: disRatingValue } }
          : h
      );
      setAllHistory(updatedHistory);
      setDisServisler(updatedHistory.filter(h => h.servis_firma_id && h.durum !== "TAMAMLANDI"));

      // Firmaları da yeniden çek (Ortalama puanların güncellenmesi için)
      const updatedFirms = await api.getFirms();
      setFirms(updatedFirms);

      setDisRatingId(null);
      setDisRatingValue(0);
      alert("İşlem puanı başarıyla kaydedildi!");
    } catch (error) {
      alert("Hata: " + error.message);
    }
  };

  const handleApproveMaintenance = async (bakimId) => {
    const record = disServisler.find(h => h.bakim_id === bakimId);
    if (!record) return;

    // Her işlem puanlanmak zorunda kontrolü
    const currentRating = record.servis_puan?.puan || record.puan || 0;
    if (currentRating === 0) {
      alert("Her işlem puanlanmak zorundadır. Lütfen önce puan veriniz.");
      return;
    }

    const confirmMsg = "Bu işlemi onaylayıp puanlama listesinden kaldırmak istediğinize emin misiniz?";
    if (!window.confirm(confirmMsg)) return;



    try {
      await api.approveMaintenance(bakimId);
      setDisServisler(disServisler.filter(h => h.bakim_id !== bakimId));
      alert("İşlem onaylandı ve listeden kaldırıldı.");
    } catch (error) {
      alert("Hata: " + error.message);
    }
  };

  const handleSaveFirm = async (firmData) => {
    try {
      await api.addFirm(firmData);
      setIsModalOpen(false);
      const updatedFirms = await api.getFirms();
      setFirms(updatedFirms);
      alert(`${firmData.tip} başarıyla eklendi!`);
    } catch (error) {
      alert("Firma eklenirken hata oluştu!");
    }
  };



  // RENDER: GÖREV LİSTESİ
  const renderGorevListesi = () => {
    // Sadece yöneticinin onayladığı veya tamamlanmış işleri göster
    const approvedTasks = tasks.filter(t => t.durum !== "BEKLEYEN");

    return (
      <div style={{ overflowX: "auto" }}>
        <table style={tableStyle}>
          <thead>
            <tr>
              <th style={thStyle}>Makine</th>
              <th style={thStyle}>Durum</th>
              <th style={thStyle}>Arıza Notu</th>
              <th style={thStyle}>Kayıt Tarihi</th>
            </tr>
          </thead>
          <tbody>
            {approvedTasks.length === 0 ? (
              <tr><td colSpan="4" style={{ textAlign: "center", padding: "40px", color: "#95a5a6" }}>Henüz onaylanmış veya devam eden bir iş kaydı bulunamadı.</td></tr>
            ) : (
              approvedTasks.map(t => (
                <tr key={t.id} style={trStyle}>
                  <td style={{ ...tdStyle, fontWeight: "bold", color: "#0f3460" }}>{t.makine_ad}</td>
                  <td style={tdStyle}>
                    <span style={t.durum === "TAMAMLANDI" ? badgeActive : { ...badgeInactive, background: "rgba(46, 204, 113, 0.1)", color: "#27ae60", border: "1px solid rgba(46, 204, 113, 0.2)" }}>
                      {t.durum === "ONAYLANDI" ? "İŞLEMDE" : t.durum}
                    </span>
                  </td>
                  <td style={{ ...tdStyle, maxWidth: "300px", whiteSpace: "normal" }}>{t.ariza_notu}</td>
                  <td style={tdStyle}>
                    <div style={{ fontSize: "14px", color: "#555" }}>📅 {t.tarih}</div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    );
  };

  // RENDER: SİSTEM FIRMALARI (Servis Firmaları)



  // RENDER: SİSTEM FIRMALARI (Servis Firmaları)
  const [firmRatingId, setFirmRatingId] = useState(null);
  const [firmRatingValue, setFirmRatingValue] = useState(0);
  const [firmRatingComment, setFirmRatingComment] = useState("");

  const handleFirmRateSave = (id) => {
    setFirms(firms.map(f => f.id === id ? { ...f, ortalama_puan: firmRatingValue, yorum: firmRatingComment } : f));
    setFirmRatingId(null);
    setFirmRatingValue(0);
    setFirmRatingComment("");
    alert("Firma puanlaması ve yorumu kaydedildi!");
  };

  const handleDeleteFirm = async (firm) => {
    const confirmMsg = `${firm.ad} firması ile olan sözleşmeyi iptal etmek ve tüm verilerini silmek istediğinize emin misiniz? Bu işlem geri alınamaz.`;
    if (!window.confirm(confirmMsg)) return;

    try {
      if (firm.tip === "Servis") {
        await api.deleteServiceFirm(firm.id);
      } else {
        await api.deleteSupplier(firm.id);
      }
      setFirms(firms.filter(f => f.id !== firm.id));
      alert("Sözleşme iptal edildi ve firma listeden kaldırıldı. Geçmiş veriler sistemde saklanmaya devam edecektir.");
    } catch (err) {
      console.error("Firma silme hatası:", err);
      alert("Hata: " + err.message);
    }
  };

  const renderFirmalar = () => {
    const filteredFirms = firms.filter(f =>
      f.tip === "Servis" &&
      f.aktiflik !== false &&
      ((f.ad || f.firma_adi || "").toLowerCase().includes(searchTerm.toLowerCase()) ||
        (f.email || "").toLowerCase().includes(searchTerm.toLowerCase()))
    );

    return (
      <div style={{ overflowX: "auto" }}>
        <table style={tableStyle}>
          <thead>
            <tr>
              <th style={thStyle}>Firma Adı & Türü</th>
              <th style={thStyle}>İletişim</th>
              <th style={thStyle}>Adres</th>
              <th style={thStyle}>Uzmanlık</th>
              <th style={thStyle}>Sorumlu</th>
              <th style={thStyle}>Ortalama Puan</th>
              <th style={thStyle}>Durum</th>
              <th style={thStyle}>İşlemler</th>
            </tr>
          </thead>
          <tbody>
            {filteredFirms.length > 0 ? (
              filteredFirms.map((f) => (
                <React.Fragment key={f.id}>
                  <tr style={trStyle}>
                    <td style={{ ...tdStyle, fontWeight: "bold", color: "#0f3460" }}>
                      {f.ad || f.firma_adi}
                      <div style={{ fontSize: "11px", color: "#95a5a6", fontWeight: "normal", marginTop: "4px" }}>{f.tip}</div>
                    </td>
                    <td style={tdStyle}>
                      <div style={{ fontSize: "13px" }}>📞 {f.telefon}</div>
                      <div style={{ fontSize: "12px", color: "#7f8c8d" }}>✉️ {f.email}</div>
                    </td>
                    <td style={tdStyle}>
                      <div style={{ fontSize: "13px", color: "#555" }}>{f.adres || "-"}</div>
                    </td>
                    <td style={tdStyle}>
                      <span style={{ fontSize: "12px", background: "#f1f2f6", padding: "4px 8px", borderRadius: "6px", color: "#57606f" }}>{f.uzmanlik_alani || "Belirtilmemiş"}</span>
                    </td>
                    <td style={tdStyle}>
                      <div style={{ fontSize: "14px", fontWeight: "bold" }}>{f.sorumlu_ad ? `${f.sorumlu_ad} ${f.sorumlu_soyad || ""}` : "-"}</div>
                    </td>
                    <td style={tdStyle}>
                      <div style={{ display: "flex", gap: "2px", alignItems: "center" }}>
                        {[1, 2, 3, 4, 5].map((star) => (
                          <span key={star} style={{ fontSize: "18px", color: star <= Math.round(f.ortalama_puan || 0) ? "#f39c12" : "#dfe6e9" }}>
                            ★
                          </span>
                        ))}
                        {f.ortalama_puan > 0 && <strong style={{ marginLeft: "6px", color: "#0f3460", fontSize: "13px" }}>{f.ortalama_puan}</strong>}
                      </div>
                      {f.yorum && <div style={{ fontSize: "12px", color: "#7f8c8d", marginTop: "4px", fontStyle: "italic" }}>💬 {f.yorum}</div>}
                    </td>
                    <td style={tdStyle}>
                      <span style={f.aktiflik !== false ? badgeActive : badgeInactive}>
                        {f.aktiflik !== false ? "Aktif" : "Pasif"}
                      </span>
                    </td>
                    <td style={tdStyle}>
                      <button
                        onClick={() => handleDeleteFirm(f)}
                        style={{
                          background: "rgba(231, 76, 60, 0.1)",
                          color: "#e74c3c",
                          border: "1px solid rgba(231, 76, 60, 0.3)",
                          padding: "8px 12px",
                          borderRadius: "8px",
                          fontSize: "12px",
                          fontWeight: "bold",
                          cursor: "pointer",
                          transition: "0.2s"
                        }}
                        onMouseOver={(e) => { e.target.style.background = "#e74c3c"; e.target.style.color = "white"; }}
                        onMouseOut={(e) => { e.target.style.background = "rgba(231, 76, 60, 0.1)"; e.target.style.color = "#e74c3c"; }}
                      >
                        Sözleşmeyi İptal Et
                      </button>
                    </td>
                  </tr>
                </React.Fragment>
              ))
            ) : (
              <tr>
                <td colSpan="8" style={{ padding: "40px", textAlign: "center", color: "#95a5a6" }}>
                  Servis firması bulunamadı.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    );
  };

  // RENDER: DIŞ SERVİS PUANLAMALARI
  const renderDisServis = () => (
    <div style={{ overflowX: "auto" }}>

      <table style={tableStyle}>
        <thead>
          <tr>
            <th style={thStyle}>Tarih</th>
            <th style={thStyle}>Servis Firması</th>
            <th style={thStyle}>Makine</th>
            <th style={thStyle}>Yapılan İşlem</th>
            <th style={thStyle}>Maliyet</th>
            <th style={thStyle}>İşlem Puanı</th>
            <th style={thStyle}>Aksiyon</th>
          </tr>
        </thead>
        <tbody>
          {disServisler.length > 0 ? (
            disServisler.map((s) => (
              <React.Fragment key={s.bakim_id}>
                <tr style={trStyle}>
                  <td style={tdStyle}>
                    {s.bakim_tarihi ? new Date(s.bakim_tarihi).toLocaleDateString("tr-TR") : "-"}
                  </td>
                  <td style={tdStyle}>
                    <div style={{ fontWeight: "bold", color: "#0f3460" }}>
                      {s.servis_firmasi || s.servis_firma?.firma_adi || "Bilinmeyen Firma"}
                    </div>
                  </td>
                  <td style={tdStyle}>{s.makine_ad || "Bilinmeyen Makine"}</td>
                  <td style={tdStyle}>
                    <div style={{ fontSize: "13px", fontWeight: "bold" }}>{s.bakim_turu || "Bakım"}</div>
                    <div style={{ fontSize: "12px", color: "#7f8c8d", marginTop: "4px" }}>{s.aciklama}</div>
                  </td>
                  <td style={{ ...tdStyle, fontWeight: "bold", color: "#27ae60" }}>
                    {Number(s.bakim_maliyet || 0).toLocaleString("tr-TR")} ₺
                  </td>
                  <td style={tdStyle}>
                    <div style={{ display: "flex", gap: "2px", fontSize: "18px" }}>
                      {[1, 2, 3, 4, 5].map((star) => (
                        <span key={star} style={{ color: star <= (s.servis_puan?.puan || 0) ? "#f39c12" : "#dfe6e9" }}>
                          ★
                        </span>
                      ))}
                      {(s.servis_puan?.puan || 0) > 0 && <span style={{ fontSize: "14px", marginLeft: "8px", fontWeight: "bold", color: "#0f3460" }}>{s.servis_puan?.puan}/5</span>}
                    </div>
                  </td>
                  <td style={tdStyle}>
                    <div style={{ display: "flex", gap: "8px" }}>
                      <button
                        onClick={() => {
                          setDisRatingId(disRatingId === s.bakim_id ? null : s.bakim_id);
                          setDisRatingValue(s.servis_puan?.puan || 0);
                        }}
                        style={{
                          padding: "8px 15px",
                          color: "white",
                          border: "none",
                          borderRadius: "8px",
                          fontWeight: "bold",
                          cursor: "pointer",
                          fontSize: "12px",
                          flex: 1,
                          background: disRatingId === s.bakim_id ? "#7f8c8d" : "#e94560"
                        }}
                      >
                        {disRatingId === s.bakim_id ? "Kapat" : ((s.servis_puan?.puan || 0) > 0 ? "Puanı Güncelle" : "⭐ Puanla")}
                      </button>
                      <button
                        onClick={() => handleApproveMaintenance(s.bakim_id)}
                        style={{
                          padding: "8px 15px",
                          color: (s.servis_puan?.puan || 0) > 0 ? "#27ae60" : "#95a5a6",
                          border: `1px solid ${(s.servis_puan?.puan || 0) > 0 ? "#27ae60" : "#ddd"}`,
                          borderRadius: "8px",
                          fontWeight: "bold",
                          cursor: (s.servis_puan?.puan || 0) > 0 ? "pointer" : "not-allowed",
                          fontSize: "12px",
                          background: "white",
                          transition: "0.2s"
                        }}
                        title={(s.servis_puan?.puan || 0) > 0 ? "Listeden Kaldır" : "Önce Puanlamanız Gerekir"}
                      >
                        Kaldır
                      </button>
                    </div>
                  </td>
                </tr>
                {disRatingId === s.bakim_id && (
                  <tr>
                    <td colSpan="7" style={{ padding: "0 16px 20px 16px", background: "#f8f9fa" }}>
                      <div style={{ padding: "20px", background: "white", borderRadius: "12px", border: "1px solid #e1e5eb", marginTop: "10px", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                        <div>
                          <div style={{ marginBottom: "8px", fontWeight: "bold", color: "#0f3460" }}>İşlem Puanı Verin:</div>
                          <div style={{ display: "flex", gap: "6px" }}>
                            {[1, 2, 3, 4, 5].map(star => (
                              <span
                                key={star}
                                onClick={() => setDisRatingValue(star)}
                                style={{ cursor: "pointer", fontSize: "24px", color: disRatingValue >= star ? "#f39c12" : "#dfe6e9", transition: "0.2s" }}
                              >
                                ★
                              </span>
                            ))}
                          </div>
                        </div>
                        <button
                          onClick={() => handleDisRateSave(s.bakim_id)}
                          disabled={disRatingValue === 0}
                          style={{ padding: "10px 25px", background: "#27ae60", color: "white", border: "none", borderRadius: "8px", fontWeight: "bold", cursor: "pointer", opacity: disRatingValue === 0 ? 0.5 : 1 }}
                        >
                          Puanı Kaydet
                        </button>
                      </div>
                    </td>
                  </tr>
                )}
              </React.Fragment>
            ))
          ) : (
            <tr><td colSpan="7" style={{ textAlign: "center", padding: "40px", color: "#95a5a6" }}>Servis kaydı bulunamadı.</td></tr>
          )}
        </tbody>
      </table>
    </div>
  );

  return (
    <div style={{ display: "flex", background: "#f5f6fa", minHeight: "100vh" }}>
      <Sidebar />
      <div style={{ flex: 1, display: "flex", flexDirection: "column", height: "100vh", overflow: "hidden" }}>
        <Navbar />
        <div style={{ padding: "30px", flex: 1, overflowY: "auto" }}>

          <div style={{ marginBottom: "25px", display: "flex", justifyContent: "space-between", alignItems: "flex-end" }}>
            <div>
              <h2 style={{ margin: 0, color: "#0f3460", fontSize: "28px", fontWeight: "bold" }}>Teknik Servis Paneli</h2>
              <p style={{ margin: "5px 0 0 0", color: "#7f8c8d" }}>
                Aşağıdaki seçenekleri kullanarak servis süreçlerini ve firma detaylarını yönetin.
              </p>
            </div>
            <div style={{ display: "flex", gap: "10px", alignItems: "center" }}>
              {isAdmin && (
                <button onClick={() => { setModalType("Servis"); setIsModalOpen(true); }} style={ekleButonStil}>
                  + Yeni Firma Ekle
                </button>
              )}
              {activeTab === "firmalar" && (
                <div style={{ position: "relative", width: "250px" }}>
                  <input
                    type="text"
                    placeholder="İsim veya e-posta..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    style={{
                      width: "100%",
                      padding: "12px 15px 12px 40px",
                      borderRadius: "10px",
                      border: "1px solid #e1e5eb",
                      fontSize: "14px",
                      outline: "none",
                      background: "white",
                      boxShadow: "0 2px 5px rgba(0,0,0,0.05)",
                      boxSizing: "border-box"
                    }}
                  />
                  <span style={{ position: "absolute", left: "14px", top: "50%", transform: "translateY(-50%)", color: "#95a5a6" }}>🔍</span>
                </div>
              )}
            </div>
          </div>

          {/* YATAY SEÇENEKLER MENÜSÜ */}
          <div style={tabContainerStyle}>
            <button
              onClick={() => setActiveTab("gorevler")}
              style={activeTab === "gorevler" ? activeTabStyle : inactiveTabStyle}
              onMouseOver={(e) => { if (activeTab !== "gorevler") e.target.style.background = "rgba(255,255,255,0.15)"; }}
              onMouseOut={(e) => { if (activeTab !== "gorevler") e.target.style.background = "rgba(255,255,255,0.05)"; }}
            >
              İş Listesi
            </button>
            <button
              onClick={() => setActiveTab("firmalar")}
              style={activeTab === "firmalar" ? activeTabStyle : inactiveTabStyle}
              onMouseOver={(e) => { if (activeTab !== "firmalar") e.target.style.background = "rgba(255,255,255,0.15)"; }}
              onMouseOut={(e) => { if (activeTab !== "firmalar") e.target.style.background = "rgba(255,255,255,0.05)"; }}
            >
              Servis Firmaları
            </button>

            <button
              onClick={() => setActiveTab("disServis")}
              style={activeTab === "disServis" ? activeTabStyle : inactiveTabStyle}
              onMouseOver={(e) => { if (activeTab !== "disServis") e.target.style.background = "rgba(255,255,255,0.15)"; }}
              onMouseOut={(e) => { if (activeTab !== "disServis") e.target.style.background = "rgba(255,255,255,0.05)"; }}
            >
              Dış Servis Puanlamaları
            </button>
          </div>

          {loading ? (
            <div style={{ textAlign: "center", marginTop: "50px", color: "#95a5a6", fontSize: "18px" }}>Yükleniyor...</div>
          ) : (
            <div style={contentCardStyle} className="glass-card-animation" key={activeTab}>
              {activeTab === "gorevler" && renderGorevListesi()}
              {activeTab === "firmalar" && renderFirmalar()}
              {activeTab === "disServis" && renderDisServis()}
            </div>
          )}

        </div>
      </div>
      <FirmModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        onSave={handleSaveFirm}
        initialType={modalType}
      />
    </div>
  );
}

// STILLER
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

const ekleButonStil = {
  padding: "12px 25px",
  background: "#27ae60",
  color: "white",
  border: "none",
  borderRadius: "10px",
  fontWeight: "bold",
  cursor: "pointer",
  boxShadow: "0 4px 15px rgba(39, 174, 96, 0.3)"
};

const baslikStil = {
  color: "#0f3460",
  marginTop: 0,
  fontSize: "20px",
  fontWeight: "bold",
  borderBottom: "2px solid #f1f2f6",
  paddingBottom: "15px",
  marginBottom: "20px"
};

const listeOgeStil = {
  background: "#fdfdfd",
  padding: "20px",
  borderRadius: "12px",
  border: "1px solid #e1e5eb"
};

const uzmanlikBadgeStil = { display: "inline-block", padding: "2px 8px", background: "rgba(243, 156, 18, 0.12)", color: "#e67e22", borderRadius: "4px", fontSize: "11px", fontWeight: "bold", marginTop: "5px" };
const badgeActive = { padding: "6px 14px", background: "rgba(46, 204, 113, 0.15)", color: "#2ecc71", borderRadius: "20px", fontSize: "12px", fontWeight: "bold", boxShadow: "0 0 10px rgba(46, 204, 113, 0.2)", border: "1px solid rgba(46, 204, 113, 0.3)" };
const badgeInactive = { padding: "6px 14px", background: "rgba(231, 76, 60, 0.15)", color: "#e74c3c", borderRadius: "20px", fontSize: "12px", fontWeight: "bold", border: "1px solid rgba(231, 76, 60, 0.3)" };

// --- ONAY MERKEZİ YENİ STİLLER ---
const graphPanelStyle = {
  display: "flex",
  gap: "30px",
  background: "rgba(15, 52, 96, 0.03)",
  padding: "30px",
  borderRadius: "20px",
  border: "1px solid rgba(15, 52, 96, 0.1)",
  alignItems: "center"
};

const chartCenterTextStyle = {
  position: "absolute",
  top: "0",
  left: "0",
  width: "100%",
  height: "100%",
  display: "flex",
  flexDirection: "column",
  justifyContent: "center",
  alignItems: "center"
};

const legendItemStyle = {
  display: "flex",
  alignItems: "center",
  gap: "12px",
  padding: "8px 15px",
  background: "white",
  borderRadius: "8px",
  boxShadow: "0 2px 5px rgba(0,0,0,0.05)"
};

const approvalSummaryCard = {
  width: "250px",
  padding: "20px",
  background: "white",
  borderRadius: "16px",
  boxShadow: "0 4px 15px rgba(0,0,0,0.05)",
  border: "1px solid #f1f2f6"
};

const onayBolumBaslikStyle = {
  fontSize: "16px",
  fontWeight: "800",
  color: "#0f3460",
  display: "flex",
  alignItems: "center",
  gap: "10px",
  marginBottom: "15px"
};

const onayKartStil = {
  background: "white",
  padding: "15px 20px",
  borderRadius: "12px",
  border: "1px solid #e1e5eb",
  display: "flex",
  justifyContent: "space-between",
  alignItems: "center",
  gap: "15px",
  transition: "transform 0.2s"
};

const onayButonStil = {
  padding: "8px 15px",
  background: "#e94560",
  color: "white",
  border: "none",
  borderRadius: "8px",
  fontSize: "12px",
  fontWeight: "bold",
  cursor: "pointer",
  whiteSpace: "nowrap"
};

const emptyListStil = {
  textAlign: "center",
  padding: "30px",
  color: "#95a5a6",
  fontSize: "14px",
  fontStyle: "italic",
  background: "#f8f9fa",
  borderRadius: "12px",
  border: "1px dashed #ddd"
};

if (typeof document !== "undefined") {
  const style = document.createElement("style");
  style.innerHTML = `
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
    .onay-kart:hover {
      transform: translateY(-3px);
      box-shadow: 0 5px 15px rgba(0,0,0,0.08);
      border-color: #e94560;
    }
  `;
  document.head.appendChild(style);
}

