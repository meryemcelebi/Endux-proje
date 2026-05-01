import prisma from "../../config/prisma";

export async function getMakineListesiView() {
    return prisma.$queryRaw<any[]>`
        SELECT * FROM public.view_makineler
    `;
}
