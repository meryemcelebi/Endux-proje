import React, { useState, useEffect } from "react";
import { useParams } from "react-router-dom";
import { api } from "./services/api";

/**
 * Makine Detay Sayfası
 * Belirli bir makinenin teknik özelliklerini, çalışma süresini, 
 * maliyet analizini ve tüm servis/parça değişim geçmişini gösterir.
 */
export default function MakineDetay() {
    const { id } = useParams(); // URL'den makine ID'sini al (Örn: /makine/5 -> id=5)

    // --- STATE TANIMLAMALARI ---
    const [machine, setMachine] = useState(null); // Makinenin temel teknik ve satın alma bilgileri
    const [history, setHistory] = useState([]); // Makineye ait geçmiş servis kayıtları ve değişen parçalar
    const [checklistHistory, setChecklistHistory] = useState([]); // Son 3 güne ait günlük kontrol formları
    const [isFocusView, setIsFocusView] = useState(false); // Detaylı "Teknik & Tedarikçi" görünüm modu anahtarı
    const [loading, setLoading] = useState(true); // Sayfa yükleniyor durum kontrolü

    useEffect(() => {
        const loadData = async () => {
            try {
                const [macData, histData, chData] = await Promise.all([
                    api.getMachineDetails(id),
                    api.getServiceHistory(id),
                    api.getChecklistHistory(id)
                ]);
                setMachine(macData);
                setHistory(histData);
                setChecklistHistory(chData);
            } catch (err) {
                console.error("Detaylar yüklenemedi", err);
            } finally {
                setLoading(false);
            }
        };
        loadData();
    }, [id]);

    if (loading) {
        return <div style={{ ...sayfaStil, padding: "100px 20px", color: "white", textAlign: "center", fontSize: "20px" }}>Veriler Yükleniyor... Dökümler Hazırlanıyor...</div>;
    }

    if (!machine) {
        return <div style={{ ...sayfaStil, padding: "100px 20px", color: "white", textAlign: "center" }}>Makine bulunamadı.</div>;
    }

    const totalBakimMaliyet = history.reduce((sum, item) => sum + (item.bakim_maliyet || 0), 0);

    // --- GARANTİ DURUMU HESAPLAMA MANTIĞI ---
    // Satın alma tarihi ve garanti süresine göre kalan günü ve kritik durumu belirler.
    const getWarrantyStatus = (purchaseDate, warrantyMonths) => {
        if (!purchaseDate || !warrantyMonths) return null;

        const purchase = new Date(purchaseDate);
        // Garanti bitiş tarihini hesapla (Satın alma + Ay süresi)
        const end = new Date(purchase.setMonth(purchase.getMonth() + warrantyMonths));
        const today = new Date();
        const diffTime = end - today;
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24)); // Milisaniyeyi güne çevir

        return {
            endDate: end,
            daysRemaining: diffDays,
            isCritical: diffDays > 0 && diffDays <= 30, // Son 30 gün kaldıysa kritik
            isExpired: diffDays <= 0 // Garanti bittiyse
        };
    };

    const warranty = getWarrantyStatus(machine.satin_alma_tarihi, machine.garanti_suresi);

    return (
        <div style={sayfaStil}>
            <div style={containerStil}>
                {/* BAŞLIK */}
                <div style={headerStil}>
                    <div style={{ display: "flex", alignItems: "center", gap: "20px" }}>
                        <div>
                            <h2 style={{ margin: 0, color: "white", fontSize: "24px", display: "flex", alignItems: "center", gap: "10px" }}>
                                {machine.makine_ad}
                                <span style={{
                                    padding: "4px 10px",
                                    borderRadius: "12px",
                                    fontSize: "12px",
                                    background: machine.aktiflik_durumu === "Aktif" ? "#2ecc71" :
                                        machine.aktiflik_durumu === "Bakımda" ? "#f39c12" : "#e74c3c",
                                    color: "white",
                                    fontWeight: "bold"
                                }}>
                                    {machine.aktiflik_durumu || "Bilinmiyor"}
                                </span>
                            </h2>
                            <div style={{ color: "#bdc3c7", fontSize: "14px", marginTop: "5px" }}>
                                Seri No: {Array.isArray(machine.seri_no) ? machine.seri_no.join(", ") : machine.seri_no || "-"} | Kimlik: #{id}
                            </div>
                        </div>
                    </div>

                    {/* BUTONLAR - Focus View Toggled */}
                    <div style={{ display: "flex", gap: "10px", alignItems: "center" }}>
                        <button
                            onClick={() => setIsFocusView(!isFocusView)}
                            style={{
                                ...btnStyle,
                                background: isFocusView ? "#2ecc71" : "#0f3460",
                                padding: "10px 20px",
                                display: "flex",
                                alignItems: "center",
                                gap: "8px",
                                border: "1px solid rgba(255,255,255,0.2)"
                            }}
                        >
                            {isFocusView ? "Rapor Paneline Dön" : "Teknik & Tedarikçi Bilgisi"}
                        </button>

                        <div style={{
                            background: "rgba(233, 69, 96, 0.2)",
                            border: "1px solid #e94560",
                            padding: "10px 20px",
                            borderRadius: "12px",
                            display: "flex",
                            alignItems: "center",
                            gap: "15px"
                        }}>
                            <span style={{ color: "#e94560", fontWeight: "bold", fontSize: "14px" }}>SERVİS GİRİŞ ŞİFRESİ:</span>
                            <span style={{ color: "white", fontSize: "20px", fontWeight: "900", letterSpacing: "4px", background: "#e94560", padding: "4px 12px", borderRadius: "6px" }}>
                                {machine.pin || "####"}
                            </span>
                        </div>
                    </div>
                </div>

                {!isFocusView && (
                    <>
                        {/* KPI KARTLARI */}
                        <div style={kartlarAlaniStil}>
                            <div style={bilgiKartStil}>
                                <div style={kartIkonStil}>⏱️</div>
                                <div>
                                    <div style={kartBaslikStil}>Toplam Çalışma Süresi</div>
                                    <div style={kartDegerStil}>{machine.top_calisma_saati || 0} Saat</div>
                                </div>
                            </div>
                            <div style={bilgiKartStil}>
                                <div style={kartIkonStil}>💰</div>
                                <div>
                                    <div style={kartBaslikStil}>Satın Alma Maliyeti</div>
                                    <div style={kartDegerStil}>{machine.satin_alma_maliyeti?.toLocaleString()} ₺</div>
                                </div>
                            </div>
                            <div style={bilgiKartStil}>
                                <div style={kartIkonStil}>🔧</div>
                                <div>
                                    <div style={kartBaslikStil}>Toplam Bakım Maliyeti</div>
                                    <div style={kartDegerStil}>{totalBakimMaliyet.toLocaleString()} ₺</div>
                                </div>
                            </div>
                            <div style={bilgiKartStil}>
                                <div style={kartIkonStil}>⚠️</div>
                                <div>
                                    <div style={kartBaslikStil}>Anlık Risk Skoru</div>
                                    <div style={kartDegerStil}>{machine.mevcut_risk_skoru} / 1.0</div>
                                </div>
                            </div>
                        </div>

                    </>
                )}

                {/* SOL KOLON - ANALİZ ÖZETİ VEYA TEKNİK BİLGİLER */}
                <div style={{ display: "flex", flexDirection: "column", gap: "20px", flex: isFocusView ? 1 : 1, minWidth: isFocusView ? "100%" : "320px" }}>

                    {/* ODAKLANMIŞ GÖRÜNÜM (isFocusView = true): Tedarikçi ve Teknik Kartlar yan yana gelir */}
                    {isFocusView && (
                        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(400px, 1fr))", gap: "25px", animation: "fadeIn 0.4s ease-out" }}>

                            {/* Tedarikçi Kartı: Satıcı firma iletişim bilgileri */}
                            <div style={{ ...detayKartStil, borderTop: "2px solid #eee", display: "flex", flexDirection: "column", gap: "20px" }}>
                                <div style={{ display: "flex", alignItems: "center", gap: "12px", borderBottom: "2px solid #f1f2f6", paddingBottom: "15px" }}>
                                    <h3 style={{ ...bolumBaslikStil, borderBottom: "none", marginBottom: 0, paddingBottom: 0 }}>Tedarikçi/Satıcı Bilgileri</h3>
                                </div>

                                {machine.tedarikci ? (
                                    <div style={{ ...tedarikciListeStil, gap: "18px" }}>
                                        <div style={{ ...tedarikciSatirStil, padding: "12px", borderRadius: "8px" }}>
                                            <span style={tedarikciEtiketStil}>Firma Adı:</span>
                                            <strong style={{ color: "#0f3460", fontSize: "17px" }}>{machine.tedarikci.firma_adi}</strong>
                                        </div>
                                        <div style={{ ...tedarikciSatirStil, padding: "8px 12px" }}>
                                            <span style={tedarikciEtiketStil}>İletişim Hattı:</span>
                                            <strong style={{ color: "#2c3e50" }}>{machine.tedarikci.telefon}</strong>
                                        </div>
                                        <div style={{ ...tedarikciSatirStil, padding: "8px 12px" }}>
                                            <span style={tedarikciEtiketStil}>E-Posta Adresi:</span>
                                            <u style={{ color: "#3498db" }}>{machine.tedarikci.email}</u>
                                        </div>
                                        <div style={{ ...tedarikciSatirStil, padding: "8px 12px", borderBottom: "none" }}>
                                            <span style={tedarikciEtiketStil}>Genel Merkez / Adres:</span>
                                            <span style={{ textAlign: "right", maxWidth: "250px", fontWeight: "500" }}>{machine.tedarikci.adres}</span>
                                        </div>
                                    </div>
                                ) : (
                                    <p style={{ color: "#777", fontStyle: "italic" }}>Tedarikçi veritabanında kayıtlı bilgi bulunmamaktadır.</p>
                                )}
                            </div>

                            {/* Teknik Bilgi Kartı: Sistem ID'leri ve donanım özellikleri */}
                            <div style={{ ...detayKartStil, borderTop: "2px solid #eee", display: "flex", flexDirection: "column", gap: "20px" }}>
                                <div style={{ display: "flex", alignItems: "center", gap: "12px", borderBottom: "2px solid #f1f2f6", paddingBottom: "15px" }}>
                                    <h3 style={{ ...bolumBaslikStil, borderBottom: "none", marginBottom: 0, paddingBottom: 0 }}>Teknik Bilgiler</h3>
                                </div>

                                <div style={{ ...tedarikciListeStil, gap: "18px" }}>
                                    <div style={{ ...tedarikciSatirStil, padding: "12px", borderRadius: "8px" }}>
                                        <span style={tedarikciEtiketStil}>Sistem Lokasyon No:</span>
                                        <strong style={{ color: "#e94560", fontSize: "17px" }}>{machine.lo_id || "Tanımlanmamış"}</strong>
                                    </div>
                                    <div style={{ ...tedarikciSatirStil, padding: "8px 12px" }}>
                                        <span style={tedarikciEtiketStil}>Makine Kategori ID:</span>
                                        <strong style={{ color: "#2c3e50" }}>{machine.m_tur_id || "N/A"}</strong>
                                    </div>
                                    <div style={{ ...tedarikciSatirStil, padding: "8px 12px", borderBottom: "none" }}>
                                        <span style={tedarikciEtiketStil}>Kapasite & Donanım Özellikleri:</span>
                                        <div style={{ display: "flex", flexWrap: "wrap", gap: "6px", justifyContent: "flex-end" }}>
                                            {machine.makine_ozellikleri?.map((oz, i) => (
                                                <span key={i} style={{ background: "#e1e5eb", padding: "4px 10px", borderRadius: "6px", fontSize: "12px", fontWeight: "600" }}>{oz}</span>
                                            )) || "-"}
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    )}

                    {/* NORMAL GÖRÜNÜM: Makine analiz özeti ve garanti durumunu gösterir */}
                    {!isFocusView && (
                        <div style={detayKartStil}>
                            <h3 style={bolumBaslikStil}>Makine Analiz Özeti</h3>
                            <p style={{ color: "#555", lineHeight: "1.6", margin: 0 }}>
                                Bu makine en son satın alma tarihinden ({new Date(machine.satin_alma_tarihi).toLocaleDateString("tr-TR")}) bu yana toplam <strong>{machine.top_calisma_saati || 0} saat</strong> aktif hizmet vermiştir. Servis kayıtlarında toplam <strong>{history.length}</strong> adet bakım veya arıza kaydı gözükmektedir. Risk skoru algoritmik olarak <strong>{machine.mevcut_risk_skoru}</strong> hesaplanmış olup, sistemde <strong style={{ color: machine.aktiflik_durumu === "Aktif" ? "#2ecc71" : machine.aktiflik_durumu === "Bakımda" ? "#f39c12" : "#e74c3c" }}>{machine.aktiflik_durumu === "Aktif" ? "aktif çalışmaya uygundur." : machine.aktiflik_durumu === "Bakımda" ? "bakım sürecindedir." : "arızalı olarak etiketlenmiştir."}</strong>

                                {/* Garanti Bilgisi Rozeti */}
                                {warranty && (
                                    <span style={{ display: "block", marginTop: "15px", padding: "10px", background: warranty.isCritical ? "#fff3cd" : warranty.isExpired ? "#f8d7da" : "#f1f2f6", borderRadius: "8px", borderLeft: `4px solid ${warranty.isCritical ? "#ffc107" : warranty.isExpired ? "#dc3545" : "#ddd"}`, color: "#333", fontSize: "14px" }}>
                                        <strong>🛡️ Garanti Durumu:</strong> {warranty.isExpired ? "Süresi dolmuştur." : warranty.isCritical ? `Bitmesine ${warranty.daysRemaining} gün kalmıştır.` : `${warranty.endDate.toLocaleDateString("tr-TR")} tarihine kadar geçerlidir.`}
                                    </span>
                                )}
                            </p>
                        </div>
                    )}
                </div>

                {/* ORTA - SON 3 GÜNLÜK CHECKLIST GEÇMİŞİ */}
                {!isFocusView && (
                    <div style={{ ...detayKartStil, flex: 3, width: "100%", marginTop: "10px", animation: "slideDown 0.3s ease-out" }}>
                        <h3 style={bolumBaslikStil}>Son 3 Günlük Kontrol ve Risk Analizi</h3>

                        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))", gap: "20px" }}>
                            {checklistHistory.map((item, idx) => (
                                <div key={idx} style={checklistKartStil}>
                                    <div style={checklistUstStil}>
                                        <span style={tarihRozetStil}>{new Date(item.tarih).toLocaleDateString("tr-TR")}</span>
                                        <span style={{
                                            padding: "4px 10px",
                                            borderRadius: "12px",
                                            fontSize: "12px",
                                            background: item.tespit_eden === "AI" ? "#6c5ce7" : item.tespit_eden === "Operatör" ? "#00b894" : "#e17055",
                                            color: "white",
                                            fontWeight: "bold"
                                        }}>
                                            Tespit: {item.tespit_eden}
                                        </span>
                                    </div>

                                    <div style={riskSebepStil}>
                                        <strong>⚠️ Risk Sebebi:</strong> {item.risk_sebebi}
                                    </div>

                                    <div style={{ marginTop: "15px" }}>
                                        <div style={{ fontSize: "13px", fontWeight: "bold", color: "#636e72", marginBottom: "8px" }}>Soru & Cevaplar</div>
                                        {item.cevaplar.map((c, i) => (
                                            <div key={i} style={cevapSatirStil}>
                                                <span style={{ flex: 1 }}>{c.soru}</span>
                                                <strong style={{ color: c.cevap === "HAYIR" ? "#d63031" : "#00b894" }}>{c.cevap}</strong>
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            ))}
                        </div>
                    </div>
                )}

                {/* SAĞ - SERVİS GEÇMİŞİ & PARÇALAR */}
                {!isFocusView && (
                    <div style={{ ...detayKartStil, flex: 2, minWidth: "400px", marginTop: "20px" }}>
                        <h3 style={bolumBaslikStil}>Servis Geçmişi ve Değişen Parçalar</h3>

                        {history.length === 0 ? (
                            <p style={{ color: "#777" }}>Henüz bir servis kaydı sisteme yansımamış.</p>
                        ) : (
                            <div style={{ display: "flex", flexDirection: "column", gap: "15px" }}>
                                {history.map((kayit) => (
                                    <div key={kayit.bakim_id} style={servisKartStil}>
                                        <div style={servisKartUstStil}>
                                            <span style={servisTarihStil}>
                                                {new Date(kayit.bakim_tarihi).toLocaleDateString("tr-TR")}
                                            </span>
                                            <span style={servisMaliyetStil}>
                                                Maliyet: {kayit.bakim_maliyet?.toLocaleString()} ₺
                                            </span>
                                        </div>

                                        <div style={{ display: "flex", gap: "20px", marginTop: "12px", fontSize: "14px" }}>
                                            <div>
                                                <span style={griBaslik}>Bakım Türü:</span> <strong>{kayit.bakim_turu?.bakim_tur_adi || "-"}</strong>
                                            </div>
                                            <div>
                                                <span style={griBaslik}>Servis Firması:</span> {kayit.servis_firmasi || `ID: ${kayit.servis_firma_id}`}
                                            </div>
                                            <div>
                                                <span style={griBaslik}>Temel Nedeni:</span> {kayit.ariza_sebebi}
                                            </div>
                                        </div>

                                        <p style={{ color: "#444", fontSize: "14px", margin: "12px 0", fontStyle: "italic", background: "white", padding: "10px", borderRadius: "6px" }}>
                                            "{kayit.aciklama}"
                                        </p>

                                        {kayit.degisen_parcalar && kayit.degisen_parcalar.length > 0 && (
                                            <div style={parcaKonteynerStil}>
                                                <span style={{ fontSize: "13px", fontWeight: "bold", color: "#e67e22", display: "flex", alignItems: "center", gap: "6px" }}>
                                                    ⚙️ Değiştirilen veya Temin Edilen Yedek Parçalar
                                                </span>
                                                <div style={{ display: "flex", flexWrap: "wrap", gap: "8px", marginTop: "10px" }}>
                                                    {kayit.degisen_parcalar.map((parca, idx) => (
                                                        <span key={idx} style={parcaRozetStil}>{parca}</span>
                                                    ))}
                                                </div>
                                            </div>
                                        )}
                                    </div>
                                ))}
                            </div>
                        )}
                    </div>
                )}
            </div>
        </div>

    );
}

