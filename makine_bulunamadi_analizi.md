# Sistem Eksiklikleri ve "Makine Bulunamadı" Hatası Çözüm Raporu

Makine QR kodunu okutup yönetici girişi yaptığınızda ekranda "Makine bulunamadı." yazmasının ve 2./3. görsellerdeki detay sayfasının açılmamasının temel sebepleri ve sistemdeki eksiklikler aşağıda listelenmiştir.

## 1. API Rota (Endpoint) Uyuşmazlığı (Kritik Hata)
Detay sayfası (`MakineDetay.jsx`) yüklendiğinde, makinenin bilgilerini ve geçmişini getirmek için 3 farklı API isteğini aynı anda (`Promise.all` ile) başlatır.
* `getMachineDetails` (Makine detayları)
* `getChecklistHistory` (Kontrol geçmişi)
* **`getServiceHistory` (Servis/Bakım geçmişi) ❌**

Sistemdeki en büyük sorun `getServiceHistory` isteğindedir. 
* Frontend (`api.js`) servis geçmişini getirmek için **`/api/bakimlar/makine/:id`** adresine istek atar.
* Backend (`bakimRoutes.ts`) ise bu rotayı **`/api/bakimlar/:makine_id`** olarak tanımlamıştır.
Aradaki "makine" kelimesi fazlalığı nedeniyle backend **404 API Bulunamadı** hatası verir.

## 2. Frontend Hata Yönetimi Eksikliği (`MakineDetay.jsx`)
API rota uyuşmazlığının ekranı tamamen karartmasının nedeni `MakineDetay.jsx` içerisindeki `Promise.all` kullanımıdır.
```javascript
const [macData, histData, chData] = await Promise.all([
    api.getMachineDetails(id),
    api.getServiceHistory(id),
    api.getChecklistHistory(id)
]);
```
Bu yapıda, eğer servis geçmişi API'si (yukarıdaki hatadan dolayı) patlarsa, ana makine bilgileri (`macData`) başarılı şekilde çekilmiş olsa dahi ekrana yansıtılmaz ve direkt `catch` bloğuna düşer. Bu da ana makine verisinin `null` kalmasına ve ekranda **"Makine bulunamadı."** yazmasına neden olur. Servis geçmişi API'si hata verse bile makine bilgileri gösterilmelidir.

## 3. QR Kod Oluşturma Hataları (`Makineler.jsx`)
Sisteme yeni bir makine eklendiğinde veya API listesinde `makine_qr` alanı frontend'e doğru eşlenmediğinde, QR kod oluşturucu içerisine `undefined` değeri gitmektedir.
Kullanıcı bu QR'ı tarattığında tarayıcı URL'si şu şekli alır:
`http://localhost:5173/checklist-giris/undefined`

Yönetici giriş yaptıktan sonra sistem `undefined` ID'sini arar ve doğal olarak veritabanında bulamadığı için çöker. 

---

## Çözüm Önerileri (Yapılması Gerekenler)

1. **`api.js` Güncellemesi:**
   `getServiceHistory` içerisindeki istek URL'si şu şekilde düzeltilmelidir:
   `- const res = await fetch(\`\${API_BASE}/bakimlar/makine/\${makine_id}\`);`
   `+ const res = await fetch(\`\${API_BASE}/bakimlar/\${makine_id}\`);`

2. **`MakineDetay.jsx` Güncellemesi:**
   `Promise.all` yerine her isteği kendi `try-catch` bloğuna almak veya `Promise.allSettled` kullanarak bir verinin gelmemesinin tüm sayfayı çökertmesini engellemek gerekir.

3. **`Makineler.jsx` Güncellemesi:**
   Makine ID'si ve QR alanı bulunmayan nesneler için "QR bulunamadı" uyarısı çıkartılarak yanlış barkodların sisteme girmesi engellenmelidir.
