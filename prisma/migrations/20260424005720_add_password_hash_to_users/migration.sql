-- AlterTable
ALTER TABLE "paxi_card" ALTER COLUMN "qrToken" SET DEFAULT encode(gen_random_bytes(32), 'hex');

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "passwordHash" TEXT;
