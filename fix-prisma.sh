#!/bin/bash
# ============================================================
# PAXI — Fix Prisma 7
# Ejecutar desde la raíz del proyecto: sh fix_prisma.sh
# ============================================================

set -e
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'
log() { echo -e "${BLUE}▶ $1${NC}"; }
ok()  { echo -e "${GREEN}✓ $1${NC}"; }

# ============================================================
# 1. prisma/schema.prisma — sin url en datasource
# ============================================================
log "Actualizando prisma/schema.prisma..."
cat > prisma/schema.prisma << 'EOF'
// PAXI — Prisma Schema v7
// La URL de conexión se configura en prisma.config.ts (Prisma 7+)

generator client {
  provider        = "prisma-client-js"
  previewFeatures = ["postgresqlExtensions"]
}

datasource db {
  provider   = "postgresql"
  extensions = [pgcrypto, postgis]
}

// ── Enums ────────────────────────────────────────────────────

enum UserRole {
  driver
  passenger
  admin
}

enum KycStatus {
  pending
  in_review
  approved
  rejected
  suspended
}

enum FuelType {
  gasoline_93
  gasoline_95
  gasoline_97
  diesel
  electric
  hybrid
}

enum PlanType {
  daily
  weekly
  monthly_uf
}

enum SubStatus {
  pending_payment
  active
  grace_period
  expired
  cancelled
}

enum TripStatus {
  requested
  awaiting_offer
  offer_received
  accepted
  driver_en_route
  in_progress
  completed
  cancelled
}

enum OfferStatus {
  pending
  accepted
  rejected
  expired
}

enum PaymentMethod {
  cash
  webpay
  khipu
  paxi_wallet
}

enum PaymentStatus {
  pending
  authorized
  captured
  failed
  reversed
}

// ── Modelos ──────────────────────────────────────────────────

model User {
  id           String    @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  email        String    @unique
  phone        String?   @unique
  fullName     String
  rut          String?   @unique
  role         UserRole
  kycStatus    KycStatus @default(pending)
  avatarUrl    String?
  ratingAvg    Decimal   @default(5.00) @db.Decimal(3, 2)
  ratingCount  Int       @default(0)
  isActive     Boolean   @default(true)
  createdAt    DateTime  @default(now())
  updatedAt    DateTime  @updatedAt
  deletedAt    DateTime?

  vehicles         Vehicle[]
  paxiCard         PaxiCard?
  subscriptions    Subscription[]
  tripsAsDriver    Trip[]       @relation("DriverTrips")
  tripsAsPassenger Trip[]       @relation("PassengerTrips")
  offersAsDriver   PriceOffer[]
  ratingsGiven     Rating[]     @relation("RaterRatings")
  ratingsReceived  Rating[]     @relation("RatedRatings")

  @@map("users")
}

model Vehicle {
  id             String    @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  driverId       String    @db.Uuid
  plate          String    @unique
  brand          String
  model          String
  year           Int
  color          String
  fuelType       FuelType
  lPer100km      Decimal   @db.Decimal(5, 2)
  soatExpiry     DateTime? @db.Date
  revisionExpiry DateTime? @db.Date
  isActive       Boolean   @default(true)
  verifiedAt     DateTime?
  createdAt      DateTime  @default(now())

  driver User   @relation(fields: [driverId], references: [id])
  trips  Trip[]

  @@map("vehicles")
}

model PaxiCard {
  id               String    @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  driverId         String    @unique @db.Uuid
  handle           String    @unique
  qrToken          String    @unique @default(dbgenerated("encode(gen_random_bytes(32), 'hex')"))
  walletBalanceClp Int       @default(0)
  isActive         Boolean   @default(true)
  issuedAt         DateTime  @default(now())
  lastScannedAt    DateTime?

  driver           User              @relation(fields: [driverId], references: [id])
  fuelTransactions FuelTransaction[]

  @@map("paxi_card")
}

