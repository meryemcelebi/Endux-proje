import React from "react";
import { BrowserRouter, Routes, Route } from "react-router-dom";

import Dashboard from "./Dashboard";
import ChecklistGiris from "./ChecklistGiris";
import Servis from "./Servis";
import Checklist from "./Checklist";
import Makineler from "./Makineler"; 
import MakineDetay from "./MakineDetay";

export default function App() {
  return (
    <BrowserRouter>

      <Routes>
       {/*kullanıcı şu linke giderse (path)
       şu component açılır (element)*/}


        {/* YÖNETİCİ PANEL */}
        <Route path="/" element={<Dashboard />} />

        {/*  CHECKLIST GİRİŞ */}
        <Route path="/checklist-giris" element={<ChecklistGiris />} />
         {/* BU ÇOK ÖNEMLİ */}
        <Route path="/makine/:id" element={<MakineDetay />} />

        {/*  CHECKLIST */}
        <Route path="/checklist/:id" element={<Checklist />} />

        {/*  MAKİNELER */}
        <Route path="/makineler" element={<Makineler />} />
        {/* TEKNİK SERVİS */}
        <Route path="/servis/:id" element={<Servis />} />


      </Routes>

    </BrowserRouter>
  );
}