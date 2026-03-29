# 📋 Endux Projesi — Takım Git & Docker Rehberi

> Bu rehber, projeye yeni başlayan veya repo'yu yeniden bağlayan tüm takım arkadaşları için hazırlanmıştır.

---

## 📌 BÖLÜM 1: Yeni Repo'ya Bağlanma

### Eğer eski repo hâlâ bilgisayarınızda klonlu ise

```bash
# 1. Eski projenin klasörüne gidin
cd <proje-klasörünüz>

# 2. Eski remote bağlantısını silin
git remote remove origin

# 3. Yeni repo'yu ekleyin (URL'yi kendi repo adresinize göre değiştirin)
git remote add origin https://github.com/meryemcelebi/bitirme-projesi-v2.git

# 4. Yeni repo'dan çekin
git fetch origin

# 5. Lokali yeni repo ile eşleyin
git checkout main
git reset --hard origin/main

# 6. Kontrol edin
git remote -v
git log --oneline -5
```

### Eğer sıfırdan başlıyorsanız (temiz klonlama)

```bash
git clone https://github.com/meryemcelebi/bitirme-projesi-v2.git
cd bitirme-projesi-v2
```

---

## 📌 BÖLÜM 2: Kendi Branch'inizi Açma ve Çalışma

Her takım üyesi kendi alanı için ayrı branch açmalıdır. **Asla doğrudan `main` branch'e push yapmayın!**

### 🖥️ Backend Ekibi (Node.js / Prisma)

```bash
# 1. main branch'in güncel olduğundan emin olun
git checkout main
git pull origin main

# 2. Backend branch'ini oluşturun
git checkout -b feature/backend

# 3. Çalışmanızı yapın (dosyaları düzenleyin, yeni dosyalar ekleyin)

# 4. Değişiklikleri stage'leyin
git add .

# 5. Commit atın (açıklayıcı mesaj yazın)
git commit -m "feat: kullanıcı giriş API endpoint'i eklendi"

# 6. Branch'inizi GitHub'a gönderin
git push -u origin feature/backend
```

### 🎨 Frontend Ekibi (React / Vite)

```bash
git checkout main
git pull origin main
git checkout -b feature/frontend

# ... çalışmanızı yapın ...

git add .
git commit -m "feat: login sayfası tasarımı tamamlandı"
git push -u origin feature/frontend
```

### 🤖 AI Ekibi (Python / FastAPI)

```bash
git checkout main
git pull origin main
git checkout -b feature/ai

# ... çalışmanızı yapın ...

git add .
git commit -m "feat: anomali tespit modeli entegre edildi"
git push -u origin feature/ai
```

### 📝 Commit Mesajı Kuralları

| Prefix | Ne Zaman Kullanılır | Örnek |
|--------|---------------------|-------|
| `feat:` | Yeni özellik | `feat: QR kod okuyucu eklendi` |
| `fix:` | Hata düzeltme | `fix: login hatası giderildi` |
| `docs:` | Dokümantasyon | `docs: API rehberi güncellendi` |
| `style:` | CSS/görsel değişiklik | `style: buton renkleri güncellendi` |
| `refactor:` | Kod düzenleme | `refactor: auth yapısı sadeleştirildi` |

---

## 📌 BÖLÜM 3: Branch'i main'e Birleştirme (Pull Request)

**⚠️ KESİNLİKLE `git push --force` KULLANMAYIN!**

### Yöntem 1: GitHub Üzerinden Pull Request (ÖNERİLEN ✅)

1. GitHub'a gidin → Repo sayfası
2. **"Compare & pull request"** butonuna tıklayın
3. Altta değişikliklerinizi gözden geçirin
4. **"Create pull request"** tıklayın
5. Takım lideriniz onayladıktan sonra **"Merge"** butonuna basın

### Yöntem 2: Komut Satırından (Dikkatli olun)

```bash
# 1. main'e geçin
git checkout main

# 2. main'i güncelleyin
git pull origin main

# 3. Kendi branch'inizi main'e birleştirin
git merge feature/backend

# 4. Eğer conflict yoksa push edin
git push origin main
```

---

## 📌 BÖLÜM 4: Merge Conflict Çözümü

### ⚡ Conflict Neden Olur?
İki kişi **aynı dosyanın aynı satırlarını** aynı anda değiştirdiğinde oluşur.

### 🛡️ Conflict'i ÖNLEME Yolları

1. **Her gün çalışmaya başlamadan önce:**
   ```bash
   git checkout main
   git pull origin main
   git checkout feature/sizin-branch
   git merge main
   ```
   Bu, main'deki güncel değişiklikleri kendi branch'inize alır.

2. **Aynı dosyayı aynı anda düzenlemeyin.** Dosya sahipliğini belirleyin.

3. **Sık sık commit atın.** Büyük değişiklikleri biriktirmeyin.

### 🔧 Conflict Oluştuğunda Çözüm

```bash
# 1. Pull veya merge yaptığınızda conflict çıkarsa:
git status
# → Conflictli dosyaları gösterir

# 2. Conflictli dosyaları açın, şöyle görünür:
```

