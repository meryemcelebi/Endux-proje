from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from typing import Optional, Dict
import pandas as pd
import xgboost as xgb
import pickle
import os
import uvicorn

app = FastAPI(title="Endux AI - Kestirimci Bakım API", version="4.0", description="Tüm Fabrika Yapay Zeka Merkezi")

# ==========================================
# 1. YAPAY ZEKA MODELLERİNİ YÜKLEME
# ==========================================
MODELS_DIR = "models"

# Model dosya adı → Veritabanındaki makine türü adı eşleştirmesi
MODEL_DOSYA_MAP = {
    "cnc": "CNC Makinesi",
    "pres": "Pres Makinesi",
    "enjeksiyon": "Plastik Enjeksiyon Makinesi"
}

modeller = {}
encoderlar = {}

print("[+] Yapay Zeka Beyinleri Yukleniyor...")
try:
    for dosya_adi, db_adi in MODEL_DOSYA_MAP.items():
        # Modeli Yükle
        model = xgb.XGBClassifier()
        model.load_model(os.path.join(MODELS_DIR, f"model_{dosya_adi}.json"))
        modeller[db_adi] = model
        
        # Sözlüğü Yükle
        with open(os.path.join(MODELS_DIR, f"encoder_{dosya_adi}.pkl"), "rb") as f:
            encoderlar[db_adi] = pickle.load(f)
    print("✅ Tüm Modeller Başarıyla Yüklendi!")
except Exception as e:
    print(f"❌ MODEL YÜKLEME HATASI: {e} (Önce eğitim kodunu çalıştırıp modelleri ürettiğinden emin ol!)")

# ==========================================
# 2. PYDANTIC ŞEMALARI (Swagger İçin)
# ==========================================

# --- GİRDİ ŞEMASI (Node.js'ten gelecek JSON) ---
class BakimIstegi(BaseModel):
    makine_turu: str = Field(..., example="CNC Makinesi", description="CNC Makinesi, Pres Makinesi veya Plastik Enjeksiyon Makinesi")
    form_doldurma_suresi_sn: int = Field(..., example=45, description="Operatörün formu doldurma süresi")
    
    # TPM ve Otonom Bakım Gözlemleri (Sensör yok, operatör beyanı var)
    toplam_calisma_saati: int = Field(0, description="Makinenin toplam çalışma saati")
    son_bakimdan_gecen_gun: int = Field(0, description="Son bakımdan bu yana geçen gün sayısı")
    genel_temizlik_puani: int = Field(3, description="1-5 arası otonom bakım temizlik puanı")
    
    # Tüm Parametreler (Gönderilmeyenler 0 kabul edilir)
    sicaklik: int = 0
    titresim: int = 0
    ses_anomalisi: int = 0
    yag_durumu: int = 0
    
    # CNC Özel
    is_mili_ses_ve_titresim: int = 0
    eksen_olcu_sapmasi: int = 0
    takim_zorlanma_durumu: int = 0
    islenen_yuzey_kalitesi: int = 0
    is_mili_govde_sicakligi: int = 0
    bor_yagi_ve_sogutma: int = 0
    pnomatik_hava_basinci: int = 0
    kizak_yag_seviyesi: int = 0
    
    # Pres Özel
    hidrolik_basinc_seviyesi: int = 0
    hidrolik_yag_sicakligi: int = 0
    yag_kacak_durumu: int = 0
    koc_vuruntu_sesi: int = 0
    koc_kilavuz_boslugu: int = 0
    kavrama_fren_hava_basinci: int = 0
    tonaj_sapmasi: int = 0
    basilan_parca_kalitesi: int = 0
    
    # Enjeksiyon Özel
    kovan_rezistans_sicakligi: int = 0
    eriyik_plastik_kokusu: int = 0
    vida_donus_sesi: int = 0
    enjeksiyon_baski_basinci: int = 0
    mengene_kapanma_basinci: int = 0
    kalip_sogutma_suyu_debisi: int = 0
    sogutma_suyu_sicakligi: int = 0
    eksik_baski_durumu: int = 0
    capakli_baski_durumu: int = 0

# --- ÇIKTI ŞEMASI (Node.js'e dönecek JSON) ---
class TahminSonucu(BaseModel):
    sistem_mesaji: str
    makine_turu: str
    guvenilirlik_notu: str
    tahmin_edilen_ariza: str
    risk_skoru: float = Field(..., description="0 ile 100 arası arıza riski")
    rul_tahmini_saat: float = Field(..., description="Tahmini Kalan Faydalı Ömür (saat)")
    bakim_tavsiyesi: str
    uyari_durumu: str
    detaylar: dict

