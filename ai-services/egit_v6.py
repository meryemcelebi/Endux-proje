import pandas as pd
import xgboost as xgb
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import accuracy_score, classification_report
import pickle
import os

print("🧠 KB-V6: Gelişmiş Olasılıksal Modeller Eğitiliyor...\n")

MODELS_DIR = "models"
if not os.path.exists(MODELS_DIR):
    os.makedirs(MODELS_DIR)

makineler = [
    {"tur": "CNC", "dosya": "kb_v6_cnc_egitim_verisi.csv"},
    {"tur": "PRES", "dosya": "kb_v6_pres_egitim_verisi.csv"},
    {"tur": "ENJEKSIYON", "dosya": "kb_v6_enjeksiyon_egitim_verisi.csv"}
]

for makine in makineler:
    dosya_adi = makine["dosya"]
    tur = makine["tur"]
    
    if not os.path.exists(dosya_adi):
        print(f"❌ HATA: '{dosya_adi}' bulunamadı.")
        continue

    print(f"📊 {tur} verisi okunuyor...")
    df = pd.read_csv(dosya_adi)
    
    # Hedef Değişken ve Özellikleri Ayır
    haric_tutulacaklar = ["makine_turu", "form_doldurma_suresi_sn", "HEDEF_ARIZA"]
    X = df.drop(columns=haric_tutulacaklar)
    
    encoder = LabelEncoder()
    y = encoder.fit_transform(df["HEDEF_ARIZA"])
    
    # %80 Eğitim, %20 Test
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    model = xgb.XGBClassifier(
        objective='multi:softprob', 
        eval_metric='mlogloss', 
        n_estimators=300,  
        max_depth=8,
        learning_rate=0.05,
        subsample=0.8,
        colsample_bytree=0.8,
        seed=42
    )
    model.fit(X_train, y_train)
    
    y_pred = model.predict(X_test)
    basari = accuracy_score(y_test, y_pred)
    print(f"🎯 {tur} Test Başarısı: %{basari * 100:.2f}\n")
    
    # Raporu bas
    print(classification_report(y_test, y_pred, target_names=encoder.classes_, zero_division=0))
    print("-" * 50)
    
    # Modeli Kaydet
    model_yolu = os.path.join(MODELS_DIR, f"model_{tur.lower()}.json")
    encoder_yolu = os.path.join(MODELS_DIR, f"encoder_{tur.lower()}.pkl")
    
    model.save_model(model_yolu)
    with open(encoder_yolu, "wb") as f:
        pickle.dump(encoder, f)

print("✅ BÜTÜN MODELLER V6 MİMARİSİYLE GÜNCELLENDİ!")
