from fastapi import FastAPI
from pydantic import BaseModel
from typing import Dict, Any
import pandas as pd
import xgboost as xgb
import pickle
import os

app = FastAPI()

# ==========================================
# 0. İKİ BEYNİ VE ÇEVİRMENİ HAFIZAYA YÜKLEME
# ==========================================
print("Yapay Zeka Modelleri (BEYİN-1 ve BEYİN-2) API'ye yükleniyor...")
klasor_yolu = os.path.dirname(os.path.abspath(__file__))

model_ariza_yolu = os.path.join(klasor_yolu, "beyin1_ariza_siniflandirici.json")
model_yuzde_yolu = os.path.join(klasor_yolu, "beyin2_yipranma_regresyonu.json")
encoder_yolu = os.path.join(klasor_yolu, "ariza_label_encoder.pkl")

# BEYİN 1: Arıza Tipi
beyin1_ariza = xgb.XGBClassifier()
beyin1_ariza.load_model(model_ariza_yolu)

# BEYİN 2: Yıpranma Yüzdesi (Regressor)
beyin2_yuzde = xgb.XGBRegressor()
beyin2_yuzde.load_model(model_yuzde_yolu)

# Çevirmen
with open(encoder_yolu, "rb") as f:
    ariza_cevirmen = pickle.load(f)

print("✅ İki beyin de aktif! Sistem Meryem'den gelecek verileri bekliyor...")

# ==========================================
# 1. PYDANTIC VERİ MODELLERİ (ŞEMALAR)
# ==========================================
class OtonomBakimTemel(BaseModel):
    sicaklik_durumu: str
    titresim_hissi: str
    yag_seviyesi: str
    genel_durum: str
    sizinti_durumu: str
    kablo_hasar_durumu: str

class AnaOtonomBakimIstegi(BaseModel):
    makine_turu: str          
    calisma_saati: int        
    genel_bakim_periyodu_saat: float 
    temel_veriler: OtonomBakimTemel
    ozel_veriler: Dict[str, Any] 

class AIArizaTespitSonucu(BaseModel):
    makine_turu: str
    tahmin_edilen_ariza: str           
    teorik_yipranma_yuzdesi: str       # Meryem'in aptal kronometresi
    ai_dinamik_yipranma_yuzdesi: str   # Senin yapay zekanın ±%0.94 sapmalı tahmini!
    tahmini_durus_suresi: float        
    tahmini_maliyet: float             
    planli_bakim_gecikmesi: bool

# ==========================================
# 2. STATİK SÖZLÜKLER VE FATURALAR
# ==========================================
MAPPING_SOZLUKLERI = {
    "sicaklik_durumu": {"Normal Değerde": 0, "Elle Dokunulmayacak Kadar Sıcak": 1, "Aşırı Isınma/Koku Var": 2},
    "titresim_hissi": {"Stabil/Sessiz Çalışıyor": 0, "Hafif Vuruntu/Titreşim Var": 1, "Anormal Ses/Sarsıntı Var": 2},
    "yag_seviyesi": {"Normal (Ortada)": 0, "Düşük (Alt Çizgide)": 1, "Kritik (Hiç Yağ Görünmüyor)": 2},
    "genel_durum": {"İyi": 0, "Orta (Aksaklık Var)": 1, "Kötü (Duruşa Gidebilir)": 2},
    "sizinti_durumu": {"Kuru ve Temiz": 0, "Hafif Terleme / Yağ İzi Var": 1, "Yere Damlayan Belirgin Sızıntı Var": 2},
    "kablo_hasar_durumu": {"Hasar Yok / Temiz": 0, "Hafif Aşınma / Sürtünme Var": 1, "Kopuk / Ezilmiş Kablo Var": 2}
}