// ================= CSS STILLERI ================= //
const sayfaStil = {
    minHeight: "100vh",
    background: "linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%)",
    padding: "40px 20px",
    boxSizing: "border-box",
    fontFamily: "'Segoe UI', Tahoma, Geneva, Verdana, sans-serif"
};

const containerStil = {
    maxWidth: "1200px",
    margin: "0 auto",
};

const headerStil = {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: "30px",
    padding: "20px 30px",
    background: "rgba(255, 255, 255, 0.05)",
    borderRadius: "16px",
    backdropFilter: "blur(12px)",
    border: "1px solid rgba(255,255,255,0.1)",
    boxShadow: "0 8px 32px rgba(0,0,0,0.15)"
};

const kartlarAlaniStil = {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))",
    gap: "20px",
    marginBottom: "30px",
};

const bilgiKartStil = {
    background: "white",
    padding: "20px",
    borderRadius: "16px",
    boxShadow: "0 4px 20px rgba(0,0,0,0.08)",
    display: "flex",
    alignItems: "center",
    gap: "18px",
    transition: "transform 0.2s",
};

const kartIkonStil = {
    fontSize: "30px",
    background: "#f0f4f8",
    width: "60px",
    height: "60px",
    display: "flex",
    justifyContent: "center",
    alignItems: "center",
    borderRadius: "14px"
};

