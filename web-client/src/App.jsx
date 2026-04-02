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
import Bakim from "./Bakim";
import TedarikciListesi from "./TedarikciListesi";

/* Giriş yapılmadıysa login'e yönlendir */
function KorumaliRoute({ children }) {   
  const token = localStorage.getItem("auth_token");   
  if (!token) {    
    return <Navigate to="/" replace />;
  }
  return children; 
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

        {/* BAKIM */}
        <Route path="/bakim" element={<KorumaliRoute><Bakim /></KorumaliRoute>} />

        {/* TEDARIKÇİLER */}
        <Route path="/tedarikciler" element={<KorumaliRoute><TedarikciListesi /></KorumaliRoute>} />

      </Routes>

    </BrowserRouter>
  );
}
