import React from 'react';
import { QRCodeCanvas } from 'qrcode.react';

const QRCodeOlustur = ({ makinaId }) => {
  // props olarak makinaId alınır (yani dışarıdan gelen veri)

  const qrValue = `https://endux-app.com/operator/islem?qr=${makinaId}`;
// QR kodun içeriği oluşturulur
  return (
    // ekranda ne görünecek
    <div style={{ textAlign: 'center' }}>  {/*ortalar*/}
      <h3>QR Kod</h3> {/*baslık*/}

      <QRCodeCanvas value={qrValue} size={200} />
     {/*qrı ekrana basar veri ve boyutunu içerir*/}
      <p>{qrValue}</p>
    </div>
  );
};

export default QRCodeOlustur;