const btnStyle = {
    padding: "10px 15px",
    background: "#e94560",
    color: "white",
    border: "none",
    borderRadius: "6px",
    cursor: "pointer",
    fontWeight: "bold",
    fontSize: "13px",
    transition: "0.2s"
};

const kartBaslikStil = {
    fontSize: "13px",
    color: "#7f8c8d",
    textTransform: "uppercase",
    fontWeight: "600",
    marginBottom: "6px",
    letterSpacing: "0.5px"
};

const kartDegerStil = {
    fontSize: "22px",
    fontWeight: "900",
    color: "#2c3e50",
};

const gridIkiKolonStil = {
    display: "flex",
    gap: "20px",
    alignItems: "flex-start",
    flexWrap: "wrap",
    paddingBottom: "50px"
};

const detayKartStil = {
    background: "white",
    padding: "30px",
    borderRadius: "16px",
    boxShadow: "0 4px 20px rgba(0,0,0,0.08)",
};

const bolumBaslikStil = {
    color: "#0f3460",
    marginTop: 0,
    marginBottom: "20px",
    fontSize: "19px",
    borderBottom: "2px solid #e1e5eb",
    paddingBottom: "12px",
    fontWeight: "bold"
};

const tedarikciListeStil = {
    display: "flex",
    flexDirection: "column",
    gap: "14px",
    fontSize: "15px",
    color: "#34495e"
};

