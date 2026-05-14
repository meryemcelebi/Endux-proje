ALTER TABLE "makine_turu"
ADD COLUMN IF NOT EXISTS "periyodik_bakim_saati" INTEGER,
ADD COLUMN IF NOT EXISTS "saatlik_durus_maliyeti" DOUBLE PRECISION DEFAULT 0;