model Subscription {
  id               String    @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  driverId         String    @db.Uuid
  planType         PlanType
  status           SubStatus @default(pending_payment)
  amountUf         Decimal   @db.Decimal(6, 4)
  amountClp        Int
  ufValueAtCharge  Decimal   @db.Decimal(10, 2)
  validFrom        DateTime
  validUntil       DateTime
  isLaunchPromo    Boolean   @default(false)
  tbkInscriptionId String?
  autoRenew        Boolean   @default(true)
  cancelledAt      DateTime?
  createdAt        DateTime  @default(now())

  driver   User                  @relation(fields: [driverId], references: [id])
  payments SubscriptionPayment[]

  @@map("subscriptions")
}

model SubscriptionPayment {
  id             String        @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  subscriptionId String        @db.Uuid
  amountClp      Int
  status         PaymentStatus @default(pending)
  tbkOrderId     String?       @unique
  tbkAuthCode    String?
  failureReason  String?
  attemptNumber  Int           @default(1)
  paidAt         DateTime?
  createdAt      DateTime      @default(now())

  subscription Subscription @relation(fields: [subscriptionId], references: [id])

  @@map("subscription_payments")
}

model Trip {
  id              String     @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  driverId        String?    @db.Uuid
  passengerId     String     @db.Uuid
  vehicleId       String?    @db.Uuid
  acceptedOfferId String?    @unique @db.Uuid
  status          TripStatus @default(requested)
  originLng       Decimal    @db.Decimal(10, 7)
  originLat       Decimal    @db.Decimal(10, 7)
  destLng         Decimal    @db.Decimal(10, 7)
  destLat         Decimal    @db.Decimal(10, 7)
  originAddress   String
  destAddress     String
  distanceKm      Decimal?   @db.Decimal(8, 2)
  durationMin     Int?
  finalAmountClp  Int?
  cancelReason    String?
  requestedAt     DateTime   @default(now())
  acceptedAt      DateTime?
  startedAt       DateTime?
  completedAt     DateTime?
  cancelledAt     DateTime?

  driver        User?        @relation("DriverTrips",    fields: [driverId],        references: [id])
  passenger     User         @relation("PassengerTrips", fields: [passengerId],     references: [id])
  vehicle       Vehicle?     @relation(fields: [vehicleId],       references: [id])
  acceptedOffer PriceOffer?  @relation("AcceptedOffer",  fields: [acceptedOfferId], references: [id])
  offers        PriceOffer[] @relation("TripOffers")
  payment       TripPayment?
  ratings       Rating[]
  locations     TripLocation[]

  @@map("trips")
}

model PriceOffer {
  id                 String      @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tripId             String      @db.Uuid
  driverId           String      @db.Uuid
  proposedClp        Int
  fuelCostClp        Int         @default(0)
  distanceToOriginKm Decimal     @db.Decimal(6, 2)
  fuelPricePerL      Decimal     @db.Decimal(8, 2)
  status             OfferStatus @default(pending)
  expiresAt          DateTime
  respondedAt        DateTime?
  createdAt          DateTime    @default(now())

  trip           Trip  @relation("TripOffers",   fields: [tripId],    references: [id])
  driver         User  @relation(fields: [driverId],  references: [id])
  acceptedInTrip Trip? @relation("AcceptedOffer")

  @@map("price_offers")
}

model TripPayment {
  id           String        @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tripId       String        @unique @db.Uuid
  method       PaymentMethod
  amountClp    Int
  status       PaymentStatus @default(pending)
  tbkToken     String?
  tbkOrderId   String?
  tbkAuthCode  String?
  khipuId      String?
  authorizedAt DateTime?
  createdAt    DateTime      @default(now())

  trip Trip @relation(fields: [tripId], references: [id])

  @@map("trip_payments")
}

model Rating {
  id        String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tripId    String   @db.Uuid
  raterId   String   @db.Uuid
  ratedId   String   @db.Uuid
  raterRole UserRole
  score     Int
  tags      String[]
  comment   String?
  isVisible Boolean  @default(true)
  createdAt DateTime @default(now())

  trip  Trip @relation(fields: [tripId],  references: [id])
  rater User @relation("RaterRatings", fields: [raterId], references: [id])
  rated User @relation("RatedRatings", fields: [ratedId], references: [id])

  @@unique([tripId, raterId])
  @@map("ratings")
}

