"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.hashSifre = hashSifre;
exports.sifreKarsilastir = sifreKarsilastir;
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const sifre_tur_sayisi = 10; //sifre_tur_sayisi, bcryptjs'in hashleme işlemi sırasında kullanacağı tur sayısını belirtir.
async function hashSifre(girilenSifre) {
    return bcryptjs_1.default.hash(girilenSifre, sifre_tur_sayisi);
}
//kullanıcının girdiği şifre ile veritabanında kayıtlı olan hashlenmiş şifreyi karşılaştırır
async function sifreKarsilastir(girilenSifre, veriTabaniSifresi) {
    return bcryptjs_1.default.compare(girilenSifre, veriTabaniSifresi);
}
//not :burada hashSifre fonksiyonu, kullanıcının girdiği şifreyi hashleyerek güvenli bir şekilde saklamak için kullanılır.
//  sifreKarsilastir fonksiyonu ise kullanıcının girdiği şifre ile 
// veritabanında saklanan hashlenmiş şifreyi karşılaştırarak doğrulama yapar
// Bu sayede kullanıcıların şifreleri güvenli bir şekilde saklanır ve doğrulama işlemi gerçekleştirilir.
