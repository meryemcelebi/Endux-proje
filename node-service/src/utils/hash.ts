import bcryptjs from 'bcryptjs';

const sifre_tur_sayisi = 10; //sifre_tur_sayisi, bcryptjs'in hashleme işlemi sırasında kullanacağı tur sayısını belirtir.
export async function hashSifre(girilenSifre:string): Promise<string> {
    return bcryptjs.hash(girilenSifre, sifre_tur_sayisi);

}

//kullanıcının girdiği şifre ile veritabanında kayıtlı olan hashlenmiş şifreyi karşılaştırır
export async function sifreKarsilastir(girilenSifre:string, 
    veriTabaniSifresi:string
): Promise<boolean> {
    return bcryptjs.compare(girilenSifre, veriTabaniSifresi);
}


//not :burada hashSifre fonksiyonu, kullanıcının girdiği şifreyi hashleyerek güvenli bir şekilde saklamak için kullanılır.
//  sifreKarsilastir fonksiyonu ise kullanıcının girdiği şifre ile 
// veritabanında saklanan hashlenmiş şifreyi karşılaştırarak doğrulama yapar
// Bu sayede kullanıcıların şifreleri güvenli bir şekilde saklanır ve doğrulama işlemi gerçekleştirilir.


