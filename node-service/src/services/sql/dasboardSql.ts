import prisma from "../../config/prisma";

export async function getKritikUyarilar() {
    return prisma.$queryRaw<any[]>`
        SELECT * FROM public.view_dashboard_kritik_uyarilar
    `;
}
