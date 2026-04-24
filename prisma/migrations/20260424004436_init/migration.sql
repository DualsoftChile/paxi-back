-- CreateExtension
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- CreateExtension
CREATE EXTENSION IF NOT EXISTS "postgis";

-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('driver', 'passenger', 'admin');

-- CreateEnum
CREATE TYPE "KycStatus" AS ENUM ('pending', 'in_review', 'approved', 'rejected', 'suspended');

-- CreateEnum
CREATE TYPE "FuelType" AS ENUM ('gasoline_93', 'gasoline_95', 'gasoline_97', 'diesel', 'electric', 'hybrid');

-- CreateEnum
CREATE TYPE "PlanType" AS ENUM ('daily', 'weekly', 'monthly_uf');

-- CreateEnum
CREATE TYPE "SubStatus" AS ENUM ('pending_payment', 'active', 'grace_period', 'expired', 'cancelled');

-- CreateEnum
CREATE TYPE "TripStatus" AS ENUM ('requested', 'awaiting_offer', 'offer_received', 'accepted', 'driver_en_route', 'in_progress', 'completed', 'cancelled');

-- CreateEnum
CREATE TYPE "OfferStatus" AS ENUM ('pending', 'accepted', 'rejected', 'expired');

-- CreateEnum
CREATE TYPE "PaymentMethod" AS ENUM ('cash', 'webpay', 'khipu', 'paxi_wallet');

