from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import logging

# --- BİZİM EKLENTİLERİMİZ ---
from pydantic import BaseModel, Field
import pandas as pd
import joblib

app = FastAPI(title="Endux AI Service", version="1.0.0")

# Setup CORS for development (Meryem'in Node.js Köprüsü - DOKUNMUYORUZ)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# --- 1. YAPAY ZEKA BEYİNLERİNİ YÜKLEME (BİZİM KOD) ---
print("Yapay Zeka Modelleri Yükleniyor...")
ariza_modeli = joblib.load('xgboost_ariza_modeli.pkl')
ariza_kolonlari = joblib.load('model_1_kolonlari.pkl')

modeller_reg = joblib.load('xgboost_regresyon_modelleri.pkl')
durus_modeli = modeller_reg['durus_modeli']
maliyet_modeli = modeller_reg['maliyet_modeli']
regresyon_kolonlari = joblib.load('model_2_kolonlari.pkl')
print("Modeller Başarıyla Yüklendi! ✅")

# --- 2. PYDANTIC GÜVENLİK ZIRHI (BİZİM KOD) ---
class MakineVerisi(BaseModel):
    makine_turu: str
    tahmini_omur_saati: int = Field(..., gt=0, description="Makinenin fabrika ömrü (Sıfırdan büyük olmalı)")
    toplam_calisma_saati: float = Field(..., ge=0, description="Mevcut çalışma saati (Eksi olamaz)")
    sicaklik: float = Field(..., ge=-20, le=200, description="Sıcaklık değeri -20 ile 200 derece arasında olmalıdır.")
    titresim: int = Field(..., ge=0, le=10, description="Titreşim şiddeti 0 ile 10 arasında olmalıdır.")
    makine_degeri: float = Field(..., gt=0)

# Meryem'in Sağlık Kontrolü (Health Check - DOKUNMUYORUZ)
@app.get("/health")
def read_health():
    logger.info("ping gonderildi")
    return {
        "status": "success",
        "service": "endux_ai_service",
        "message": "AI Service is up and running."
    }

# --- 3. BÜYÜK YAPAY ZEKA MOTORU (BİZİM KOD) ---
@app.post("/predict")
def make_prediction(veri: MakineVerisi):
    # Meryem'in log sistemini kullanarak konsola bilgi düşüyoruz
    logger.info(f"Yeni AI tahmini yapiliyor: {veri.makine_turu}") 
    
    # 1. Gelen Veriyi Tabloya Çevir
    girdi_df = pd.DataFrame([veri.model_dump()])
    
    # 2. Özellik Mühendisliği (Ömür yüzdesi hesaplama)
    girdi_df['omur_tuketim_yuzdesi'] = (girdi_df['toplam_calisma_saati'] / girdi_df['tahmini_omur_saati']) * 100
    girdi_df['omur_tuketim_yuzdesi'] = girdi_df['omur_tuketim_yuzdesi'].round(1)
    
    # 3. Yazıları Parçala (One-Hot)
    girdi_df = pd.get_dummies(girdi_df, columns=['makine_turu'])
    
    # 4. Veriyi Model 1 İskeletine Oturt ve TİPİ SABİTLE
    X_ariza = girdi_df.reindex(columns=ariza_kolonlari, fill_value=0).astype(float)
    
    # 5. BİRİNCİ BEYİN ÇALIŞIYOR (Arıza Tahmini)
    ariza_tahmini = int(ariza_modeli.predict(X_ariza)[0])
    
    # 6. İKİNCİ BEYİNLER ÇALIŞIYOR (Sadece Arıza Varsa)
    if ariza_tahmini == 1:
        X_regresyon = girdi_df.reindex(columns=regresyon_kolonlari, fill_value=0).astype(float)
        tahmini_durus = round(float(durus_modeli.predict(X_regresyon)[0]), 1)
        tahmini_maliyet = round(float(maliyet_modeli.predict(X_regresyon)[0]), 2)
        mesaj = "⚠️ DİKKAT! Makinede kritik arıza riski tespit edildi."
    else:
        tahmini_durus = 0.0
        tahmini_maliyet = 0.0
        mesaj = "✅ Makine sağlıklı çalışıyor."
        
    # 7. Sonucu Fırlat
    return {
        "makine": veri.makine_turu,
        "ariza_riski": bool(ariza_tahmini),
        "tahmini_durus_suresi_saat": tahmini_durus,
        "tahmini_onarim_maliyeti_tl": tahmini_maliyet,
        "mesaj": mesaj
    }