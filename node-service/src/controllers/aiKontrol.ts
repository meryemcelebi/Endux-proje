import { Request, Response } from "express";
import axios, { AxiosError } from "axios";
import prisma from "../config/prisma";
import { config } from "../config";

const AI_SERVICE_URL = config.aiServiceUrl;
const AI_TIMEOUT_MS  = 10_000; // 10 saniye timeout

//python api'ye gönderilecek payload

interface AITahminPayload {
    makine_id: number;
    form_id: number;
    makine_turu :string;
    tahmini_omur_saati: number;
    toplam_calisma_saati:number;
    sicaklik:number;
    titresim:number;
    makine_degeri:number;
}
//python APİ'den dönen yanıt 
interface IAiTahminYanit {
    makine_id: number;
    form_id: number;
    makine: string;
    ariza_riski: boolean;
    tahmini_durus_suresi_saat: number;
    tahmini_onarim_maliyeti_tl: number;
    mesaj: string;
}

//veri tabanı sorgusu
async function makineOZetVeriCek(makineID : number){
    const makine=await prisma.makine.findUnique({
        where: {makine_id: makineID},
        include: {
            makine_turu: true,
            makine_ozellikleri: true
        },
    });
    if(!makine){
        throw new Error (`Makine Bulunamadı: ID ${makineID}`);
    }
    return makine;
}