const tedarikciSatirStil = {
    display: "flex",
    justifyContent: "space-between",
    borderBottom: "1px dashed #eee",
    paddingBottom: "10px"
};

const tedarikciEtiketStil = {
    color: "#95a5a6",
    fontWeight: "bold"
};

const servisKartStil = {
    background: "#f8f9fa",
    color: "#2c3e50",
    border: "1px solid #e1e5eb",
    padding: "20px",
    borderRadius: "14px",
    display: "flex",
    flexDirection: "column",
    boxShadow: "0 2px 5px rgba(0,0,0,0.02)"
};

const servisKartUstStil = {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    borderBottom: "2px dashed #ddd",
    paddingBottom: "12px"
};

const servisTarihStil = {
    fontWeight: "bold",
    color: "#2c3e50",
    background: "white",
    padding: "6px 14px",
    borderRadius: "8px",
    border: "1px solid #ccd1d9",
    boxShadow: "0 1px 3px rgba(0,0,0,0.05)"
};

const servisMaliyetStil = {
    fontWeight: "800",
    color: "#c0392b",
    fontSize: "17px"
};

const griBaslik = {
    color: "#7f8c8d",
    fontSize: "13px",
    marginRight: "4px"
};

const parcaKonteynerStil = {
    marginTop: "12px",
    background: "linear-gradient(to right, rgba(230, 126, 34, 0.1), transparent)",
    padding: "15px",
    borderRadius: "10px",
    borderLeft: "4px solid #e67e22"
};

