import prisma from './src/config/prisma';
import { hashSifre } from './src/utils/hash';

async function yoneticiEkle() {
    try {
        console.log('PostgreSQL bağlantısı kontrol ediliyor...');
        
        // 1. YONETICI rolü var mı kontrol et
        let rol = await prisma.rol.findFirst({ where: { rol_adi: 'YONETICI' } });
        if (!rol) {
            console.log('YONETICI rolü bulunamadı, oluşturuluyor...');
            rol = await prisma.rol.create({ data: { rol_adi: 'YONETICI' } });
        }

        // 2. Temsili bir firma var mı kontrol et, yoksa 1 id'li firma oluştur
        let firma = await prisma.firma.findUnique({ where: { firma_id: 1 } });
        if (!firma) {
             console.log('Sistemde şirket bulunamadı, "Merkez Yönetim" adında bir şirket oluşturuluyor...');
             firma = await prisma.firma.create({ 
                 data: { firma_adi: 'Merkez Yönetim' } 
             });
        }
        
        // 3. Kullanıcı adını belirle
        const yonKullaniciAdi = 'YON_admin';
        
        const mevcutKullanici = await prisma.kullanici.findUnique({ where: { kullanici_adi: yonKullaniciAdi } });
        if (mevcutKullanici) {
            console.log('Zaten "YON_admin" adında bir yönetici sistemde mevcut. Bilgiler:');
            console.log(mevcutKullanici);
            return;
        }

        console.log('Yönetici kullanıcısı oluşturuluyor...');
        const plainPassword = 'admin'; // Basit standart bir şifre
        const hashedSifre = await hashSifre(plainPassword);

        const yeniKullanici = await prisma.kullanici.create({
            data: {
                ad: 'Sistem',
                soyad: 'Yöneticisi',
                sifre: hashedSifre,
                rol_id: rol.rol_id,
                firma_id: firma.firma_id,
                telefon: '05550000000',
                kullanici_adi: yonKullaniciAdi,
                aktiflik: true
            }
        });

        console.log('✅ YÖNETİCİ BAŞARIYLA EKLENDİ!');
        console.log('--------------------------------------------------');
        console.log('Giriş Bilgileriniz:');
        console.log(`Kullanıcı Adı : ${yeniKullanici.kullanici_adi}`);
        console.log(`Şifre         : ${plainPassword}`);
        console.log('--------------------------------------------------');

    } catch (e) {
        console.error('❌ Yönetici eklenirken hata oluştu:', e);
    } finally {
        await prisma.$disconnect();
    }
}

yoneticiEkle();
