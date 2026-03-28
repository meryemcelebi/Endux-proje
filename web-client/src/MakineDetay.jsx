import React from "react";
import { useParams } from "react-router-dom";

export default function MakineDetay() {
    const { id } = useParams();

    return (
        <div style={sayfaStil}>
            <div style={containerStil}>
                {/* BAŞLIK */}
                <div style={headerStil}>
                    <h2 style={{ margin: 0, color: "white", fontSize: "22px" }}>Makine Yönetici Paneli</h2>
                    <div style={badgeStil}>Makine ID: {id}</div>
                </div>

                {/* BİLGİ KARTLARI */}
                <div style={kartlarAlaniStil}>
                    <div style={bilgiKartStil}>

                        <div>
                            <div style={kartBaslikStil}>Durum</div>
                            <div style={kartDegerStil}>Aktif</div>
                        </div>
                    </div>

                    <div style={bilgiKartStil}>

                        <div>
                            <div style={kartBaslikStil}>Son Bakım</div>
                            <div style={kartDegerStil}>12.03.2026</div>
                        </div>
                    </div>

                    <div style={bilgiKartStil}>

                        <div>
                            <div style={kartBaslikStil}>Çalışma Süresi</div>
                            <div style={kartDegerStil}>148 saat</div>
                        </div>
                    </div>

                    <div style={bilgiKartStil}>

                        <div>
                            <div style={kartBaslikStil}>Uyarı</div>
                            <div style={kartDegerStil}>Yok</div>
                        </div>
                    </div>
                </div>

                {/* DETAY ALANI */}
                <div style={detayKartStil}>
                    <h3 style={{ color: "navy", marginTop: 0 }}>Makine Özeti</h3>
                    <p style={{ color: "#555", lineHeight: "1.8" }}>
                        Bu makine şu an <strong>aktif</strong> durumda çalışmaktadır.
                        Son bakım tarihi <strong>12.03.2026</strong> olarak kayıtlara geçmiştir.
                        Toplam çalışma süresi <strong>148 saat</strong> olup herhangi bir uyarı bulunmamaktadır.
                    </p>
                </div>
            </div>
        </div>
    );
}

/* STILLER */
const sayfaStil = {
    minHeight: "100vh",
    background: "linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%)",
    padding: "30px",
    boxSizing: "border-box",
};

const containerStil = {
    maxWidth: "900px",
    margin: "0 auto",
};

const headerStil = {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: "25px",
    padding: "20px 25px",
    background: "rgba(255,255,255,0.1)",
    borderRadius: "12px",
    backdropFilter: "blur(10px)",
};

const badgeStil = {
    padding: "6px 16px",
    background: "rgba(255,255,255,0.2)",
    color: "white",
    borderRadius: "20px",
    fontSize: "13px",
    fontWeight: "bold",
};

const kartlarAlaniStil = {
    display: "grid",
    gridTemplateColumns: "repeat(4, 1fr)",
    gap: "20px",
    marginBottom: "25px",
};

const bilgiKartStil = {
    background: "white",
    padding: "20px",
    borderRadius: "12px",
    boxShadow: "0 4px 15px rgba(0,0,0,0.1)",
    display: "flex",
    alignItems: "center",
    gap: "15px",
};

const kartIconStil = {
    fontSize: "28px",
};

const kartBaslikStil = {
    fontSize: "12px",
    color: "#999",
    textTransform: "uppercase",
    fontWeight: "bold",
    marginBottom: "4px",
};

const kartDegerStil = {
    fontSize: "18px",
    fontWeight: "bold",
    color: "navy",
};

const detayKartStil = {
    background: "white",
    padding: "25px 30px",
    borderRadius: "12px",
    boxShadow: "0 4px 15px rgba(0,0,0,0.1)",
};