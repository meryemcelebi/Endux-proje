import React from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';

import Navbar from './Navbar';
import Sidebar from './Sidebar';
import Dashboard from './Dashboard';
import Makineler from './Makineler';

export default function App() {
  return (
    <BrowserRouter>
      <div style={{ display: 'flex', minHeight: '100vh', fontFamily: 'Arial, sans-serif' }}>
        <Sidebar />
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
          <Navbar />
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/makineler" element={<Makineler />} />
          </Routes>
        </div>
      </div>
    </BrowserRouter>
  );
}