model TripLocation {
  id         BigInt   @id @default(autoincrement())
  tripId     String   @db.Uuid
  coordLng   Decimal  @db.Decimal(10, 7)
  coordLat   Decimal  @db.Decimal(10, 7)
  accuracyM  Decimal? @db.Decimal(6, 2)
  speedKmh   Decimal? @db.Decimal(5, 2)
  bearing    Decimal? @db.Decimal(5, 2)
  recordedAt DateTime

  trip Trip @relation(fields: [tripId], references: [id])

  @@index([tripId, recordedAt(sort: Desc)])
  @@map("trip_locations")
}

model FuelTransaction {
  id            String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  paxiCardId    String   @db.Uuid
  stationName   String
  stationBrand  String
  fuelType      FuelType
  liters        Decimal  @db.Decimal(6, 3)
  pricePerLiter Decimal  @db.Decimal(8, 2)
  amountClp     Int
  discountClp   Int      @default(0)
  createdAt     DateTime @default(now())

  paxiCard PaxiCard @relation(fields: [paxiCardId], references: [id])

  @@map("fuel_transactions")
}
EOF
ok "prisma/schema.prisma actualizado"

# ============================================================
# 2. prisma.config.ts — donde Prisma 7 lee la URL
# ============================================================
log "Creando prisma.config.ts..."
cat > prisma.config.ts << 'EOF'
import { defineConfig } from 'prisma/config'
import 'dotenv/config'

export default defineConfig({
  earlyAccess: true,
  schema: 'prisma/schema.prisma',
  migrate: {
    adapter: async () => {
      const { PrismaPg } = await import('@prisma/adapter-pg')
      const { default: pg } = await import('pg')

      const pool = new pg.Pool({
        connectionString: process.env.DATABASE_URL,
      })

      return new PrismaPg(pool)
    },
  },
})
EOF
ok "prisma.config.ts"

# ============================================================
# 3. Actualizar PrismaService para Prisma 7 con adapter
# ============================================================
log "Actualizando PrismaService para Prisma 7..."
cat > src/shared/database/prisma.service.ts << 'EOF'
import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import pg from 'pg'

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name)
  private pool: pg.Pool

  constructor() {
    const pool = new pg.Pool({
      connectionString: process.env.DATABASE_URL,
    })

    const adapter = new PrismaPg(pool)

    super({
      adapter,
      log: process.env.NODE_ENV === 'development'
        ? ['query', 'info', 'warn', 'error']
        : ['error'],
    })

    this.pool = pool
  }

  async onModuleInit() {
    await this.$connect()
    this.logger.log('✅ Conectado a PostgreSQL')
  }

  async onModuleDestroy() {
    await this.$disconnect()
    await this.pool.end()
    this.logger.log('PostgreSQL desconectado')
  }
}
EOF
ok "PrismaService actualizado"

# ============================================================
# 4. Instalar dependencias adicionales para Prisma 7
# ============================================================
log "Instalando dependencias de Prisma 7..."
npm install @prisma/adapter-pg pg dotenv
npm install -D @types/pg
ok "Dependencias instaladas"

# ============================================================
# 5. Generar cliente Prisma
# ============================================================
log "Generando cliente Prisma..."
npx prisma generate
ok "Prisma client generado"

# ============================================================
# Resumen
# ============================================================
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ Fix Prisma 7 completado             ${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo "Cambios aplicados:"
echo "  prisma/schema.prisma  → sin 'url' en datasource (Prisma 7)"
echo "  prisma.config.ts      → URL de conexión movida aquí"
echo "  prisma.service.ts     → usa PrismaPg adapter"
echo ""
echo "Próximo paso:"
echo "  npx prisma migrate dev --name init"
echo ""