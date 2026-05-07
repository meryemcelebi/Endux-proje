import os
import psycopg2
import pandas as pd
from dotenv import load_dotenv

# .env dosyasındaki değişkenleri (şifreleri) sisteme yükle
load_dotenv()

def verileri_getir(tablo_adi="gunluk_kontrol_formu"):
    """
    Supabase (PostgreSQL) veritabanına doğrudan bağlanıp, 
    istenen tablodaki verileri Pandas DataFrame olarak döndürür.
    Bu veri AI model eğitiminde kullanılacaktır.
    """
    try:
        print("[+] Veritabanına bağlanılıyor...")
        
        # .env dosyasındaki DATABASE_URL'yi kullanarak doğrudan PostgreSQL bağlantısı kurar
        conn = psycopg2.connect(os.getenv("DATABASE_URL"))
        
        # Veritabanına atacağımız SQL sorgusu
        sorgu = f"SELECT * FROM {tablo_adi};"
        
        # Sorguyu çalıştırıp doğrudan Pandas DataFrame'e aktarıyoruz (Veri Bilimi standardı)
        df = pd.read_sql_query(sorgu, conn)
        
        print(f"[BASARILI] '{tablo_adi}' tablosundan {len(df)} satır veri çekildi.")
        
        # İşimiz bitince bağlantıyı kapatıyoruz ki sunucuyu yormasın
        conn.close()
        
        return df

    except Exception as e:
        print(f"[HATA] Veritabanı bağlantı hatası: {e}")
        return None

# Eğer bu dosyayı doğrudan 'python database.py' diyerek çalıştırırsan test için ilk 5 satırı yazdırır
if __name__ == "__main__":
    veri = verileri_getir()
    if veri is not None and not veri.empty:
        print("\n[BILGI] Örnek Veriler (İlk 5 Satır):")
        print(veri.head())
