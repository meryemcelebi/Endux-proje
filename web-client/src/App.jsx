import React from "react";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";

import Login from "./Login";
import Dashboard from "./Dashboard";
import ChecklistGiris from "./ChecklistGiris";
import Servis from "./Servis";
import Checklist from "./Checklist";
import Makineler from "./Makineler";
import MakineDetay from "./MakineDetay";
import KisiEkle from "./KisiEkle";

/* Giriş yapılmadıysa login'e yönlendir */
function KorumaliRoute({ children }) {   // KorumaliRoute adında bir component (route guard) oluşturulur
  // children = bu component'in içine sarılan sayfa (örneğin Dashboard)

  const girisYapildi = localStorage.getItem("girisYapildi");   // Tarayıcının localStorage'ından "girisYapildi" değeri alınır login olunca true olur
  if (!girisYapildi) {    // Kullanıcıyı "/" yani login sayfasına yönlendirir
    return <Navigate to="/" replace />;
  }
  return children; // Eğer giriş yapılmışsa, içindeki sayfayı gösterir (erişim izinli)
}

export default function App() {
  return (
    <BrowserRouter>

      <Routes>
        {/*kullanıcı şu linke giderse (path)
       şu component açılır (element)*/}

        {/* GİRİŞ EKRANI */}
        <Route path="/" element={<Login />} />

        {/* YÖNETİCİ PANEL */}
        <Route path="/dashboard" element={<KorumaliRoute><Dashboard /></KorumaliRoute>} />

        {/*  CHECKLIST GİRİŞ */}
        <Route path="/checklist-giris" element={<KorumaliRoute><ChecklistGiris /></KorumaliRoute>} />
        {/* BU ÇOK ÖNEMLİ */}
        <Route path="/makine/:id" element={<KorumaliRoute><MakineDetay /></KorumaliRoute>} />

        {/*  CHECKLIST */}
        <Route path="/checklist/:id" element={<KorumaliRoute><Checklist /></KorumaliRoute>} />

        {/*  MAKİNELER */}
        <Route path="/makineler" element={<KorumaliRoute><Makineler /></KorumaliRoute>} />

        {/*  KİŞİ EKLE */}
        <Route path="/kisi-ekle" element={<KorumaliRoute><KisiEkle /></KorumaliRoute>} />

        {/* TEKNİK SERVİS */}
        <Route path="/servis/:id" element={<KorumaliRoute><Servis /></KorumaliRoute>} />

      </Routes>

    </BrowserRouter>
  );
}
