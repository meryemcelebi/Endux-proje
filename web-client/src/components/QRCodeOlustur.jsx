/**
 * QR Kod Oluşturma ve Yazdırma Bileşeni
 * Verilen makine ID'sine göre bir URL oluşturur, QR kod haline getirir
 * ve operatörün bu kodu fiziksel makine üzerine yapıştırması için yazdırma imkanı sunar.
 */
const QRCodeOlustur = ({ makinaId }) => {
  // props olarak makinaId alınır (yani dışarıdan gelen veri)
  const qrRef = useRef(null); /*QR alanını referans olarak tutar*/

  const qrValue = `https://endux-app.com/operator/islem?qr=${makinaId}`;
  // QR kodun içeriği oluşturulur

  const handlePrint = () => {
    /*QR canvas'ını resme çevirip yeni pencerede yazdırır*/
    const canvas = qrRef.current?.querySelector('canvas');  // QR kod canvas olarak çizildiği için, o canvas elementi seçilir
    if (!canvas) return;  // Eğer canvas bulunamazsa işlemi durdurur


    const imgData = canvas.toDataURL('image/png');  // Canvas'ı PNG formatında resme çevirir (base64 veri üretir)
    const printWindow = window.open('', '_blank');
    printWindow.document.write(`
      <html>
        <head><title>QR Kod Çıktısı</title></head>
        <body style="display:flex; flex-direction:column; align-items:center; justify-content:center; height:100vh; margin:0;">
          <h2>QR Kod</h2>
          <img src="${imgData}" style="width:200px; height:200px;" />
          <p style="font-size:12px; color:gray; margin-top:10px;">${qrValue}</p>
        </body>
      </html>      
    `);
    printWindow.document.close();
    printWindow.focus();   // Açılan pencereye odaklanır
    printWindow.print();   // Yazdırma penceresini açar
    printWindow.close();   // Yazdırma sonrası pencereyi kapatır
  };

  return (
    // ekranda ne görünecek
    <div style={{ textAlign: 'center' }}>  {/*ortalar*/}
      <h3>QR Kod</h3> {/*baslık*/}

      <div ref={qrRef}>   {/*// QR kodun bulunduğu div (referans burada tutulur)*/}
        <QRCodeCanvas value={qrValue} size={200} />
      </div>
      {/*qrı ekrana basar veri ve boyutunu içerir*/}
      <p>{qrValue}</p>

      <button
        onClick={handlePrint}
        // Butona basılınca handlePrint çalışır

        // Butonun görünüm ayarları
        style={{
          marginTop: '10px',
          padding: '10px 20px',
          background: 'darkslategray',
          color: 'white',
          border: 'none',
          borderRadius: '6px',
          cursor: 'pointer',
          fontWeight: 'bold'
        }}
      >
        Çıktı Al
      </button>
      {/*yazdırma butonu*/}
    </div>
  );
};

export default QRCodeOlustur;