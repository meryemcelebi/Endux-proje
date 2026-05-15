import pandas as pd
import xgboost as xgb
import numpy as np
from sklearn.preprocessing import LabelEncoder
import pickle
import os

print("🔄 KB-V4: Sürekli Eğitim (Retraining) ve Ağırlık Kaydırma Motoru Başlatılıyor...\n")

DATA_DIR = "data"
MODELS_DIR = "models"
YENI_VERI_DIR = "data/yeni_gercek_veriler"

# Eğer klasör yoksa oluştur
if not os.path.exists(YENI_VERI_DIR):
    os.makedirs(YENI_VERI_DIR)

# AĞIRLIK KAYDIRMA KATSAYISI
GERCEK_VERI_AGIRLIGI = 5.0  # Sentetik veriden 5 kat daha değerli!
SENTETIK_VERI_AGIRLIGI = 1.0

makineler = ["CNC", "PRES", "ENJEKSIYON"]

for tur in makineler:
    eski_dosya = os.path.join(DATA_DIR, f"kb_v4_{tur.lower()}_egitim_verisi.csv")
    yeni_dosya = os.path.join(YENI_VERI_DIR, f"gercek_saha_verisi_{tur.lower()}.csv")
    
    if not os.path.exists(yeni_dosya):
        print(f"⏳ {tur} için yeni saha verisi bulunamadı. Mevcut model korunuyor.")
        continue
        
    print(f"\n⚙️ {tur} MAKİNESİ İÇİN YENİDEN EĞİTİM BAŞLIYOR...")
    
    # 1. Verileri Oku
    df_eski = pd.read_csv(eski_dosya)
    df_yeni = pd.read_csv(yeni_dosya)
    
    print(f"   📊 Eski Sentetik Veri: {len(df_eski)} satır | Yeni Gerçek Veri: {len(df_yeni)} satır")

    # 2. Ağırlıkları (Weights) Belirle
    # Eski verilere 1, yeni verilere 5 çarpanı ver
    agirliklar_eski = np.full(len(df_eski), SENTETIK_VERI_AGIRLIGI)
    agirliklar_yeni = np.full(len(df_yeni), GERCEK_VERI_AGIRLIGI)
    
    # Verileri ve ağırlıkları birleştir
    df_toplam = pd.concat([df_eski, df_yeni], ignore_index=True)
    agirliklar_toplam = np.concatenate([agirliklar_eski, agirliklar_yeni])
    
    # 3. X ve Y Ayırımı
    haric_tutulacaklar = ["makine_turu", "form_doldurma_suresi_sn", "HEDEF_ARIZA"]
    X = df_toplam.drop(columns=haric_tutulacaklar)
    
    # Eski encoder'ı yükle ki arıza kodları (0,1,2..) birbirine karışmasın
    with open(os.path.join(MODELS_DIR, f"encoder_{tur.lower()}.pkl"), "rb") as f:
        encoder = pickle.load(f)
    y = encoder.transform(df_toplam["HEDEF_ARIZA"])
    
    # 4. Yeni Modeli Eğit
    # XGBoost, 'sample_weight' parametresini gördüğünde gerçek verilere 5 kat daha fazla odaklanır.
    model = xgb.XGBClassifier(objective='multi:softprob', eval_metric='mlogloss', n_estimators=100, seed=42)
    model.fit(X, y, sample_weight=agirliklar_toplam)
    
    # 5. Güncel Modeli Üzerine Yaz
    model_yolu = os.path.join(MODELS_DIR, f"model_{tur.lower()}.json")
    model.save_model(model_yolu)
    
    print(f"✅ {tur} Modeli Gerçek Saha Verileriyle Eğitildi ve Ağırlıkları Kaydırıldı!")

print("\n🎯 MLOps SÜREKLİ EĞİTİM DÖNGÜSÜ TAMAMLANDI.")