# ==========================================
# 3. KURAL MOTORU (Uzman Sistem Çıktıları)
# ==========================================
KURAL_MOTORU = {
    "YOK": {"tahmini_maliyet": 0.00, "tahmini_durus_suresi": 0.00, "ekip": "Gerek Yok", "parca": "Sorun Yok"},
    # CNC
    "SPINDLE_RULMAN_ARIZASI": {"tahmini_maliyet": 12500.00, "tahmini_durus_suresi": 12.00, "ekip": "Mekanik Bakım", "parca": "İş Mili Rulmanı"},
    "EKSEN_MOTOR_ARIZASI": {"tahmini_maliyet": 25000.00, "tahmini_durus_suresi": 8.00, "ekip": "Elektrik/Otomasyon", "parca": "Eksen Sürücüsü"},
    "PNOMATIK_VALF_ARIZASI": {"tahmini_maliyet": 3500.00, "tahmini_durus_suresi": 2.00, "ekip": "Mekanik Bakım", "parca": "Hava Valfi Grubu"},
    "BOR_YAGI_POMPA_ARIZASI": {"tahmini_maliyet": 6000.00, "tahmini_durus_suresi": 4.00, "ekip": "Mekanik Bakım", "parca": "Soğutma Pompası"},
    # PRES
    "ANA_HIDROLIK_POMPA_ARIZASI": {"tahmini_maliyet": 45000.00, "tahmini_durus_suresi": 24.00, "ekip": "Hidrolik Ekibi", "parca": "Ana Pompa"},
    "HIDROLIK_YON_VALFI_ARIZASI": {"tahmini_maliyet": 8000.00, "tahmini_durus_suresi": 4.00, "ekip": "Hidrolik Ekibi", "parca": "Yön Valfi"},
    "MEKANIK_GOVDE_YORULMASI": {"tahmini_maliyet": 85000.00, "tahmini_durus_suresi": 48.00, "ekip": "Ağır Bakım Ekibi", "parca": "Gövde / Kılavuz"},
    # ENJEKSİYON
    "ISITICI_REZISTANS_ARIZASI": {"tahmini_maliyet": 5000.00, "tahmini_durus_suresi": 3.00, "ekip": "Elektrik Bakım", "parca": "Kovan Rezistansı"},
    "VIDA_KOVAN_ASINMASI": {"tahmini_maliyet": 65000.00, "tahmini_durus_suresi": 36.00, "ekip": "Mekanik Bakım", "parca": "Enjeksiyon Vidası"},
    "KALIP_SOGUTMA_VALFI_ARIZASI": {"tahmini_maliyet": 4500.00, "tahmini_durus_suresi": 2.00, "ekip": "Tesisat/Mekanik", "parca": "Soğutma Eşanjörü"}
}

