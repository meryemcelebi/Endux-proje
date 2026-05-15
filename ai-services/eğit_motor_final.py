import pandas as pd
import xgboost as xgb
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import accuracy_score
import pickle
import os

print("🚀 KB-V4: Ayrı Ayrı 3 Makine Modeli Eğitiliyor...\n")

DATA_DIR = "data"
MODELS_DIR = "models"

if not os.path.exists(MODELS_DIR):
    os.makedirs(MODELS_DIR)
    print(f"📁 '{MODELS_DIR}' klasörü oluşturuldu.")

# Eğitilecek makineler ve veri yolları
makineler = [
    {"tur": "CNC", "dosya": os.path.join(DATA_DIR, "kb_v4_cnc_egitim_verisi.csv")},
    {"tur": "PRES", "dosya": os.path.join(DATA_DIR, "kb_v4_pres_egitim_verisi.csv")},
    {"tur": "ENJEKSIYON", "dosya": os.path.join(DATA_DIR, "kb_v4_enjeksiyon_egitim_verisi.csv")}
]

for makine in makineler:
    dosya_adi = makine["dosya"]
    tur = makine["tur"]
    
    if not os.path.exists(dosya_adi):
        print(f"❌ HATA: '{dosya_adi}' bulunamadı. Veri üreticiyi çalıştırıp dosyayı data/ klasörüne attığına emin ol!")
        continue

    print(f"⚙️ {tur} verisi okunuyor...")
    # 1. Veriyi Oku
    df = pd.read_csv(dosya_adi)
    
    # 2. X (Özellikler) ve Y (Hedef) Ayırma
    # makine_turu, form_suresi ve HEDEF_ARIZA dışındaki TÜM kolonları X olarak al
    haric_tutulacaklar = ["makine_turu", "form_doldurma_suresi_sn", "HEDEF_ARIZA"]
    X = df.drop(columns=haric_tutulacaklar)
    
    # Encoder ile metinleri sayıya çevir
    encoder = LabelEncoder()
    y = encoder.fit_transform(df["HEDEF_ARIZA"])
    
    # %80 Eğitim, %20 Test
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    # 3. XGBoost Modelini Eğit
    model = xgb.XGBClassifier(objective='multi:softprob', eval_metric='mlogloss', n_estimators=100, seed=42)
    model.fit(X_train, y_train)
    
    # 4. Başarıyı Ölç
    basari = accuracy_score(y_test, model.predict(X_test))
    print(f"✅ {tur} Modeli Eğitildi! Test Başarısı: %{basari * 100:.2f}")
    
    # 5. Model ve Sözlükleri 'models' Klasörüne Kaydet
    model_yolu = os.path.join(MODELS_DIR, f"model_{tur.lower()}.json")
    encoder_yolu = os.path.join(MODELS_DIR, f"encoder_{tur.lower()}.pkl")
    
    model.save_model(model_yolu)
    
    with open(encoder_yolu, "wb") as f:
        pickle.dump(encoder, f)

print("\n🎯 TÜM EĞİTİMLER TAMAMLANDI! 3 Ayrı Beyin (JSON) ve Sözlük (PKL) 'models' Klasöründe Hazır.")