-- CreateEnum
CREATE TYPE "PaymentStatus" AS ENUM ('pending', 'authorized', 'captured', 'failed', 'reversed');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "email" TEXT NOT NULL,
    "phone" TEXT,
    "fullName" TEXT NOT NULL,
    "rut" TEXT,
    "role" "UserRole" NOT NULL,
    "kycStatus" "KycStatus" NOT NULL DEFAULT 'pending',
    "avatarUrl" TEXT,
    "ratingAvg" DECIMAL(3,2) NOT NULL DEFAULT 5.00,
    "ratingCount" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vehicles" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "driverId" UUID NOT NULL,
    "plate" TEXT NOT NULL,
    "brand" TEXT NOT NULL,
    "model" TEXT NOT NULL,
    "year" INTEGER NOT NULL,
    "color" TEXT NOT NULL,
    "fuelType" "FuelType" NOT NULL,
    "lPer100km" DECIMAL(5,2) NOT NULL,
    "soatExpiry" DATE,
    "revisionExpiry" DATE,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "verifiedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "vehicles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "paxi_card" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "driverId" UUID NOT NULL,
    "handle" TEXT NOT NULL,
    "qrToken" TEXT NOT NULL DEFAULT encode(gen_random_bytes(32), 'hex'),
    "walletBalanceClp" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "issuedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastScannedAt" TIMESTAMP(3),

    CONSTRAINT "paxi_card_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "subscriptions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "driverId" UUID NOT NULL,
    "planType" "PlanType" NOT NULL,
    "status" "SubStatus" NOT NULL DEFAULT 'pending_payment',
    "amountUf" DECIMAL(6,4) NOT NULL,
    "amountClp" INTEGER NOT NULL,
    "ufValueAtCharge" DECIMAL(10,2) NOT NULL,
    "validFrom" TIMESTAMP(3) NOT NULL,
    "validUntil" TIMESTAMP(3) NOT NULL,
    "isLaunchPromo" BOOLEAN NOT NULL DEFAULT false,
    "tbkInscriptionId" TEXT,
    "autoRenew" BOOLEAN NOT NULL DEFAULT true,
    "cancelledAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "subscriptions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "subscription_payments" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "subscriptionId" UUID NOT NULL,
    "amountClp" INTEGER NOT NULL,
    "status" "PaymentStatus" NOT NULL DEFAULT 'pending',
    "tbkOrderId" TEXT,
    "tbkAuthCode" TEXT,
    "failureReason" TEXT,
    "attemptNumber" INTEGER NOT NULL DEFAULT 1,
    "paidAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "subscription_payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "trips" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "driverId" UUID,
    "passengerId" UUID NOT NULL,
    "vehicleId" UUID,
    "acceptedOfferId" UUID,
    "status" "TripStatus" NOT NULL DEFAULT 'requested',
    "originLng" DECIMAL(10,7) NOT NULL,
    "originLat" DECIMAL(10,7) NOT NULL,
    "destLng" DECIMAL(10,7) NOT NULL,
    "destLat" DECIMAL(10,7) NOT NULL,
    "originAddress" TEXT NOT NULL,
    "destAddress" TEXT NOT NULL,
    "distanceKm" DECIMAL(8,2),
    "durationMin" INTEGER,
    "finalAmountClp" INTEGER,
    "cancelReason" TEXT,
    "requestedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "acceptedAt" TIMESTAMP(3),
    "startedAt" TIMESTAMP(3),
    "completedAt" TIMESTAMP(3),
    "cancelledAt" TIMESTAMP(3),

    CONSTRAINT "trips_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "price_offers" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tripId" UUID NOT NULL,
    "driverId" UUID NOT NULL,
    "proposedClp" INTEGER NOT NULL,
    "fuelCostClp" INTEGER NOT NULL DEFAULT 0,
    "distanceToOriginKm" DECIMAL(6,2) NOT NULL,
    "fuelPricePerL" DECIMAL(8,2) NOT NULL,
    "status" "OfferStatus" NOT NULL DEFAULT 'pending',
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "respondedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "price_offers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "trip_payments" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tripId" UUID NOT NULL,
    "method" "PaymentMethod" NOT NULL,
    "amountClp" INTEGER NOT NULL,
    "status" "PaymentStatus" NOT NULL DEFAULT 'pending',
    "tbkToken" TEXT,
    "tbkOrderId" TEXT,
    "tbkAuthCode" TEXT,
    "khipuId" TEXT,
    "authorizedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "trip_payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ratings" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "tripId" UUID NOT NULL,
    "raterId" UUID NOT NULL,
    "ratedId" UUID NOT NULL,
    "raterRole" "UserRole" NOT NULL,
    "score" INTEGER NOT NULL,
    "tags" TEXT[],
    "comment" TEXT,
    "isVisible" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ratings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "trip_locations" (
    "id" BIGSERIAL NOT NULL,
    "tripId" UUID NOT NULL,
    "coordLng" DECIMAL(10,7) NOT NULL,
    "coordLat" DECIMAL(10,7) NOT NULL,
    "accuracyM" DECIMAL(6,2),
    "speedKmh" DECIMAL(5,2),
    "bearing" DECIMAL(5,2),
    "recordedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "trip_locations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "fuel_transactions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "paxiCardId" UUID NOT NULL,
    "stationName" TEXT NOT NULL,
    "stationBrand" TEXT NOT NULL,
    "fuelType" "FuelType" NOT NULL,
    "liters" DECIMAL(6,3) NOT NULL,
    "pricePerLiter" DECIMAL(8,2) NOT NULL,
    "amountClp" INTEGER NOT NULL,
    "discountClp" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "fuel_transactions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "users_phone_key" ON "users"("phone");

-- CreateIndex
CREATE UNIQUE INDEX "users_rut_key" ON "users"("rut");

-- CreateIndex
CREATE UNIQUE INDEX "vehicles_plate_key" ON "vehicles"("plate");

-- CreateIndex
CREATE UNIQUE INDEX "paxi_card_driverId_key" ON "paxi_card"("driverId");

-- CreateIndex
CREATE UNIQUE INDEX "paxi_card_handle_key" ON "paxi_card"("handle");

-- CreateIndex
CREATE UNIQUE INDEX "paxi_card_qrToken_key" ON "paxi_card"("qrToken");

-- CreateIndex
CREATE UNIQUE INDEX "subscription_payments_tbkOrderId_key" ON "subscription_payments"("tbkOrderId");

-- CreateIndex
CREATE UNIQUE INDEX "trips_acceptedOfferId_key" ON "trips"("acceptedOfferId");

-- CreateIndex
CREATE UNIQUE INDEX "trip_payments_tripId_key" ON "trip_payments"("tripId");

-- CreateIndex
CREATE UNIQUE INDEX "ratings_tripId_raterId_key" ON "ratings"("tripId", "raterId");

-- CreateIndex
CREATE INDEX "trip_locations_tripId_recordedAt_idx" ON "trip_locations"("tripId", "recordedAt" DESC);

-- AddForeignKey
ALTER TABLE "vehicles" ADD CONSTRAINT "vehicles_driverId_fkey" FOREIGN KEY ("driverId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "paxi_card" ADD CONSTRAINT "paxi_card_driverId_fkey" FOREIGN KEY ("driverId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_driverId_fkey" FOREIGN KEY ("driverId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "subscription_payments" ADD CONSTRAINT "subscription_payments_subscriptionId_fkey" FOREIGN KEY ("subscriptionId") REFERENCES "subscriptions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trips" ADD CONSTRAINT "trips_driverId_fkey" FOREIGN KEY ("driverId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trips" ADD CONSTRAINT "trips_passengerId_fkey" FOREIGN KEY ("passengerId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trips" ADD CONSTRAINT "trips_vehicleId_fkey" FOREIGN KEY ("vehicleId") REFERENCES "vehicles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trips" ADD CONSTRAINT "trips_acceptedOfferId_fkey" FOREIGN KEY ("acceptedOfferId") REFERENCES "price_offers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "price_offers" ADD CONSTRAINT "price_offers_tripId_fkey" FOREIGN KEY ("tripId") REFERENCES "trips"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "price_offers" ADD CONSTRAINT "price_offers_driverId_fkey" FOREIGN KEY ("driverId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trip_payments" ADD CONSTRAINT "trip_payments_tripId_fkey" FOREIGN KEY ("tripId") REFERENCES "trips"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ratings" ADD CONSTRAINT "ratings_tripId_fkey" FOREIGN KEY ("tripId") REFERENCES "trips"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ratings" ADD CONSTRAINT "ratings_raterId_fkey" FOREIGN KEY ("raterId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ratings" ADD CONSTRAINT "ratings_ratedId_fkey" FOREIGN KEY ("ratedId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trip_locations" ADD CONSTRAINT "trip_locations_tripId_fkey" FOREIGN KEY ("tripId") REFERENCES "trips"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "fuel_transactions" ADD CONSTRAINT "fuel_transactions_paxiCardId_fkey" FOREIGN KEY ("paxiCardId") REFERENCES "paxi_card"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
