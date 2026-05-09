import os
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
        
        # Pandas 2.0+ ile DBAPI (psycopg2) bağlantısı kullanırken çıkan "UserWarning" 
        # (sarı uyarı) mesajını önlemek için SQLAlchemy motoru (engine) kullanıyoruz.
        from sqlalchemy import create_engine
        
        # .env dosyasındaki DATABASE_URL'yi kullanarak doğrudan PostgreSQL bağlantısı kurar
        db_url = os.getenv("DATABASE_URL")
        if not db_url:
            raise ValueError("DATABASE_URL .env dosyasında bulunamadı!")
            
        engine = create_engine(db_url)
        
        # Veritabanına atacağımız SQL sorgusu
        sorgu = f"SELECT * FROM {tablo_adi};"
        
        # Sorguyu çalıştırıp doğrudan Pandas DataFrame'e aktarıyoruz (Veri Bilimi standardı)
        df = pd.read_sql_query(sorgu, engine)
        
        print(f"[BASARILI] '{tablo_adi}' tablosundan {len(df)} satır veri çekildi.")
        
        # İşimiz bitince bağlantıyı kapatıyoruz ki sunucuyu yormasın (engine ile dispose yapılır)
        engine.dispose()
        
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
