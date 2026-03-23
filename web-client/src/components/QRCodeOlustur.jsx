import React from 'react';
import { QRCodeCanvas } from 'qrcode.react';

const QRCodeOlustur = ({ makinaId }) => {

  const qrValue = `https://endux-app.com/operator/islem?qr=${makinaId}`;

  return (
    <div style={{ textAlign: 'center' }}>
      <h3>QR Kod</h3>

      <QRCodeCanvas value={qrValue} size={200} />

      <p>{qrValue}</p>
    </div>
  );
};

export default QRCodeOlustur;