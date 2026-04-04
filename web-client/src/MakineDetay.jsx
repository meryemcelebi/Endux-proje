import React, { useState, useEffect } from "react";
import { useParams } from "react-router-dom";
import { api } from "./services/api";

/**
 * Makine Detay Sayfası
 * Belirli bir makinenin teknik özelliklerini, çalışma süresini, 
 * maliyet analizini ve tüm servis/parça değişim geçmişini gösterir.
 */
export default function MakineDetay() {
    const { id } = useParams(); // URL'den makine ID'sini al
    const [machine, setMachine] = useState(null); // Makine temel bilgileri
    const [history, setHistory] = useState([]); // Makineye ait servis geçmişi
    const [loading, setLoading] = useState(true); // Veri yükleme durumu

    useEffect(() => {
        const loadData = async () => {
            try {
                const [macData, histData] = await Promise.all([
                    api.getMachineDetails(id),
                    api.getServiceHistory(id)
                ]);
                setMachine(macData);
                setHistory(histData);
            } catch (err) {
                console.error("Detaylar yüklenemedi", err);
            } finally {
                setLoading(false);
            }
        };
        loadData();
    }, [id]);

    if (loading) {
        return <div style={{...sayfaStil, color: "white", textAlign: "center", paddingTop: "100px", fontSize: "20px"}}>Veriler Yükleniyor... Dökümler Hazırlanıyor...</div>;
    }

    if (!machine) {
        return <div style={{...sayfaStil, color: "white", textAlign: "center", paddingTop: "100px"}}>Makine bulunamadı.</div>;
    }

    const totalBakimMaliyet = history.reduce((sum, item) => sum + (item.bakim_maliyet?.[0] || 0), 0);

    return (
        <div style={sayfaStil}>
            <div style={containerStil}>
                {/* BAŞLIK */}
                <div style={headerStil}>
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
                            Seri No: {machine.seri_no?.join(", ")} | Kimlik: #{id}
                        </div>
                    </div>
                </div>

                {/* KPI KARTLARI */}
                <div style={kartlarAlaniStil}>
                    <div style={bilgiKartStil}>
                        <div style={kartIkonStil}>⏱️</div>
                        <div>
                            <div style={kartBaslikStil}>Toplam Çalışma Süresi</div>
                            <div style={kartDegerStil}>{machine.top_cal_sma_saati?.[0]} Saat</div>
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

                {/* İKİLİ KOLON */}
                <div style={gridIkiKolonStil}>
                    {/* SOL - TEDARİKÇİ & ÖZET */}
                    <div style={{ display: "flex", flexDirection: "column", gap: "20px", flex: 1, minWidth: "320px" }}>
                        <div style={detayKartStil}>
                            <h3 style={bolumBaslikStil}>Tedarikçi (Satıcı) Bilgileri</h3>
                            {machine.tedarikci ? (
                                <div style={tedarikciListeStil}>
                                    <div style={tedarikciSatirStil}>
                                        <span style={tedarikciEtiketStil}>Firma:</span> 
                                        <strong style={{color: "navy"}}>{machine.tedarikci.firma_adi}</strong>
                                    </div>
                                    <div style={tedarikciSatirStil}>
                                        <span style={tedarikciEtiketStil}>Telefon:</span> 
                                        {machine.tedarikci.telefon}
                                    </div>
                                    <div style={tedarikciSatirStil}>
                                        <span style={tedarikciEtiketStil}>E-Posta:</span> 
                                        {machine.tedarikci.email}
                                    </div>
                                    <div style={tedarikciSatirStil}>
                                        <span style={tedarikciEtiketStil}>Adres:</span> 
                                        <span style={{textAlign: "right", maxWidth: "160px"}}>{machine.tedarikci.adres}</span>
                                    </div>
                                </div>
                            ) : (
                                <p style={{color: "#777"}}>Tedarikçi veritabanında bulunamadı.</p>
                            )}
                        </div>

                        <div style={detayKartStil}>
                            <h3 style={bolumBaslikStil}>Makine Analiz Özeti</h3>
                            <p style={{ color: "#555", lineHeight: "1.6", margin: 0 }}>
                                Bu makine en son satın alma tarihinden ({new Date(machine.satin_alma_tarihi).toLocaleDateString("tr-TR")}) bu yana toplam <strong>{machine.top_cal_sma_saati?.[0]} saat</strong> aktif hizmet vermiştir. Servis kayıtlarında toplam <strong>{history.length}</strong> adet bakım veya arıza kaydı gözükmektedir. Risk skoru algoritmik olarak <strong>{machine.mevcut_risk_skoru}</strong> hesaplanmış olup, sistemde <strong style={{ color: machine.aktiflik_durumu === "Aktif" ? "#2ecc71" : machine.aktiflik_durumu === "Bakımda" ? "#f39c12" : "#e74c3c" }}>{machine.aktiflik_durumu === "Aktif" ? "aktif çalışmaya uygundur." : machine.aktiflik_durumu === "Bakımda" ? "bakım sürecindedir." : "arızalı olarak etiketlenmiştir."}</strong>
                            </p>
                        </div>
                    </div>

                    {/* SAĞ - SERVİS GEÇMİŞİ & PARÇALAR */}
                    <div style={{...detayKartStil, flex: 2, minWidth: "400px"}}>
                        <h3 style={bolumBaslikStil}>Servis Geçmişi ve Değişen Parçalar</h3>
                        
                        {history.length === 0 ? (
                            <p style={{color: "#777"}}>Henüz bir servis kaydı sisteme yansımamış.</p>
                        ) : (
                            <div style={{ display: "flex", flexDirection: "column", gap: "15px" }}>
                                {history.map((kayit) => (
                                    <div key={kayit.bakim_id} style={servisKartStil}>
                                        <div style={servisKartUstStil}>
                                            <span style={servisTarihStil}>
                                                 {new Date(kayit.bakim_tarihi[0]).toLocaleDateString("tr-TR")}
                                            </span>
                                            <span style={servisMaliyetStil}>
                                                Maliyet: {kayit.bakim_maliyet[0]?.toLocaleString()} ₺
                                            </span>
                                        </div>
                                        
                                        <div style={{ display: "flex", gap: "20px", marginTop: "12px", fontSize: "14px" }}>
                                            <div>
                                                <span style={griBaslik}>Bakım Türü:</span> <strong>{kayit.bakim_turu?.[0] || "-"}</strong>
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
                </div>
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