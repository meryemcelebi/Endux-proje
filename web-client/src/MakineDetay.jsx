import React from "react";
import { useParams } from "react-router-dom";

export default function MakineDetay() {
    const { id } = useParams();

    return (
        <div style={{ padding: 20 }}>
            <h2>Makine Yönetici Paneli</h2>

            <p><b>Makine ID:</b> {id}</p>

            <div style={{
                marginTop: 20,
                padding: 15,
                border: "1px solid #ccc",
                borderRadius: 8
            }}>
                <p> Durum: Aktif</p>
                <p> Son bakım: 12.03.2026</p>
                <p> Çalışma süresi: 148 saat</p>
                <p> Uyarı: Yok</p>
            </div>
        </div>
    );
}