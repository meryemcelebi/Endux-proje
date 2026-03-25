import React, { useState } from 'react'; /*useState:form verisini tutmak için*/
import QRCodeOlustur from './QRCodeOlustur'; 

const MakineEkle = ({ onEkle }) => { /*makine eklenince listeye gönder*/

  const [form, setForm] = useState({ /*verileri tutar*/
    ad: '',
    marka: '',
    fiyat: '',
    omur: ''
  });

  const [qrId, setQrId] = useState(null); /*Makine kaydedilince oluşan ID burada tutulur qr bu id ile oluşur*/

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value }); /*name neyse ona göre form güncellenir*/
  };

  const handleSubmit = () => { /*kaydet butonuna basınca çalışır*/

    const yeniMakine = {
      ...form,
      id: Date.now().toString() 
 /*Formdaki tüm bilgileri alır
 Üstüne benzersiz ID ekler
 Date.now() = anlık sayı (unique id)*/
    };

    onEkle(yeniMakine); /*makine listesine ekle*/
    setQrId(yeniMakine.id);

    setForm({ /*inputları temizliyor*/
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

     {/*onChange=handleChange kullanıcı yazdıkça state güncellenir*/}


      {qrId && ( 
        /*Eğer qrId varsa (boş değilse) bu alan gösterilir,yani şartlı render
*/
        <div style={{ marginTop: '20px' }}>
          <QRCodeOlustur makinaId={qrId} />
        </div>
      )}

    </div>
  );
};

export default MakineEkle;