import pandas as pd
import xgboost as xgb
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import mean_absolute_error, accuracy_score
import pickle
import os

print("🧠 KB-V3: Çift Beyinli Yapay Zeka Eğitimi Başlıyor...\n")

# ==========================================
# 1. VERİYİ YÜKLEME (10.000 Satırlık Şaheser)
# ==========================================
klasor_yolu = os.path.dirname(os.path.abspath(__file__))
csv_dosyasi = os.path.join(klasor_yolu, "data", "kb_v2_egitim_verisi_v2.csv")

print("1. Veri seti okunuyor...")
df = pd.read_csv(csv_dosyasi)

# ==========================================
# 2. ÖZELLİKLER (X) VE HEDEFLER (y) AYRIMI
# ==========================================
# Yapay zekanın GİRDİ olarak bakacağı özellikler (Makine Türü ve Hedefler hariç hepsi matrisimizdir)
X = df.drop(columns=["makine_turu", "Hedef_Ariza_Tipi", "Hedef_Gercek_Yipranma"])

# 1. Hedef: Arıza Tipi (Metin olduğu için sayıya çevireceğiz)
y_ariza_text = df["Hedef_Ariza_Tipi"]
encoder = LabelEncoder()
y_ariza = encoder.fit_transform(y_ariza_text)

# 2. Hedef: Gerçek Yıpranma Yüzdesi (Zaten sayı olduğu için doğrudan alıyoruz)
y_yuzde = df["Hedef_Gercek_Yipranma"]

# Veriyi %80 Eğitim, %20 Sınav olarak bölüyoruz (Her iki hedef için de aynı bölünme)
X_train, X_test, y_ariza_train, y_ariza_test, y_yuzde_train, y_yuzde_test = train_test_split(
    X, y_ariza, y_yuzde, test_size=0.2, random_state=42
)

# ==========================================
# 3. BEYİN 1: ARIZA TİPİ SINIFLANDIRICI (Classifier)
# ==========================================
print("\n2. BEYİN-1 (Arıza Tipi Sınıflandırıcı) Eğitiliyor...")
model_ariza = xgb.XGBClassifier(
    objective='multi:softprob', 
    eval_metric='mlogloss',
    seed=42
)
model_ariza.fit(X_train, y_ariza_train)

# Beyin 1'i Test Et
ariza_basari = accuracy_score(y_ariza_test, model_ariza.predict(X_test))
print(f"✅ BEYİN-1 Doğruluk Oranı: %{ariza_basari * 100:.2f}")

# ==========================================
# 4. BEYİN 2: YIPRANMA YÜZDESİ TAHMİN EDİCİ (Regressor)
# ==========================================
print("\n3. BEYİN-2 (Gerçek Yıpranma Regresyonu) Eğitiliyor...")
# Dikkat: Regresyon (sayı tahmini) yapacağımız için XGBRegressor kullanıyoruz!
model_yuzde = xgb.XGBRegressor(
    objective='reg:squarederror', 
    eval_metric='rmse',
    seed=42
)
model_yuzde.fit(X_train, y_yuzde_train)

# Beyin 2'yi Test Et (MAE: Ortalama Mutlak Hata - Tahminler gerçek değerden ortalama ne kadar sapıyor?)
yuzde_hata_payi = mean_absolute_error(y_yuzde_test, model_yuzde.predict(X_test))
print(f"✅ BEYİN-2 Hata Payı: Ortalama ±%{yuzde_hata_payi:.2f} sapma ile kusursuz tahmin!")

# ==========================================
# 5. MODELLERİ API İÇİN KAYDETME
# ==========================================
print("\n4. Modeller ve Çevirmen Kaydediliyor...")

model_ariza_yolu = os.path.join(klasor_yolu, "beyin1_ariza_siniflandirici.json")
model_yuzde_yolu = os.path.join(klasor_yolu, "beyin2_yipranma_regresyonu.json")
encoder_yolu = os.path.join(klasor_yolu, "ariza_label_encoder.pkl")

# İki modeli de JSON olarak, çevirmeni ise PKL olarak kaydediyoruz
model_ariza.save_model(model_ariza_yolu)
model_yuzde.save_model(model_yuzde_yolu)

with open(encoder_yolu, "wb") as f:
    pickle.dump(encoder, f)

print("\n🚀 MUHTEŞEM! Her iki yapay zeka beyni de eğitildi ve API'ye bağlanmaya hazır.")