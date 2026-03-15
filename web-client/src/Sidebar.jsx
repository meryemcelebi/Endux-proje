import React from 'react';
import { Link } from 'react-router-dom';

const Sidebar = () => (
  <div style={{ width: '200px', background: 'darkslategray', color: 'white', height: '100vh', padding: '20px' }}>
    <h3>Menü</h3>
    <nav style={{ display: 'flex', flexDirection: 'column', gap: '15px', marginTop: '20px' }}>
      <Link to="/" style={{ color: 'white', textDecoration: 'none' }}>Dashboard</Link>
      <Link to="/makineler" style={{ color: 'white', textDecoration: 'none' }}>Makineler</Link>
    </nav>
  </div>
);

export default Sidebar;