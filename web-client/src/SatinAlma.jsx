import React, { useState, useEffect } from "react";
import Sidebar from "./Sidebar";
import Navbar from "./Navbar";
import { api } from "./services/api";

export default function SatinAlma() {
  // ── TAB STATE ──
  const [activeTab, setActiveTab] = useState("form");

  // ── FORM STATE ──
  const [tedarikciler, setTedarikciler] = useState([]);
  const [formData, setFormData] = useState({
    tedarikci_id: "",
    parca_adi: "",
    adet: "",
    birim_fiyat: "",
    tedarik_suresi: "",
    tarih: new Date().toISOString().split("T")[0],
    puan: 0,
    makine_tur_id: "",
    tahmini_omur: "",
  });
  const [machineTypes, setMachineTypes] = useState([]);
  const [hoverPuan, setHoverPuan] = useState(0);
  const [formLoading, setFormLoading] = useState(false);
  const [formSuccess, setFormSuccess] = useState("");

  // ── STOK STATE ──
  const [stoklar, setStoklar] = useState([]);
  const [stokLoading, setStokLoading] = useState(true);

  // ── GEÇMİŞ ALIMLAR STATE ──
  const [satinAlmalar, setSatinAlmalar] = useState([]);
  const [satinAlmaLoading, setSatinAlmaLoading] = useState(true);

  // ── VERİ ÇEKME ──
  useEffect(() => {
    const fetchData = async () => {
      try {
        const [allFirms, types] = await Promise.all([
          api.getFirms(),
          api.getSystemMachineTypes()
        ]);
        const suppliersOnly = allFirms.filter(f => f.tip === "Tedarikçi");
        setTedarikciler(suppliersOnly);
        setMachineTypes(types);
      } catch (error) {
        console.error("Veriler çekilirken hata:", error);
      }
    };
    fetchData();
  }, []);

  useEffect(() => {
    if (activeTab === "stok") {
      setStokLoading(true);
      api.getInventory()
        .then(data => setStoklar(data))
        .catch(err => console.error("Stok verileri çekilirken hata:", err))
        .finally(() => setStokLoading(false));
    }
    if (activeTab === "gecmis") {
      setSatinAlmaLoading(true);
      api.getPurchases()
        .then(data => setSatinAlmalar(data))
        .catch(err => console.error("Satın alma geçmişi çekilirken hata:", err))
        .finally(() => setSatinAlmaLoading(false));
    }
  }, [activeTab]);

  // ── FORM SUBMIT ──
  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!formData.tedarikci_id || !formData.parca_adi || !formData.adet || !formData.birim_fiyat || !formData.puan) {
      alert("Lütfen tüm zorunlu alanları doldurunuz.");
      return;
    }
    setFormLoading(true);
    setFormSuccess("");
    try {
      await api.addPurchase(formData);
      setFormSuccess("Satın alma kaydı başarıyla oluşturuldu ve stok güncellendi!");
      setFormData({ tedarikci_id: "", parca_adi: "", adet: "", birim_fiyat: "", tarih: new Date().toISOString().split("T")[0], puan: 0, makine_tur_id: "", tahmini_omur: "" });
      setHoverPuan(0);
      // 3 saniye sonra başarı mesajını kaldır
      setTimeout(() => setFormSuccess(""), 4000);
    } catch (error) {
      alert("Hata: " + (error.message || "Satın alma kaydı eklenemedi."));
    } finally {
      setFormLoading(false);
    }
  };

  const handleInputChange = (field, value) => {
    setFormData(prev => ({ ...prev, [field]: value }));
  };

  // ── TOPLAM TUTAR ──
  const toplamTutar = (Number(formData.adet) || 0) * (Number(formData.birim_fiyat) || 0);

  // Stok seviyesi bar rengi
  const getStokRenk = (miktar) => {
    if (miktar > 50) return "linear-gradient(90deg, #27ae60, #2ecc71)";
    if (miktar > 15) return "linear-gradient(90deg, #f39c12, #f1c40f)";
    return "linear-gradient(90deg, #c0392b, #e74c3c)";
  };

  return (
    <div style={{ display: "flex", background: "#f5f6fa", minHeight: "100vh" }}>
      <Sidebar />
      <div style={{ flex: 1, display: "flex", flexDirection: "column", height: "100vh", overflow: "hidden" }}>
        <Navbar />
        <div style={{ padding: "30px", flex: 1, overflowY: "auto" }}>

          {/* BAŞLIK */}
          <div style={{ marginBottom: "25px" }}>
            <h2 style={{ margin: 0, color: "#0f3460", fontSize: "28px", letterSpacing: "1px" }}>
              Satın Alma & Stok Yönetimi
            </h2>
            <p style={{ margin: "5px 0 0 0", color: "#7f8c8d", fontSize: "14px" }}>
              Tedarikçilerden yapılan alımları kaydedin, puanlayın ve stok durumunu takip edin.
            </p>
          </div>

          {/* TABS */}
          <div style={tabContainerStyle}>
            {[
              { key: "form", label: "Satın Alma Formu" },
              { key: "stok", label: "Stok Durumu" },
              { key: "gecmis", label: "Alım Geçmişi" },
            ].map(tab => (
              <button
                key={tab.key}
                style={activeTab === tab.key ? activeTabStyle : inactiveTabStyle}
                onClick={() => setActiveTab(tab.key)}
              >
                {tab.label}
              </button>
            ))}
          </div>

          {/* ═══════ FORM TAB ═══════ */}
          {activeTab === "form" && (
            <div style={contentCardStyle}>
              <div style={{ maxWidth: "720px", margin: "0 auto" }}>
                {/* Başarı mesajı */}
                {formSuccess && (
                  <div style={successBannerStyle}>
                    {formSuccess}
                  </div>
                )}

                <div style={{ display: "flex", alignItems: "center", gap: "12px", marginBottom: "30px", paddingBottom: "20px", borderBottom: "2px solid #f1f2f6" }}>

                  <div>
                    <h3 style={{ margin: 0, color: "#0f3460", fontSize: "20px" }}>Yeni Satın Alma Kaydı</h3>
                    <p style={{ margin: "2px 0 0 0", color: "#95a5a6", fontSize: "13px" }}>Tedarikçi seçin, ürün bilgilerini girin ve performans puanı verin.</p>
                  </div>
                </div>

                <form onSubmit={handleSubmit}>
                  {/* TEDARİKÇİ SEÇİMİ */}
                  <div style={formGroupStyle}>
                    <label style={labelStyle}>Tedarikçi Seçimi <span style={{ color: "#e74c3c" }}>*</span></label>
                    <select
                      id="tedarikci-select"
                      value={formData.tedarikci_id}
                      onChange={(e) => handleInputChange("tedarikci_id", e.target.value)}
                      style={selectStyle}
                    >
                      <option value="">— Tedarikçi seçiniz —</option>
                      {tedarikciler.map(t => (
                        <option key={t.id} value={t.id}>{t.ad}</option>
                      ))}
                    </select>
                  </div>

                  {/* PARÇA ADI */}
                  <div style={formGroupStyle}>
                    <label style={labelStyle}>Parça Adı <span style={{ color: "#e74c3c" }}>*</span></label>
                    <input
                      id="parca-adi-input"
                      type="text"
                      placeholder="Örn: M6 Rulman, Hidrolik Filtre..."
                      value={formData.parca_adi}
                      onChange={(e) => handleInputChange("parca_adi", e.target.value)}
                      style={inputStyle}
                    />
                  </div>

                  {/* TAHMİNİ ÖMÜR (Yeni yeri - Daha Görünür) */}
                  <div style={formGroupStyle}>
                    <label style={labelStyle}>Tahmini Ömür (Saat)</label>
                    <input
                      id="omur-input"
                      type="number"
                      min="0"
                      placeholder="Parçanın beklenen çalışma ömrünü girin (Örn: 5000)"
                      value={formData.tahmini_omur}
                      onChange={(e) => handleInputChange("tahmini_omur", e.target.value)}
                      style={inputStyle}
                    />
                  </div>

                  {/* MAKİNE TÜRÜ */}
                  <div style={formGroupStyle}>
                    <label style={labelStyle}>İlgili Makine Türü</label>
                    <select
                      value={formData.makine_tur_id}
                      onChange={(e) => handleInputChange("makine_tur_id", e.target.value)}
                      style={selectStyle}
                    >
                      <option value="">— Opsiyonel: Makine türü seçin —</option>
                      {machineTypes.map(type => (
                        <option key={type.makine_tur_id} value={type.makine_tur_id}>
                          {type.makine_tur_adi}
                        </option>
                      ))}
                    </select>
                  </div>

                  {/* ADET ve BİRİM FİYAT yan yana */}
                  <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "20px" }}>
                    <div style={formGroupStyle}>
                      <label style={labelStyle}>Adet <span style={{ color: "#e74c3c" }}>*</span></label>
                      <input
                        id="adet-input"
                        type="number"
                        min="1"
                        placeholder="0"
                        value={formData.adet}
                        onChange={(e) => handleInputChange("adet", e.target.value)}
                        style={inputStyle}
                      />
                    </div>
                    <div style={formGroupStyle}>
                      <label style={labelStyle}>Birim Fiyat (₺) <span style={{ color: "#e74c3c" }}>*</span></label>
                      <input
                        id="birim-fiyat-input"
                        type="number"
                        min="0"
                        step="0.01"
                        placeholder="0.00"
                        value={formData.birim_fiyat}
                        onChange={(e) => handleInputChange("birim_fiyat", e.target.value)}
                        style={inputStyle}
                      />
                    </div>
                  </div>

                  {/* TOPLAM TUTAR */}
                  {toplamTutar > 0 && (
                    <div style={toplamBarStyle}>
                      <span style={{ color: "#7f8c8d", fontSize: "14px" }}>Toplam Tutar</span>
                      <span style={{ color: "#0f3460", fontSize: "22px", fontWeight: "bold" }}>
                        {toplamTutar.toLocaleString("tr-TR", { minimumFractionDigits: 2 })} ₺
                      </span>
                    </div>
                  )}

                  {/* TEDARİK SÜRESİ ve TARİH yan yana */}
                  <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "20px" }}>
                    <div style={formGroupStyle}>
                      <label style={labelStyle}>Tedarik Süresi (Gün)</label>
                      <input
                        id="tedarik-suresi-input"
                        type="number"
                        min="0"
                        placeholder="Örn: 3"
                        value={formData.tedarik_suresi}
                        onChange={(e) => handleInputChange("tedarik_suresi", e.target.value)}
                        style={inputStyle}
                      />
                    </div>
                    <div style={{ ...formGroupStyle, position: "relative" }}>
                      <label style={labelStyle}>Alım Tarihi</label>
                      <input
                        id="tarih-input"
                        type="date"
                        value={formData.tarih}
                        onChange={(e) => handleInputChange("tarih", e.target.value)}
                        style={{ ...inputStyle, paddingRight: "40px", color: formData.tarih ? "#333" : "#999" }}
                      />
                      <span
                        onClick={() => document.getElementById("tarih-input")?.showPicker?.()}
                        style={{ position: "absolute", right: "10px", top: "50%", transform: "translateY(-50%)", fontSize: "20px", cursor: "pointer", userSelect: "none", filter: "drop-shadow(0 1px 2px rgba(0,0,0,0.2))" }}
                      >📅</span>
                    </div>
                  </div>


                  {/* PUAN (1–10 Yıldız) */}
                  <div style={formGroupStyle}>
                    <label style={labelStyle}>Tedarikçi Performans Puanı (1-10) <span style={{ color: "#e74c3c" }}>*</span></label>
                    <div style={{ display: "flex", gap: "6px", alignItems: "center", marginTop: "8px" }}>
                      {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map(star => (
                        <span
                          key={star}
                          onClick={() => handleInputChange("puan", star)}
                          onMouseEnter={() => setHoverPuan(star)}
                          onMouseLeave={() => setHoverPuan(0)}
                          style={{
                            cursor: "pointer",
                            fontSize: "28px",
                            color: star <= (hoverPuan || formData.puan) ? "#f39c12" : "#dfe6e9",
                            transition: "all 0.15s ease",
                            transform: star <= (hoverPuan || formData.puan) ? "scale(1.15)" : "scale(1)",
                            textShadow: star <= (hoverPuan || formData.puan) ? "0 0 8px rgba(243,156,18,0.4)" : "none",
                          }}
                        >
                          ★
                        </span>
                      ))}
                      {formData.puan > 0 && (
                        <span style={{
                          marginLeft: "12px",
                          fontWeight: "bold",
                          fontSize: "20px",
                          color: formData.puan >= 8 ? "#27ae60" : formData.puan >= 5 ? "#f39c12" : "#e74c3c",
                          background: formData.puan >= 8 ? "rgba(46,204,113,0.1)" : formData.puan >= 5 ? "rgba(243,156,18,0.1)" : "rgba(231,76,60,0.1)",
                          padding: "4px 14px",
                          borderRadius: "20px",
                        }}>
                          {formData.puan}/10
                        </span>
                      )}
                    </div>
                    <div style={{ marginTop: "6px", fontSize: "12px", color: "#95a5a6" }}>
                      {formData.puan === 0 && "Puan vermek için yıldızlara tıklayın"}
                      {formData.puan >= 1 && formData.puan <= 3 && "⚠️ Düşük performans — Dikkatle değerlendirin"}
                      {formData.puan >= 4 && formData.puan <= 6 && "📊 Ortalama performans"}
                      {formData.puan >= 7 && formData.puan <= 8 && "👍 İyi performans"}
                      {formData.puan >= 9 && "🌟 Mükemmel performans!"}
                    </div>
                  </div>

                  {/* GÖNDER BUTONU */}
                  <button
                    id="submit-purchase-btn"
                    type="submit"
                    disabled={formLoading}
                    style={{
                      ...submitButtonStyle,
                      opacity: formLoading ? 0.6 : 1,
                      cursor: formLoading ? "not-allowed" : "pointer"
                    }}
                  >
                    {formLoading ? "Kaydediliyor..." : "Satın Alma Kaydını Oluştur"}
                  </button>
                </form>
              </div>
            </div>
          )}

          {/* ═══════ STOK TAB ═══════ */}
          {activeTab === "stok" && (
            <div style={contentCardStyle}>
              <div style={{ display: "flex", alignItems: "center", gap: "12px", marginBottom: "25px" }}>

                <div>
                  <h3 style={{ margin: 0, color: "#0f3460", fontSize: "18px" }}>Güncel Stok Durumu</h3>
                  <p style={{ margin: "2px 0 0 0", color: "#95a5a6", fontSize: "13px" }}>Tüm parçaların anlık stok miktarları</p>
                </div>
              </div>

              {stokLoading ? (
                <div style={{ textAlign: "center", padding: "60px 0", color: "#95a5a6", fontSize: "16px" }}>
                  Stok verileri yükleniyor...
                </div>
              ) : stoklar.length === 0 ? (
                <div style={{ textAlign: "center", padding: "60px 0" }}>

                  <div style={{ color: "#95a5a6", fontSize: "16px" }}>Henüz stok kaydı bulunmamaktadır.</div>
                  <div style={{ color: "#bdc3c7", fontSize: "13px", marginTop: "5px" }}>Satın alma kaydı ekledikçe stok otomatik oluşur.</div>
                </div>
              ) : (
                <table style={tableStyle}>
                  <thead>
                    <tr>
                      <th style={thStyle}>#</th>
                      <th style={thStyle}>Parça Adı</th>
                      <th style={thStyle}>Güncel Miktar</th>
                      <th style={thStyle}>Tahmini Ömür</th>
                      <th style={thStyle}>Stok Seviyesi</th>
                      <th style={thStyle}>Son Güncelleme</th>
                      <th style={thStyle}>Durum</th>
                    </tr>
                  </thead>
                  <tbody>
                    {stoklar.map((s, i) => {
                      const isKritik = s.miktar <= 5;
                      const isDusuk = s.miktar <= 15;
                      return (
                        <tr key={s.stok_id} style={trStyle}>
                          <td style={{ ...tdStyle, color: "#bdc3c7", fontWeight: "bold" }}>{i + 1}</td>
                          <td style={{ ...tdStyle, fontWeight: "bold", color: "#0f3460", fontSize: "15px" }}>
                            {s.parca_adi}
                          </td>
                          <td style={tdStyle}>
                            <span style={{
                              fontWeight: "bold",
                              fontSize: "18px",
                              color: isKritik ? "#e74c3c" : isDusuk ? "#f39c12" : "#27ae60"
                            }}>
                              {s.miktar}
                            </span>
                            <span style={{ color: "#bdc3c7", fontSize: "12px", marginLeft: "4px" }}>adet</span>
                          </td>
                          <td style={tdStyle}>
                            {s.tahmini_omur_saati ? (
                              <span style={{ 
                                background: "rgba(52,152,219,0.1)", 
                                color: "#3498db", 
                                padding: "4px 10px", 
                                borderRadius: "12px", 
                                fontSize: "12px",
                                fontWeight: "bold"
                              }}>
                                ⏳ {s.tahmini_omur_saati} Saat
                              </span>
                            ) : "-"}
                          </td>
                          <td style={tdStyle}>
                            <div style={stokKapsayiciStyle}>
                              <div style={{
                                height: "100%",
                                borderRadius: "10px",
                                width: `${Math.min((s.miktar / 100) * 100, 100)}%`,
                                background: getStokRenk(s.miktar),
                                transition: "width 1.5s cubic-bezier(0.4, 0, 0.2, 1)",
                                boxShadow: "0 0 10px rgba(255,255,255,0.3)"
                              }}></div>
                            </div>
                          </td>
                          <td style={{ ...tdStyle, fontSize: "13px", color: "#7f8c8d" }}>
                            {s.son_guncelleme ? new Date(s.son_guncelleme).toLocaleDateString("tr-TR", { day: "2-digit", month: "long", year: "numeric", hour: "2-digit", minute: "2-digit" }) : "-"}
                          </td>
                          <td style={tdStyle}>
                            <span style={{
                              padding: "5px 12px",
                              borderRadius: "20px",
                              fontSize: "12px",
                              fontWeight: "bold",
                              background: isKritik ? "rgba(231,76,60,0.12)" : isDusuk ? "rgba(243,156,18,0.12)" : "rgba(46,204,113,0.12)",
                              color: isKritik ? "#e74c3c" : isDusuk ? "#f39c12" : "#27ae60",
                              border: `1px solid ${isKritik ? "rgba(231,76,60,0.3)" : isDusuk ? "rgba(243,156,18,0.3)" : "rgba(46,204,113,0.3)"}`
                            }}>
                              {isKritik ? "Kritik" : isDusuk ? "Düşük" : "Yeterli"}
                            </span>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              )}
            </div>
          )}

          {/* ═══════ GEÇMİŞ TAB ═══════ */}
          {activeTab === "gecmis" && (
            <div style={contentCardStyle}>
              <div style={{ display: "flex", alignItems: "center", gap: "12px", marginBottom: "25px" }}>
                <div style={{ width: "44px", height: "44px", borderRadius: "12px", background: "linear-gradient(135deg, #8e44ad, #9b59b6)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: "20px", color: "white", boxShadow: "0 4px 15px rgba(142,68,173,0.3)" }}>
                  📋
                </div>
                <div>
                  <h3 style={{ margin: 0, color: "#0f3460", fontSize: "18px" }}>Satın Alma Geçmişi</h3>
                  <p style={{ margin: "2px 0 0 0", color: "#95a5a6", fontSize: "13px" }}>Tüm satın alma kayıtları ve tedarikçi puanlamaları</p>
                </div>
              </div>

              {satinAlmaLoading ? (
                <div style={{ textAlign: "center", padding: "60px 0", color: "#95a5a6", fontSize: "16px" }}>
                  ⏳ Veriler yükleniyor...
                </div>
              ) : satinAlmalar.length === 0 ? (
                <div style={{ textAlign: "center", padding: "60px 0" }}>
                  <div style={{ fontSize: "48px", marginBottom: "15px" }}>📭</div>
                  <div style={{ color: "#95a5a6", fontSize: "16px" }}>Henüz satın alma kaydı bulunmamaktadır.</div>
                </div>
              ) : (
                <table style={tableStyle}>
                  <thead>
                    <tr>
                      <th style={thStyle}>Tarih</th>
                      <th style={thStyle}>Tedarikçi</th>
                      <th style={thStyle}>Makine Türü</th>
                      <th style={thStyle}>Parça</th>
                      <th style={thStyle}>Adet</th>
                      <th style={thStyle}>Birim Fiyat</th>
                      <th style={thStyle}>Toplam</th>
                      <th style={thStyle}>Tahmini Ömür</th>
                      <th style={thStyle}>Puan</th>
                    </tr>
                  </thead>
                  <tbody>
                    {satinAlmalar.map((sa) => (
                      <tr key={sa.satin_alma_id} style={trStyle}>
                        <td style={{ ...tdStyle, fontSize: "13px", color: "#7f8c8d" }}>
                          {sa.tarih?.split('T')[0] || "-"}
                        </td>
                        <td style={{ ...tdStyle, fontWeight: "bold", color: "#0f3460" }}>
                          {sa.tedarikci?.firma_adi || "-"}
                        </td>
                        <td style={tdStyle}>
                          <span style={{
                            padding: "4px 10px",
                            background: sa.makine_turu ? "#f1f2f6" : "transparent",
                            borderRadius: "6px",
                            fontSize: "12px",
                            color: "#0f3460"
                          }}>
                            {sa.makine_turu?.makine_tur_adi || "-"}
                          </span>
                        </td>
                        <td style={tdStyle}>{sa.parca_adi}</td>
                        <td style={{ ...tdStyle, fontWeight: "bold" }}>{sa.adet}</td>
                        <td style={tdStyle}>{Number(sa.birim_fiyat).toLocaleString("tr-TR", { minimumFractionDigits: 2 })} ₺</td>
                        <td style={{ ...tdStyle, fontWeight: "bold", color: "#27ae60" }}>
                          {(sa.adet * Number(sa.birim_fiyat)).toLocaleString("tr-TR", { minimumFractionDigits: 2 })} ₺
                        </td>
                        <td style={tdStyle}>
                          {sa.tahmini_omur_saati ? (
                            <span style={{ 
                              background: "rgba(52,152,219,0.1)", 
                              color: "#3498db", 
                              padding: "4px 10px", 
                              borderRadius: "12px", 
                              fontSize: "12px",
                              fontWeight: "bold"
                            }}>
                              ⏳ {sa.tahmini_omur_saati} Saat
                            </span>
                          ) : "-"}
                        </td>
                        <td style={tdStyle}>
                          <div style={{ display: "flex", alignItems: "center", gap: "4px" }}>
                            {[...Array(10)].map((_, idx) => (
                              <span key={idx} style={{ fontSize: "14px", color: idx < sa.puan ? "#f39c12" : "#ecf0f1" }}>★</span>
                            ))}
                            <span style={{
                              marginLeft: "8px",
                              fontWeight: "bold",
                              fontSize: "13px",
                              color: sa.puan >= 8 ? "#27ae60" : sa.puan >= 5 ? "#f39c12" : "#e74c3c"
                            }}>
                              {sa.puan}/10
                            </span>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          )}

        </div>
      </div>
    </div>
  );
}

// ═══════ STYLES ═══════

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
  padding: "35px",
  borderRadius: "20px",
  boxShadow: "0 10px 40px 0 rgba(0, 0, 0, 0.05)",
  border: "1px solid #eee",
  animation: "fadeIn 0.4s ease-out",
  overflowX: "auto"
};

const formGroupStyle = {
  marginBottom: "22px"
};

const labelStyle = {
  display: "block",
  marginBottom: "8px",
  fontWeight: "600",
  fontSize: "14px",
  color: "#34495e",
  letterSpacing: "0.3px"
};

const inputStyle = {
  width: "100%",
  padding: "14px 16px",
  border: "1.5px solid #e1e5eb",
  borderRadius: "10px",
  fontSize: "15px",
  outline: "none",
  background: "#fafbfc",
  color: "#333",
  transition: "all 0.3s ease",
  boxSizing: "border-box"
};

const selectStyle = {
  ...inputStyle,
  appearance: "none",
  backgroundImage: "url('data:image/svg+xml;charset=US-ASCII,<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"14\" height=\"14\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"%2395a5a6\" stroke-width=\"2\"><path d=\"M6 9l6 6 6-6\"/></svg>')",
  backgroundRepeat: "no-repeat",
  backgroundPosition: "right 16px center",
  paddingRight: "40px"
};

const toplamBarStyle = {
  display: "flex",
  justifyContent: "space-between",
  alignItems: "center",
  padding: "14px 20px",
  background: "linear-gradient(135deg, rgba(15,52,96,0.04), rgba(233,69,96,0.04))",
  borderRadius: "12px",
  marginBottom: "22px",
  border: "1px dashed rgba(15,52,96,0.15)"
};

const submitButtonStyle = {
  width: "100%",
  padding: "16px",
  background: "linear-gradient(135deg, #27ae60, #2ecc71)",
  color: "white",
  border: "none",
  borderRadius: "12px",
  fontSize: "16px",
  fontWeight: "bold",
  letterSpacing: "0.5px",
  boxShadow: "0 6px 20px rgba(46, 204, 113, 0.35)",
  transition: "all 0.3s ease",
  marginTop: "10px"
};

const successBannerStyle = {
  background: "linear-gradient(135deg, rgba(46,204,113,0.1), rgba(39,174,96,0.1))",
  color: "#27ae60",
  padding: "16px 20px",
  borderRadius: "12px",
  marginBottom: "25px",
  fontSize: "15px",
  fontWeight: "600",
  border: "1px solid rgba(46,204,113,0.3)",
  textAlign: "center",
  animation: "fadeIn 0.3s ease-out"
};

const tableStyle = { width: "100%", borderCollapse: "collapse", minWidth: "800px" };

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

const stokKapsayiciStyle = {
  height: "8px",
  width: "120px",
  background: "#f1f2f6",
  borderRadius: "10px",
  overflow: "hidden",
  boxShadow: "inset 0 1px 3px rgba(0,0,0,0.1)"
};

// Animasyonlar
if (typeof document !== "undefined") {
  const existingStyle = document.getElementById("satin-alma-styles");
  if (!existingStyle) {
    const style = document.createElement("style");
    style.id = "satin-alma-styles";
    style.innerHTML = `
      @keyframes fadeIn {
        from { opacity: 0; transform: translateY(10px); }
        to { opacity: 1; transform: translateY(0); }
      }
    `;
    document.head.appendChild(style);
  }
}
