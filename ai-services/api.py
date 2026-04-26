from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from typing import Optional, Dict
import pandas as pd
import xgboost as xgb
import pickle
import os

app = FastAPI(title="KB-V4 Kestirimci Bakım API", version="4.0", description="Tüm Fabrika Yapay Zeka Merkezi")

# ==========================================
# 1. YAPAY ZEKA MODELLERİNİ YÜKLEME
# ==========================================
MODELS_DIR = "models"
makine_turleri = ["cnc", "pres", "enjeksiyon"]
modeller = {}
encoderlar = {}

print("⚙️ Yapay Zeka Beyinleri Yükleniyor...")
try:
    for tur in makine_turleri:
        # Modeli Yükle
        model = xgb.XGBClassifier()
        model.load_model(os.path.join(MODELS_DIR, f"model_{tur}.json"))
        modeller[tur.upper()] = model
        
        # Sözlüğü Yükle
        with open(os.path.join(MODELS_DIR, f"encoder_{tur}.pkl"), "rb") as f:
            encoderlar[tur.upper()] = pickle.load(f)
    print("✅ Tüm Modeller Başarıyla Yüklendi!")
except Exception as e:
    print(f"❌ MODEL YÜKLEME HATASI: {e} (Önce eğitim kodunu çalıştırıp modelleri ürettiğinden emin ol!)")

# ==========================================
# 2. PYDANTIC ŞEMALARI (Swagger İçin)
# ==========================================
class BakimIstegi(BaseModel):
    makine_turu: str = Field(..., example="CNC", description="CNC, PRES veya ENJEKSIYON")
    form_doldurma_suresi_sn: int = Field(..., example=45, description="Operatörün formu doldurma süresi")
    
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

# ==========================================
# 3. KURAL MOTORU (Uzman Sistem Çıktıları)
# ==========================================
KURAL_MOTORU = {
    "YOK": {"maliyet_tl": 0, "durus_saat": 0, "ekip": "Gerek Yok", "parca": "Sorun Yok"},
    # CNC
    "SPINDLE_RULMAN_ARIZASI": {"maliyet_tl": 12500, "durus_saat": 12, "ekip": "Mekanik Bakım", "parca": "İş Mili Rulmanı"},
    "EKSEN_MOTOR_ARIZASI": {"maliyet_tl": 25000, "durus_saat": 8, "ekip": "Elektrik/Otomasyon", "parca": "Eksen Sürücüsü"},
    "PNOMATIK_VALF_ARIZASI": {"maliyet_tl": 3500, "durus_saat": 2, "ekip": "Mekanik Bakım", "parca": "Hava Valfi Grubu"},
    "BOR_YAGI_POMPA_ARIZASI": {"maliyet_tl": 6000, "durus_saat": 4, "ekip": "Mekanik Bakım", "parca": "Soğutma Pompası"},
    # PRES
    "ANA_HIDROLIK_POMPA_ARIZASI": {"maliyet_tl": 45000, "durus_saat": 24, "ekip": "Hidrolik Ekibi", "parca": "Ana Pompa"},
    "HIDROLIK_YON_VALFI_ARIZASI": {"maliyet_tl": 8000, "durus_saat": 4, "ekip": "Hidrolik Ekibi", "parca": "Yön Valfi"},
    "MEKANIK_GOVDE_YORULMASI": {"maliyet_tl": 85000, "durus_saat": 48, "ekip": "Ağır Bakım Ekibi", "parca": "Gövde / Kılavuz"},
    # ENJEKSİYON
    "ISITICI_REZISTANS_ARIZASI": {"maliyet_tl": 5000, "durus_saat": 3, "ekip": "Elektrik Bakım", "parca": "Kovan Rezistansı"},
    "VIDA_KOVAN_ASINMASI": {"maliyet_tl": 65000, "durus_saat": 36, "ekip": "Mekanik Bakım", "parca": "Enjeksiyon Vidası"},
    "KALIP_SOGUTMA_VALFI_ARIZASI": {"maliyet_tl": 4500, "durus_saat": 2, "ekip": "Tesisat/Mekanik", "parca": "Soğutma Eşanjörü"}
}

# ==========================================
# 4. API ENDPOINT (Tahmin Merkezi)
# ==========================================
@app.post("/tahmin_et")
async def tahmin_yap(istek: BakimIstegi):
    makine = istek.makine_turu.upper()
    
    if makine not in modeller:
        raise HTTPException(status_code=400, detail="Geçersiz Makine Türü. Sadece CNC, PRES, ENJEKSIYON.")

    # 1. 10 Saniye Kalkanı (Güvenilirlik Testi)
    guvenilirlik = "YÜKSEK - Veri Güvenilir"
    if istek.form_doldurma_suresi_sn < 10:
        guvenilirlik = "DÜŞÜK - Veri Şüpheli (Çok Hızlı Dolduruldu)"

    # 2. Makineye Özel Özellikleri Filtrele
    istek_dict = istek.dict()
    
    if makine == "CNC":
        ozellikler = ["sicaklik", "titresim", "ses_anomalisi", "yag_durumu", "is_mili_ses_ve_titresim", "eksen_olcu_sapmasi", "takim_zorlanma_durumu", "islenen_yuzey_kalitesi", "is_mili_govde_sicakligi", "bor_yagi_ve_sogutma", "pnomatik_hava_basinci", "kizak_yag_seviyesi"]
    elif makine == "PRES":
        ozellikler = ["sicaklik", "titresim", "ses_anomalisi", "yag_durumu", "hidrolik_basinc_seviyesi", "hidrolik_yag_sicakligi", "yag_kacak_durumu", "koc_vuruntu_sesi", "koc_kilavuz_boslugu", "kavrama_fren_hava_basinci", "tonaj_sapmasi", "basilan_parca_kalitesi"]
    elif makine == "ENJEKSIYON":
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
        risk_skoru = round(100 - en_yuksek_olasilik)
    else:
        # Arıza VAR kararı çıktıysa, risk skoru doğrudan modelin o arızaya verdiği ihtimaldir.
        # Örn: Model %85 Rulman Arızası diyorsa, risk skoru 85'tir (Kırmızı).
        risk_skoru = round(en_yuksek_olasilik)

    # Kıyamet Senaryosu ve 10 Saniye Kalkanı
    if ariza_ad != "YOK" and istek.form_doldurma_suresi_sn < 10:
         uyari_rengi = "KIRMIZI-ŞÜPHELİ (Operatör formata uymadı ama kritik arıza var!)"
         risk_skoru = max(risk_skoru, 90) # Kesin acil müdahale
    else:
         uyari_rengi = "YEŞİL" if ariza_ad == "YOK" else "KIRMIZI"
         
    if ariza_ad == "YOK" and istek.form_doldurma_suresi_sn < 10:
         uyari_rengi = "SARI (Form çok hızlı dolduruldu, gidip teyit ediniz)"
         risk_skoru = max(risk_skoru, 50) # Arıza yok dese bile veri şüpheli olduğu için riski 50'ye çektik!

    # 4. Kural Motoru Çıktısı Ekle
    sonuc = KURAL_MOTORU.get(ariza_ad, KURAL_MOTORU["YOK"])

    return {
        "sistem_mesaji": "Tahmin Başarılı",
        "makine_turu": makine,
        "guvenilirlik_notu": guvenilirlik,
        "yapay_zeka_karari": ariza_ad,
        "risk_skoru": risk_skoru,  # <--- İŞTE MERYEM'İN İSTEDİĞİ 0-100 DEĞERİ BURADA!
        "uyari_durumu": uyari_rengi,
        "detaylar": sonuc
    }