OZEL_MAPPING_SOZLUKLERI = {
    "Plastik ve Enjeksiyon": {"hidrolik_yag_durumu": {"Seviye İyi/Normal": 0, "Eksilme Var (Çizgide)": 1, "Köpüklü/Kirli": 2}, "rezistans_kokusu": {"Koku Yok": 0, "Hafif Plastik Kokusu": 1, "Ağır Yanık Kokusu Var": 2}},
    "Talaşlı İmalat": {"bor_yag_rengi": {"Süt Beyazı/Normal": 0, "Koyu/Karamel Renk": 1, "Bakteri(Çürük) Kokusu Var": 2}, "spindle_titresim": {"Ses Normal": 0, "Hafif Titreşim Sesi": 1, "Vuruntu/Anormal Ses Var": 2}},
    "Yardımcı Tesis": {"alt_su_tahliye": {"Düzenli Atıyor": 0, "Sürekli Hava Kaçırıyor": 1, "Hiç Su Atmadı": 2}},
    "Kalite Kontrol": {"mercek_temizligi": {"Tozsuz/Temiz": 0, "Tozlanmış": 1, "Silinmesi Lazım": 2}},
    "Otomasyon ve Robotik": {"kaynak_torcu": {"Temiz": 0, "Hafif Çapaklı": 1, "Çok Yoğun Çapak/Temizlik Şart": 2}, "kablo_sarmali": {"Hasarsız": 0, "Sürtünüyor": 1, "Aşınmış/Yırtık Var": 2}},
    "Sac ve Şekillendirme": {"isik_bariyeri": {"Sorunsuz Kesti": 0, "Düzensiz Çalışıyor": 1, "Algılamıyor (Risk)": 2}, "sizma_kontrolu": {"Kuru": 0, "Hafif Terleme Var": 1, "Ayrık Yağ Sızıntısı Var": 2}},
    "Döküm ve Isıl İşlem": {"termal_gozlem": {"Kızarma Yok (Normal)": 0, "Hafif Renk Değişimi": 1, "Aşırı Kızarıklık (Riskli)": 2}, "sogutma_suyu": {"Gürül Gürül Akıyor": 0, "Düşük Debili": 1, "Akış Yok (Kritik)": 2}},
    "Paketleme ve Lojistik": {"teflon_kontrolu": {"Temiz/Kalıntısız": 0, "Yanık Plastik Yapışmış": 1, "Kesme Sorunu Yaratıyor": 2}, "fotosel_algilama": {"Temiz(Görüyor)": 0, "Tozlu (Silinmeli)": 1, "Kritik Tozlanma": 2}}
}

ARIZA_FATURA_SOZLUGU = {
    "HDF": {"maliyet": 15000.0, "durus_saati": 4.5},  
    "TWF": {"maliyet": 25000.0, "durus_saati": 8.0},  
    "OSF": {"maliyet": 5000.0,  "durus_saati": 2.0},  
    "PWF": {"maliyet": 35000.0, "durus_saati": 12.0}, 
    "RNF": {"maliyet": 10000.0, "durus_saati": 3.0},  
    "Yok": {"maliyet": 0.0,     "durus_saati": 0.0}   
}

# XGBoost'un beklediği o kusursuz 22 sütunluk sıra (Mock veri ile birebir aynı)
SUTUN_SIRASI = [
    "calisma_saati", "genel_bakim_periyodu_saat",
    "sicaklik_durumu", "titresim_hissi", "yag_seviyesi", "genel_durum", "sizinti_durumu", "kablo_hasar_durumu",
    "hidrolik_yag_durumu", "rezistans_kokusu", "bor_yag_rengi", "spindle_titresim",
    "alt_su_tahliye", "mercek_temizligi", "kaynak_torcu", "kablo_sarmali",
    "isik_bariyeri", "sizma_kontrolu", "termal_gozlem", "sogutma_suyu",
    "teflon_kontrolu", "fotosel_algilama"
]

