import { Router } from "express";
import { servisPuanVer, tedarikciPuanVer} from "../controllers/puanKontrol";
import { oturumKontrol, rolKontrol } from "../middlewares/yetki";

const ServisPuanRouter = Router();
const TedarikciPuanRouter = Router();

ServisPuanRouter.post('/', oturumKontrol, rolKontrol('YONETICI', 'TEKNISYEN'), servisPuanVer);

TedarikciPuanRouter.post('/', oturumKontrol, rolKontrol('YONETICI', 'TEKNISYEN'), tedarikciPuanVer);

export { ServisPuanRouter, TedarikciPuanRouter };