const parcaRozetStil = {
    background: "white",
    color: "#d35400",
    border: "1px solid #e67e22",
    padding: "6px 14px",
    borderRadius: "20px",
    fontSize: "13px",
    fontWeight: "bold",
    boxShadow: "0 2px 6px rgba(230,126,34,0.15)",
    transition: "transform 0.1s",
    cursor: "default"
};

const checklistKartStil = {
    background: "#fdfefe",
    color: "#2d3436",
    border: "1px solid #d1d8e0",
    borderRadius: "12px",
    padding: "20px",
    boxShadow: "0 4px 6px rgba(0,0,0,0.02)",
    display: "flex",
    flexDirection: "column",
    gap: "12px"
};

const checklistUstStil = {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    borderBottom: "1px solid #eee",
    paddingBottom: "10px"
};

const tarihRozetStil = {
    fontSize: "13px",
    fontWeight: "bold",
    color: "#2d3436",
    background: "#dfe6e9",
    padding: "4px 10px",
    borderRadius: "6px"
};

const riskSebepStil = {
    fontSize: "14px",
    color: "#d63031",
    background: "#fff5f5",
    padding: "10px",
    borderRadius: "8px",
    borderLeft: "4px solid #d63031",
    lineHeight: "1.4"
};

const cevapSatirStil = {
    display: "flex",
    justifyContent: "space-between",
    fontSize: "13px",
    color: "#2d3436",
    padding: "6px 0",
    borderBottom: "1px dashed #f1f2f6"
};