# ==========================================
# 3. VERİ ÖN İŞLEME FONKSİYONU
# ==========================================
def verileri_modele_hazirla(istek: AnaOtonomBakimIstegi) -> pd.DataFrame:
    islenmis_veri = {sutun: 0 for sutun in SUTUN_SIRASI} # Tüm matrisi 0 (Normal) ile doldur
    
    islenmis_veri["calisma_saati"] = istek.calisma_saati
    islenmis_veri["genel_bakim_periyodu_saat"] = istek.genel_bakim_periyodu_saat
    
    # Temel sensörleri eşleştir
    temel_dict = istek.temel_veriler.model_dump()
    for alan, deger in temel_dict.items():
        islenmis_veri[alan] = MAPPING_SOZLUKLERI[alan].get(deger, 2)
                
    # Özel sensörleri eşleştir (Eğer makineye ait özel sensör geldiyse)
    makine_turu = istek.makine_turu
    if makine_turu in OZEL_MAPPING_SOZLUKLERI:
        secili_sozluk = OZEL_MAPPING_SOZLUKLERI[makine_turu] 
        for ozel_alan, ozel_deger in istek.ozel_veriler.items():
            if isinstance(ozel_deger, str) and ozel_alan in secili_sozluk:
                islenmis_veri[ozel_alan] = secili_sozluk[ozel_alan].get(ozel_deger, 2)
            elif isinstance(ozel_deger, (int, float)):
                islenmis_veri[ozel_alan] = ozel_deger
                
    # DataFrame'e çevir
    return pd.DataFrame([islenmis_veri], columns=SUTUN_SIRASI)

# ==========================================
# 4. ANA KARAR MOTORU (API ENDPOINT)
# ==========================================
@app.post("/predict", response_model=AIArizaTespitSonucu)
def predict_ariza(istek: AnaOtonomBakimIstegi):
    
    # 1. Ön İşleme: JSON'u O Devasa 22 Sütunluk Matrise Çevir
    df_model_girdisi = verileri_modele_hazirla(istek)

    # 2. BEYİN 1: Arıza Tipini Tahmin Et
    sayisal_tahmin = beyin1_ariza.predict(df_model_girdisi)
    gercek_ariza_tipi = ariza_cevirmen.inverse_transform(sayisal_tahmin)[0]

    # GÜVENLİK AĞI: Sensörlerin hepsi "Normal" ise boşuna arıza verme
    # İlk 2 sütun saat, sonrakiler sensör. Sensörlerin toplamı 0 ise sorun yoktur.
    if df_model_girdisi.iloc[0, 2:].sum() == 0: 
        gercek_ariza_tipi = "Yok"

    # 3. BEYİN 2: Gerçek Yıpranma Yüzdesini Tahmin Et! (İşte şov burada)
    ai_tahmini_yuzde = float(beyin2_yuzde.predict(df_model_girdisi)[0])
    
    if ai_tahmini_yuzde > 100.0: ai_tahmini_yuzde = 100.0
    if ai_tahmini_yuzde < 0.0: ai_tahmini_yuzde = 0.0

    # 4. Meryem'in Klasik Kronometresi
    teorik_yuzde = (istek.calisma_saati / istek.genel_bakim_periyodu_saat) * 100.0
    if teorik_yuzde > 100.0: teorik_yuzde = 100.0

    planli_bakim_gecikmesi = (istek.calisma_saati >= istek.genel_bakim_periyodu_saat)

    # 5. Faturayı Kes
    fatura_detayi = ARIZA_FATURA_SOZLUGU.get(gercek_ariza_tipi, ARIZA_FATURA_SOZLUGU["Yok"])
    
    return AIArizaTespitSonucu(
        makine_turu=istek.makine_turu,
        tahmin_edilen_ariza=gercek_ariza_tipi,
        teorik_yipranma_yuzdesi=f"%{round(teorik_yuzde, 1)}",
        ai_dinamik_yipranma_yuzdesi=f"%{round(ai_tahmini_yuzde, 1)}",
        tahmini_durus_suresi=fatura_detayi["durus_saati"],
        tahmini_maliyet=fatura_detayi["maliyet"],
        planli_bakim_gecikmesi=planli_bakim_gecikmesi
    )