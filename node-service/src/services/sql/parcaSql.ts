import prisma from "../../config/prisma";

export async function getParcaDetayListesi() {
    return prisma.$queryRaw<any[]>`
        SELECT * FROM public.v_parca_detay_listesi
    `;
}
