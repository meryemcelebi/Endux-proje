import React from "react";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";

// Sayfa Bileşenleri (Sistemin farklı bölümlerini temsil eden sayfalar)
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
import MaliyetDetay from "./MaliyetDetay";
import SistemAyarlari from "./SistemAyarlari";

/**
 * Giriş Yapılmayan Kullanıcıları Login Ekranına Yönlendiren Component (Korumalı Rota)
 * Yerel depolamada (LocalStorage) geçerli bir 'auth_token' yoksa kullanıcının sayfayı görmesini engeller
 * ve otomatik olarak giriş (Login) sayfasına geri gönderir.
 */
function KorumaliRoute({ children }) {
  const token = localStorage.getItem("auth_token"); // Tarayıcı hafızasındaki giriş anahtarını kontrol et
  if (!token) {
    // Token yoksa ana giriş sayfasına yönlendir
    return <Navigate to="/" replace />;
  }
  // Token varsa istenen sayfayı (children) göster
  return children;
}

// Uygulamanın Ana Giriş Noktası ve Yönlendirme (Router) Yapılandırması
export default function App() {
  return (
    <BrowserRouter>

      <Routes>
        {/* Giriş Ekranı - Uygulama açıldığında karşılanacak ilk sayfa */}
        <Route path="/" element={<Login />} />

        {/* --- Yönetici ve Personel Panelleri (Korumalı Rotalar) --- */}
        {/* Aşağıdaki sayfaların hepsi 'KorumaliRoute' içine alınmıştır, giriş yapmadan ulaşılamazlar. */}

        {/* Ana Kontrol Paneli (Dashboard): Özet verilerin ve KPI'ların olduğu ana ekran */}
        <Route path="/dashboard" element={<KorumaliRoute><Dashboard /></KorumaliRoute>} />

        {/* Günlük Kontrol Listeleri Giriş Ekranı (Makine bazlı veya genel liste) */}
        <Route path="/checklist-giris/:id" element={<ChecklistGiris />} />
        <Route path="/checklist-giris" element={<ChecklistGiris />} />

        {/* Teknik Servis Kaydı Girme Ekranı (Spesifik bir makine arızası için) */}
        <Route path="/servis/:id" element={<KorumaliRoute><Servis /></KorumaliRoute>} />

        {/* Spesifik bir makinenin detay sayfası: Tüm grafik ve geçmiş verileri barındırır */}
        <Route path="/makine/:id" element={<KorumaliRoute><MakineDetay /></KorumaliRoute>} />

        {/* Belirli bir makine için Checklist formu doldurma alanı */}
        <Route path="/checklist/:id" element={<KorumaliRoute><Checklist /></KorumaliRoute>} />

        {/* Tüm makinelerin listelendiği, düzenlendiği ve silindiği yönetim ekranı */}
        <Route path="/makineler" element={<KorumaliRoute><Makineler /></KorumaliRoute>} />

        {/* Yeni personel veya teknik kişi ekleme/yönetme ekranı */}
        <Route path="/kisi-ekle" element={<KorumaliRoute><KisiEkle /></KorumaliRoute>} />

        {/* Bakım planlama, takvim ve yıllık maliyet takip ekranı */}
        <Route path="/bakim" element={<KorumaliRoute><Bakim /></KorumaliRoute>} />

        {/* Tedarikçi listesi, stok durumu ve yedek parça performans takip ekranı */}
        <Route path="/tedarikciler" element={<KorumaliRoute><TedarikciListesi /></KorumaliRoute>} />

        {/* Teknik Servis Merkezi: Tüm bakım ve onarım süreçlerinin tek bir yerden yönetildiği pano */}
        <Route path="/teknik-servis" element={<KorumaliRoute><ServisMerkezi /></KorumaliRoute>} />

        {/* Maliyet Detay Sayfası: Makine bazlı maliyet ve duruş kayıpları analizi */}
        <Route path="/maliyet-detay" element={<KorumaliRoute><MaliyetDetay /></KorumaliRoute>} />

        {/* Sistem Ayarları: Vardiya saatleri ve genel sistem parametreleri */}
        <Route path="/sistem-ayarlari" element={<KorumaliRoute><SistemAyarlari /></KorumaliRoute>} />

        {/* Tanımsız veya hatalı yazılmış rotalar için kullanıcıyı otomatik olarak ana sayfaya yönlendir */}
        <Route path="*" element={<Navigate to="/" replace />} />

      </Routes>

    </BrowserRouter>
  );
}
