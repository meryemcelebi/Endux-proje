import React, { useState } from 'react';
import QRCodeOlustur from './QRCodeOlustur';

const MakineEkle = ({ onEkle }) => {

  const [form, setForm] = useState({
    ad: '',
    marka: '',
    fiyat: '',
    omur: ''
  });

  const [qrId, setQrId] = useState(null);

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const handleSubmit = () => {

    const yeniMakine = {
      ...form,
      id: Date.now().toString()
    };

    onEkle(yeniMakine);
    setQrId(yeniMakine.id);

    setForm({
      ad: '',
      marka: '',
      fiyat: '',
      omur: ''
    });
  };

  return (
    <div>

      <h3>Makine Ekle</h3>

      <input name="ad" placeholder="Ad" value={form.ad} onChange={handleChange} /><br />
      <input name="marka" placeholder="Marka" value={form.marka} onChange={handleChange} /><br />
      <input name="fiyat" placeholder="Alış Fiyat" value={form.fiyat} onChange={handleChange} /><br />
      <input name="omur" placeholder="Ömür" value={form.omur} onChange={handleChange} /><br />

      <button onClick={handleSubmit} style={{ marginTop: '10px' }}>
        Kaydet
      </button>

      {qrId && (
        <div style={{ marginTop: '20px' }}>
          <QRCodeOlustur makinaId={qrId} />
        </div>
      )}

    </div>
  );
};

export default MakineEkle;