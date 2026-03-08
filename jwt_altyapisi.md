# Endux — JWT Yetkilendirme Altyapısı

## Genel Bakış

Sistemdeki kullanıcı hesapları **admin veya yönetici tarafından oluşturulur**.
Operatörler kendi hesaplarını açamaz. Şifre genellikle makine ID numarasıdır.

### Giriş Akışı
```
Operatör → kullanici_adi + sifre (örn: MK-001) →
  API doğrula → bcrypt karşılaştır → JWT Token üret → Frontend'e döner
```

### API Rotaları

| Method | Endpoint | Erişim | Açıklama |
|--------|----------|--------|----------|
| POST | `/api/auth/login` | Herkese açık | Giriş yap, token al |
| GET | `/api/auth/me` | Token gerekli | Kimim ben? |
| POST | `/api/kullanicilar` | Sadece admin/yönetici | Yeni hesap oluştur |

---

## 1. Ortam Değişkenleri — `.env`

```env
JWT_SECRET=endux_super_secret_key_2026
JWT_EXPIRES_IN=7d
PORT=3000
```

---

## 2. Konfigürasyon — `src/config/index.ts`

```typescript
import dotenv from "dotenv";
import path from "path";

dotenv.config({ path: path.resolve(__dirname, "../../../.env") });

export const config = {
  port: parseInt(process.env.PORT || "3000", 10),
  databaseUrl: process.env.DATABASE_URL || "",
  jwtSecret: process.env.JWT_SECRET || "fallback_secret_key",
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || "7d",
  nodeEnv: process.env.NODE_ENV || "development",
};
```

---

## 3. Veritabanı Modeli — `prisma/schema.prisma`

```prisma
model kullanici {
  id             Int      @id @default(autoincrement())
  kullanici_adi  String   @unique  // Giriş için kullanılacak (örn: op_ahmet)
  ad             String
  soyad          String
  email          String?  @unique  // Opsiyonel — admin ve yöneticiler için
  sifre_hash     String
  rol            String   @default("operator") // "admin" | "yonetici" | "operator" | "teknisyen"
  aktif          Boolean  @default(true)
  createdAt      DateTime @default(now())
  updatedAt      DateTime @updatedAt
}
```

---

## 4. JWT Yardımcıları — `src/utils/jwt.ts`

Token **üretmek** ve **doğrulamak** için kullanılır.

```typescript
import jwt, { JwtPayload, SignOptions } from "jsonwebtoken";
import type { StringValue } from "ms";
import { config } from "../config";

export interface TokenPayload extends JwtPayload {
  userId: number;
  email: string;
  rol: string;
}

// Token üretir (login ve register sonrası çağrılır)
export function generateToken(payload: {
  userId: number;
  email: string;
  rol: string;
}): string {
  const options: SignOptions = {
    expiresIn: config.jwtExpiresIn as StringValue,
  };
  return jwt.sign(payload, config.jwtSecret, options);
}

// Token'ı doğrular ve içindeki bilgileri döner
export function verifyToken(token: string): TokenPayload {
  return jwt.verify(token, config.jwtSecret) as TokenPayload;
}
```

---

## 5. Şifre Yardımcıları — `src/utils/hash.ts`

Şifreyi veritabanına **hash'leyerek** kaydeder, girişte **karşılaştırır**.

```typescript
import bcrypt from "bcryptjs";

const SALT_ROUNDS = 10;

// Düz şifreyi hash'ler — kayıt sırasında kullanılır
export async function hashPassword(plainPassword: string): Promise<string> {
  return bcrypt.hash(plainPassword, SALT_ROUNDS);
}

// Girilen şifre ile hash'i karşılaştırır — login sırasında kullanılır
export async function comparePassword(
  plainPassword: string,
  hashedPassword: string
): Promise<boolean> {
  return bcrypt.compare(plainPassword, hashedPassword);
}
```

---

## 6. Auth Middleware — `src/middlewares/auth.ts`

Tüm korunan rotaların önünde durur. Token yoksa veya sahte ise **401** döner.

```typescript
import { Request, Response, NextFunction } from "express";
import { verifyToken, TokenPayload } from "../utils/jwt";

// req.user tipini genişlet
declare global {
  namespace Express {
    interface Request {
      user?: TokenPayload;
    }
  }
}

// JWT doğrulama kapısı
export function authMiddleware(req: Request, res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    res.status(401).json({ success: false, message: "Erişim reddedildi. Token bulunamadı." });
    return;
  }

  const token = authHeader.split(" ")[1];

  try {
    const decoded = verifyToken(token);
    req.user = decoded; // Sonraki middleware/controller'lar req.user'a erişebilir
    next();
  } catch {
    res.status(401).json({ success: false, message: "Geçersiz veya süresi dolmuş token." });
  }
}

// Rol bazlı yetkilendirme — örn: authorizeRoles("admin", "yonetici")
export function authorizeRoles(...roles: string[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user || !roles.includes(req.user.rol)) {
      res.status(403).json({ success: false, message: "Bu işlem için yetkiniz bulunmamaktadır." });
      return;
    }
    next();
  };
}
```

---

## 7. Auth Controller — `src/controllers/authController.ts`

### 7a. Login — `POST /api/auth/login`

```typescript
export async function login(req, res, next): Promise<void> {
  const { kullanici_adi, sifre } = req.body;

  // 1. Kullanıcıyı kullanici_adi ile bul
  const kullanici = await prisma.kullanici.findUnique({ where: { kullanici_adi } });

  // 2. Bulunamadıysa → 401
  // 3. Aktif değilse → 403
  // 4. Şifre yanlışsa → 401 (comparePassword ile kontrol)

  // 5. JWT token üret ve döndür
  const token = generateToken({ userId: kullanici.id, email: kullanici.email ?? "", rol: kullanici.rol });

  res.status(200).json({ success: true, data: { ...kullanici }, token });
}
```

### 7b. Kullanıcı Oluştur (Admin) — `POST /api/kullanicilar`

```typescript
export async function createKullanici(req, res, next): Promise<void> {
  const { kullanici_adi, ad, soyad, sifre, rol, email } = req.body;

  // 1. kullanici_adi zaten varsa → 409 Conflict
  // 2. Şifreyi hash'le: hashPassword(sifre)  ← örn: "MK-001" → "$2a$10$..."
  // 3. Veritabanına kaydet
  // 4. Yeni kullanıcı bilgilerini döndür (token üretilmez)
}
```

### 7c. Ben Kimim — `GET /api/auth/me`

```typescript
export async function getMe(req, res, next): Promise<void> {
  // req.user.userId → authMiddleware tarafından eklendi
  const kullanici = await prisma.kullanici.findUnique({ where: { id: req.user!.userId } });
  res.status(200).json({ success: true, data: kullanici });
}
```

---

## 8. Rotalar — `src/routes/authRoutes.ts` & `src/routes/index.ts`

```typescript
// authRoutes.ts
router.post("/login", login);
router.get("/me", authMiddleware, getMe);

// routes/index.ts
router.use("/auth", authRoutes);
router.post("/kullanicilar", authMiddleware, authorizeRoles("admin", "yonetici"), createKullanici);
```

---

## Kurulu NPM Paketleri

| Paket | Görev |
|-------|-------|
| `jsonwebtoken` | JWT token üretme / doğrulama |
| `bcryptjs` | Şifre hash'leme / karşılaştırma |
| `@types/jsonwebtoken` | TypeScript tip tanımları |
| `@types/bcryptjs` | TypeScript tip tanımları |