Conflictli dosyada göreceğiniz yapı:
```
<<<<<<< HEAD
Sizin değişikliğiniz
=======
Diğer kişinin değişikliği
>>>>>>> feature/diger-branch
```

```bash
# 3. Dosyayı düzenleyin:
#    - <<<<<<< HEAD satırını silin
#    - ======= satırını silin
#    - >>>>>>> ... satırını silin
#    - Doğru olan kodu bırakın (ya da ikisini birleştirin)

# 4. Düzelttiğiniz dosyayı ekleyin
git add <conflict-cozulen-dosya>

# 5. Merge'i tamamlayın
git commit -m "fix: merge conflict çözüldü"

# 6. Push edin
git push origin feature/sizin-branch
```

### ❌ YAPMAYIN! Tehlikeli Komutlar

| Komut | Neden Tehlikeli |
|-------|-----------------|
| `git push --force` | Başkalarının commitlerini siler! |
| `git push -f` | `--force` ile aynı, aynı derecede tehlikeli |
| `git rebase main` (tecrübesiz ise) | Geçmişi değiştirir, force push gerektirir |
| `git reset --hard` (dikkatli olun) | Kaydedilmemiş değişiklikleri siler |

### ✅ YAPMANIZ GEREKEN Güvenli Alternatif

```bash
# Force push yerine merge kullanın:
git checkout main
git pull origin main
git checkout feature/sizin-branch
git merge main
# Conflict varsa çözün, sonra:
git push origin feature/sizin-branch
```

---

## 📌 BÖLÜM 5: .env Dosyası Kurulumu (Her Bilgisayarda Yapılmalı)

```bash
# .env.example dosyasını kopyalayın
cp .env.example .env
```

`.env` dosyası içeriğini doldurun:
```env
POSTGRES_USER=endux_admin
POSTGRES_PASSWORD=q1w2e3
POSTGRES_DB=endux_db
DATABASE_URL="postgresql://endux_admin:q1w2e3@localhost:5433/endux_db?schema=public"
PORT=3000
JWT_SECRET=endux_jwt
JWT_EXPIRES_IN=7d
```

> ⚠️ `.env` dosyası GitHub'a yüklenmez. Her bilgisayarda elle oluşturulmalıdır!

---

## 📌 BÖLÜM 6: Docker ile Projeyi Çalıştırma

### İlk Kurulum

```bash
# 1. .env dosyasını oluşturun (Bölüm 5'e bakın)

# 2. Docker Desktop'un açık olduğundan emin olun

# 3. Tüm servisleri başlatın (ilk seferde image'ları build eder)
docker compose up --build

# 4. Eğer daha önce build edilmişse ve sadece çalıştırmak istiyorsanız:
docker compose up
```

### Servisler ve Portları

| Servis | Port | Adres |
|--------|------|-------|
| PostgreSQL | 5433 | `localhost:5433` |
| Backend (Node.js) | 3000 | `http://localhost:3000` |
| Frontend (React) | 5173 | `http://localhost:5173` |
| AI Service (Python) | 8000 | `http://localhost:8000` |

### Sık Kullanılan Docker Komutları

```bash
# Tüm servisleri başlat
docker compose up

# Arka planda başlat
docker compose up -d

# Yeniden build et (kod değişikliği sonrası)
docker compose up --build

# Servisleri durdur
docker compose down

# Servisleri durdur + verileri sil (TEMİZ BAŞLANGIÇ) // (veri tabnını sıfırlar)
docker compose down -v

# Tek bir servisin loglarını gör
docker compose logs endux_backend
docker compose logs endux_frontend
docker compose logs endux_ai

# Container'a gir (hata ayıklama için)
docker exec -it endux_backend sh
```

### ⚠️ Sık Karşılaşılan Docker Sorunları ve Çözümleri

#### Sorun: "Benim bilgisayarımda çalışıyor, arkadaşımda çalışmıyor"

**Çözüm — Temiz başlangıç:**
```bash
# 1. Tüm container ve volume'ları temizle
docker compose down -v --rmi all

# 2. Docker cache'ini temizle
docker system prune -af

# 3. Yeniden build et
docker compose up --build
```

#### Sorun: "Kütüphane bulunamadı / Module not found"

**Çözüm:**
```bash
# Backend için:
docker compose down
docker compose up --build endux_backend

# Frontend için:
docker compose down
docker compose up --build endux_frontend

# AI için:
docker compose down
docker compose up --build endux_ai
```

#### Sorun: "Port zaten kullanımda"

```bash
# Hangi process portu kullanıyor bul (Windows):
netstat -ano | findstr :3000
netstat -ano | findstr :5173

# O process'i kapat:
taskkill /PID <PID_NUMARASI> /F
```

---

## 📌 HIZLI REFERANS: Günlük Çalışma Rutini

```bash
# 1. Sabah — güncelle
git checkout main
git pull origin main
git checkout feature/sizin-branch
git merge main

# 2. Çalış — kod yaz

# 3. Akşam — kaydet ve gönder
git add .
git commit -m "feat: açıklayıcı mesaj"
git push origin feature/sizin-branch

# 4. Hazır olunca — GitHub'da Pull Request aç
```
