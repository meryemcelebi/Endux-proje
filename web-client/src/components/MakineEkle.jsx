import React, { useState } from 'react'; /*useState:form verisini tutmak için*/
import QRCodeOlustur from './QRCodeOlustur';

const MakineEkle = ({ onEkle }) => { /*makine eklenince listeye gönder*/

  const [form, setForm] = useState({ /*verileri tutar*/
    makineid: '',
    firmaid: '',
    makineqr: '',
    makinead: '',
    satinAlmaTarihi: '',
    satinAlmaMaliyeti: '',
    toplamCalismaSaati: '',
    makineOzellikleri: '',
    mevcutRiskSkoru: '',
    mevcutRiskSeviyesi: '',
    aktiflikDurumu: '',
    geciciMakineTurAdi: '',
    geciciFirmaAdi: '',
    seriNo: '',
    geciciRiskKatsayisi: '',
    geciciTurAciklama: ''
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
      makineid: '',
      firmaid: '',
      makineqr: '',
      makinead: '',
      satinAlmaTarihi: '',
      satinAlmaMaliyeti: '',
      toplamCalismaSaati: '',
      makineOzellikleri: '',
      mevcutRiskSkoru: '',
      mevcutRiskSeviyesi: '',
      aktiflikDurumu: '',
      geciciMakineTurAdi: '',
      geciciFirmaAdi: '',
      seriNo: '',
      geciciRiskKatsayisi: '',
      geciciTurAciklama: ''
    });
  };

  return (
    <div>

      <h3>Makine Ekle</h3>

      <input name="makineid" placeholder="Makine ID" value={form.makineid} onChange={handleChange} /><br />
      <input name="firmaid" placeholder="Firma ID" value={form.firmaid} onChange={handleChange} /><br />
      <input name="makineqr" placeholder="Makine QR" value={form.makineqr} onChange={handleChange} /><br />
      <input name="makinead" placeholder="Makine Adı" value={form.makinead} onChange={handleChange} /><br />
      <input name="satinAlmaTarihi" placeholder="Satın Alma Tarihi" value={form.satinAlmaTarihi} onChange={handleChange} /><br />
      <input name="satinAlmaMaliyeti" placeholder="Satın Alma Maliyeti" value={form.satinAlmaMaliyeti} onChange={handleChange} /><br />
      <input name="toplamCalismaSaati" placeholder="Toplam Çalışma Saati" value={form.toplamCalismaSaati} onChange={handleChange} /><br />
      <input name="makineOzellikleri" placeholder="Makine Özellikleri" value={form.makineOzellikleri} onChange={handleChange} /><br />
      <input name="mevcutRiskSkoru" placeholder="Mevcut Risk Skoru" value={form.mevcutRiskSkoru} onChange={handleChange} /><br />
      <input name="mevcutRiskSeviyesi" placeholder="Mevcut Risk Seviyesi" value={form.mevcutRiskSeviyesi} onChange={handleChange} /><br />
      <input name="aktiflikDurumu" placeholder="Aktiflik Durumu" value={form.aktiflikDurumu} onChange={handleChange} /><br />
      <input name="geciciMakineTurAdi" placeholder="Geçici Makine Tür Adı" value={form.geciciMakineTurAdi} onChange={handleChange} /><br />
      <input name="geciciFirmaAdi" placeholder="Geçici Firma Adı" value={form.geciciFirmaAdi} onChange={handleChange} /><br />
      <input name="seriNo" placeholder="Seri No" value={form.seriNo} onChange={handleChange} /><br />
      <input name="geciciRiskKatsayisi" placeholder="Geçici Risk Katsayısı" value={form.geciciRiskKatsayisi} onChange={handleChange} /><br />
      <input name="geciciTurAciklama" placeholder="Geçici Tür Açıklama" value={form.geciciTurAciklama} onChange={handleChange} /><br />
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