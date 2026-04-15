/**
 * Notlar ve Veri Yapısı Taslağı
 * Bu dosya geliştirme aşamasında kullanılan makine ekleme veri yapısı notlarını içermektedir.
 */
/*                     ########İSTENEN VERİLER##############

    makine_ad, 
    firma_id, 
    m_tur_id, 
    seri_no, 
    satin_alma_tarihi, 
    satin_alma_maliyeti, 
    aktiflik_durumu 

                                      ###GÖSTERİLEN VERİLER #####
makine_ad: makine_ad,
    firma_id:Number(firma_id),
    m_tur_id:Number(m_tur_id),
    seri_no:Array.isArray(seri_no) ? seri_no : [seri_no],
    satin_alma_tarihi: new Date(satin_alma_tarihi),
    satin_alma_maliyeti:Number(satin_alma_maliyeti),
    aktiflik_durumu:Boolean(aktiflik_durumu),
    makine_qr:uuidv4(),
    mevcut_risk_skoru: 0, // Başlangıç risk skoru (Zorunlu alan)
    top_cal_sma_saati: [],
    makine_ozellikleri: []
    }
});*/
