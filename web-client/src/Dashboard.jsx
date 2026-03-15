import React from 'react';

const Dashboard = () => (
  <div style={{ padding: '20px' }}>
    <h2>Dashboard</h2>
    <p>*Buraya ileride KPI kutuları ve harita gelecek.*</p>

    {/* Üst KPI Kutuları */}
    <div style={{ display: 'flex', gap: '20px', marginTop: '20px' }}>
      <div style={{
        flex: 1,
        background: 'lightgray',
        padding: '30px',
        border: '2px dashed gray',
        textAlign: 'center',
        borderRadius: '8px'
      }}>
         Günlük Kritik Uyarılar
      </div>

      <div style={{
        flex: 1,
        background: 'lightgray',
        padding: '30px',
        border: '2px dashed gray',
        textAlign: 'center',
        borderRadius: '8px'
      }}>
         Bekleyen Bakım Onayları
      </div>

      <div style={{
        flex: 1,
        background: 'lightgray',
        padding: '30px',
        border: '2px dashed gray',
        textAlign: 'center',
        borderRadius: '8px'
      }}>
         Genel OEE Skoru
      </div>
    </div>

    {/* Alt Harita ve Masraf Kutuları */}
    <div style={{ display: 'flex', gap: '20px', marginTop: '20px' }}>
      
      {/* Harita Kutusu */}
      <div style={{
        flex: 2,
        height: '300px',
        background: 'lightgray',
        border: '2px dashed gray',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        borderRadius: '8px',
        fontWeight: 'bold'
      }}>
         Buraya Fabrika Haritası Gelecek
      </div>

      {/* Masraf Kutusu */}
      <div style={{
        flex: 1,
        height: '300px',
        background: 'lightgray',
        border: '2px dashed gray',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        borderRadius: '8px',
        fontWeight: 'bold',
        textAlign: 'center',
        padding: '10px'
      }}>
         Makine Alım & Bakım Masraf Oranı
      </div>

    </div>
  </div>
);

export default Dashboard;