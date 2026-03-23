import React from "react";
import { BrowserRouter, Routes, Route } from "react-router-dom";

import Dashboard from "./Dashboard";
import ChecklistGiris from "./ChecklistGiris";
import Checklist from "./Checklist";
import Makineler from "./Makineler"; // ✅ EKLENDİ
import MakineDetay from "./MakineDetay";

export default function App() {
  return (
    <BrowserRouter>

      <Routes>

        {/* 🟢 YÖNETİCİ PANEL */}
        <Route path="/" element={<Dashboard />} />

        {/* 🔐 CHECKLIST GİRİŞ */}
        <Route path="/checklist-giris" element={<ChecklistGiris />} />
         {/* 🔥 BU ÇOK ÖNEMLİ */}
        <Route path="/makine/:id" element={<MakineDetay />} />

        {/* 📋 CHECKLIST */}
        <Route path="/checklist/:id" element={<Checklist />} />

        {/* ⚙️ MAKİNELER */}
        <Route path="/makineler" element={<Makineler />} />

      </Routes>

    </BrowserRouter>
  );
}