# ==========================================
# 4. API ENDPOINT (Tahmin Merkezi)
# ==========================================
@app.post("/tahmin-et", response_model=TahminSonucu)
async def tahmin_yap(istek: BakimIstegi):
    try:
        makine = istek.makine_turu
        
        if makine not in modeller:
            raise HTTPException(status_code=400, detail=f"Geçersiz Makine Türü: '{makine}'. Geçerli türler: {', '.join(modeller.keys())}")

        # 1. 10 Saniye Kalkanı (Güvenilirlik Testi)
        guvenilirlik = "YÜKSEK - Veri Güvenilir"
        if istek.form_doldurma_suresi_sn < 10:
            guvenilirlik = "DÜŞÜK - Veri Şüpheli (Çok Hızlı Dolduruldu)"

        # 2. Makineye Özel Özellikleri Filtrele
        istek_dict = istek.dict()
        
        if makine == "CNC Makinesi":
            ozellikler = ["sicaklik", "titresim", "ses_anomalisi", "yag_durumu", "is_mili_ses_ve_titresim", "eksen_olcu_sapmasi", "takim_zorlanma_durumu", "islenen_yuzey_kalitesi", "is_mili_govde_sicakligi", "bor_yagi_ve_sogutma", "pnomatik_hava_basinci", "kizak_yag_seviyesi"]
        elif makine == "Pres Makinesi":
            ozellikler = ["sicaklik", "titresim", "ses_anomalisi", "yag_durumu", "hidrolik_basinc_seviyesi", "hidrolik_yag_sicakligi", "yag_kacak_durumu", "koc_vuruntu_sesi", "koc_kilavuz_boslugu", "kavrama_fren_hava_basinci", "tonaj_sapmasi", "basilan_parca_kalitesi"]
        elif makine == "Plastik Enjeksiyon Makinesi":
            ozellikler = ["sicaklik", "titresim", "ses_anomalisi", "yag_durumu", "kovan_rezistans_sicakligi", "eriyik_plastik_kokusu", "vida_donus_sesi", "enjeksiyon_baski_basinci", "mengene_kapanma_basinci", "kalip_sogutma_suyu_debisi", "sogutma_suyu_sicakligi", "eksik_baski_durumu", "capakli_baski_durumu"]

        veri_df = pd.DataFrame([{k: istek_dict[k] for k in ozellikler}])

        # 3. Yapay Zeka Tahmini ve Risk Skoru Hesaplama
        model = modeller[makine]
        encoder = encoderlar[makine]
        
        # Modelin tüm ihtimallerini (olasılıklarını) alıyoruz
        olasiliklar = model.predict_proba(veri_df)[0]
        tahmin_kodu = model.predict(veri_df)[0]
        ariza_ad = encoder.inverse_transform([tahmin_kodu])[0]

        # En yüksek ihtimali 100 üzerinden bir skora çeviriyoruz
        en_yuksek_olasilik = float(max(olasiliklar)) * 100

        if ariza_ad == "YOK":
            # Arıza YOK kararı çıktıysa, risk skoru "YOK" olma ihtimalinin tersidir.
            # Örn: Model %90 arıza YOK diyorsa, risk sadece %10'dur.
            risk_skoru = round((100 - en_yuksek_olasilik) / 100, 2)
        else:
            # Arıza VAR kararı çıktıysa, risk skoru doğrudan modelin o arızaya verdiği ihtimaldir.
            # Örn: Model %85 Rulman Arızası diyorsa, risk skoru 85'tir (Kırmızı).
            risk_skoru = round(en_yuksek_olasilik / 100, 2)

        # Kıyamet Senaryosu ve 10 Saniye Kalkanı
        if ariza_ad != "YOK" and istek.form_doldurma_suresi_sn < 10:
             uyari_rengi = "KIRMIZI-ŞÜPHELİ (Operatör formata uymadı ama kritik arıza var!)"
             risk_skoru = max(risk_skoru, 0.90) # Kesin acil müdahale
        else:
             uyari_rengi = "YEŞİL" if ariza_ad == "YOK" else "KIRMIZI"
             
        if ariza_ad == "YOK" and istek.form_doldurma_suresi_sn < 10:
             uyari_rengi = "SARI (Form çok hızlı dolduruldu, gidip teyit ediniz)"
             risk_skoru = max(risk_skoru, 0.50) # Arıza yok dese bile veri şüpheli olduğu için riski 0.50'ye çektik!

        # 4. RUL Tahmini (Tahmini Kalan Faydalı Ömür)
        # Basit RUL hesaplama: toplam_calisma_saati ve risk_skoru'na göre
        if istek.toplam_calisma_saati > 0:
            # Risk arttıkça kalan ömür düşer
            rul_tahmini = max(0, istek.toplam_calisma_saati * (1 - risk_skoru) * 0.5)
        else:
            rul_tahmini = 0.0

        # 5. Bakım Tavsiyesi Üret
        if risk_skoru >= 0.80:
            bakim_tavsiyesi = "ACİL BAKIM GEREKLİ! Makineyi durdurup derhal müdahale edin."
        elif risk_skoru >= 0.50:
            bakim_tavsiyesi = "Planlı bakımı öne çekin, arıza riski yüksek."
        elif risk_skoru >= 0.30:
            bakim_tavsiyesi = "Yakın takip yapın, bir sonraki planlı bakımda kontrol edin."
        else:
            bakim_tavsiyesi = "Makine sağlıklı, rutin bakım takvimini takip edin."

        # 6. Kural Motoru Çıktısı Ekle
        sonuc = KURAL_MOTORU.get(ariza_ad, KURAL_MOTORU["YOK"])

        risk_yuzde = round(risk_skoru * 100, 2)

        return TahminSonucu(
            sistem_mesaji="Tahmin Başarılı",
            makine_turu=makine,
            guvenilirlik_notu=guvenilirlik,
            tahmin_edilen_ariza=ariza_ad,
            risk_skoru=risk_yuzde,
            rul_tahmini_saat=round(rul_tahmini, 1),
            bakim_tavsiyesi=bakim_tavsiyesi,
            uyari_durumu=uyari_rengi,
            detaylar=sonuc
        )

    except HTTPException:
        raise  # HTTPException'ları olduğu gibi ilet
    except Exception as e:
        # Beklenmeyen hata durumunda backend'i bilgilendir
        raise HTTPException(status_code=500, detail=f"Model işleme hatası: {str(e)}")

# Eğer dosyayı doğrudan çalıştırırsan (test için)
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
