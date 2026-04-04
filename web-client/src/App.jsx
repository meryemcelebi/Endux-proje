import React from "react";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";

// Sayfa Bileşenleri (Pages)
import Login from "./Login";
import Dashboard from "./Dashboard";
import ChecklistGiris from "./ChecklistGiris";
import Servis from "./Servis";
import Checklist from "./Checklist";
import Makineler from "./Makineler";
import MakineDetay from "./MakineDetay";
import KisiEkle from "./KisiEkle";
import Bakim from "./Bakim";
import TedarikciListesi from "./TedarikciListesi";
import ServisMerkezi from "./ServisMerkezi";

/**
 * Giriş Yapılmayan Kullanıcıları Login Ekranına Yönlendiren Component
 * Yerel depolamada (LocalStorage) token yoksa erişimi engeller.
 */
function KorumaliRoute({ children }) {
  const token = localStorage.getItem("auth_token");
  if (!token) {
    return <Navigate to="/" replace />;
  }
  return children;
}

// Uygulamanın Ana Giriş Noktası ve Router Yapılandırması
export default function App() {
  return (
    <BrowserRouter>

      <Routes>
        {/* Giriş Ekranı - Uygulamanın başlangıç noktası */}
        <Route path="/" element={<Login />} />

        {/* --- Yönetici ve Personel Panelleri (Korumalı Rotalar) --- */}

        {/* Ana Kontrol Paneli */}
        <Route path="/dashboard" element={<KorumaliRoute><Dashboard /></KorumaliRoute>} />

        {/* Günlük Kontrol Listeleri Giriş Ekranı */}
        <Route path="/checklist-giris/:id" element={<ChecklistGiris />} />
        <Route path="/checklist-giris" element={<ChecklistGiris />} />

        {/* Teknik Servis Kaydı Girme Ekranı */}
        <Route path="/servis/:id" element={<KorumaliRoute><Servis /></KorumaliRoute>} />

        {/* Spesifik bir makinenin detay sayfası */}
        <Route path="/makine/:id" element={<KorumaliRoute><MakineDetay /></KorumaliRoute>} />

        {/* Belirli bir makine için Checklist formu */}
        <Route path="/checklist/:id" element={<KorumaliRoute><Checklist /></KorumaliRoute>} />

        {/* Tüm makinelerin listelendiği yönetim ekranı */}
        <Route path="/makineler" element={<KorumaliRoute><Makineler /></KorumaliRoute>} />

        {/* Yeni personel/kişi ekleme ekranı */}
        <Route path="/kisi-ekle" element={<KorumaliRoute><KisiEkle /></KorumaliRoute>} />

        {/* Bakım planlama ve maliyet takip ekranı */}
        <Route path="/bakim" element={<KorumaliRoute><Bakim /></KorumaliRoute>} />

        {/* Tedarikçi listesi ve stok performans takip ekranı */}
        <Route path="/tedarikciler" element={<KorumaliRoute><TedarikciListesi /></KorumaliRoute>} />

        {/* Teknik Servis Merkezi - Tüm bakım süreçlerinin yönetildiği pano */}
        <Route path="/teknik-servis" element={<KorumaliRoute><ServisMerkezi /></KorumaliRoute>} />

        {/* Tanımsız rotalar için ana sayfaya yönlendir */}
        <Route path="*" element={<Navigate to="/" replace />} />

      </Routes>

    </BrowserRouter>
  );
}
