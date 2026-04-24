#!/bin/bash
# ============================================================
# PAXI — Scaffold completo del proyecto NestJS
# Ejecutar desde la raíz del proyecto: sh setup.sh
# ============================================================

set -e  # Detener si cualquier comando falla
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}▶ $1${NC}"; }
ok()  { echo -e "${GREEN}✓ $1${NC}"; }

# ============================================================
# main.ts — Configuración de producción
# ============================================================
log "Creando main.ts..."
cat > src/main.ts << 'EOF'
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Prefijo global de la API
  app.setGlobalPrefix('api/v1');

  // Validación automática de DTOs
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,       // elimina campos no declarados en el DTO
      forbidNonWhitelisted: true,
      transform: true,       // convierte tipos automáticamente (string → number, etc.)
    }),
  );

  // CORS — ajustar origins en producción
  app.enableCors({
    origin: process.env.ALLOWED_ORIGINS?.split(',') ?? '*',
    credentials: true,
  });

  const port = process.env.PORT ?? 3000;
  await app.listen(port);
  console.log(`🚕 PAXI API corriendo en puerto ${port}`);
}

bootstrap();
EOF
ok "main.ts"

# ============================================================
# app.module.ts — Módulo raíz
# ============================================================
log "Creando app.module.ts..."
cat > src/app.module.ts << 'EOF'
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

// Shared
import { DatabaseModule } from './shared/database/database.module';
import { RedisModule }    from './shared/redis/redis.module';
import { QueueModule }    from './shared/queue/queue.module';

// Módulos de dominio
import { AuthModule }          from './modules/auth/auth.module';
import { UsersModule }         from './modules/users/users.module';
import { VehiclesModule }      from './modules/vehicles/vehicles.module';
import { SubscriptionsModule } from './modules/subscriptions/subscriptions.module';
import { TripsModule }         from './modules/trips/trips.module';
import { PricingModule }       from './modules/pricing/pricing.module';
import { PaymentsModule }      from './modules/payments/payments.module';
import { RatingsModule }       from './modules/ratings/ratings.module';
import { PaxiCardModule }      from './modules/paxi-card/paxi-card.module';

@Module({
  imports: [
    // Variables de entorno disponibles en toda la app
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),

    // Infraestructura compartida
    DatabaseModule,
    RedisModule,
    QueueModule,

    // Dominios de negocio
    AuthModule,
    UsersModule,
    VehiclesModule,
    SubscriptionsModule,
    TripsModule,
    PricingModule,
    PaymentsModule,
    RatingsModule,
    PaxiCardModule,
  ],
})
export class AppModule {}
EOF
ok "app.module.ts"

# ============================================================
# SHARED — DatabaseModule (Prisma)
# ============================================================
log "Creando shared/database..."
cat > src/shared/database/database.module.ts << 'EOF'
import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Global()  // disponible en toda la app sin necesidad de importar en cada módulo
@Module({
  providers: [PrismaService],
  exports:   [PrismaService],
})
export class DatabaseModule {}
EOF

cat > src/shared/database/prisma.service.ts << 'EOF'
import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  constructor() {
    super({
      log: process.env.NODE_ENV === 'development'
        ? ['query', 'info', 'warn', 'error']
        : ['error'],
    });
  }

  async onModuleInit() {
    await this.$connect();
    this.logger.log('✅ Conectado a PostgreSQL');
  }

  async onModuleDestroy() {
    await this.$disconnect();
    this.logger.log('PostgreSQL desconectado');
  }
}
EOF
ok "shared/database"

# ============================================================
# SHARED — RedisModule
# ============================================================
log "Creando shared/redis..."
cat > src/shared/redis/redis.module.ts << 'EOF'
import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { RedisService } from './redis.service';
import { GeoService }   from './geo.service';

@Global()
@Module({
  providers: [RedisService, GeoService],
  exports:   [RedisService, GeoService],
})
export class RedisModule {}
EOF

cat > src/shared/redis/redis.service.ts << 'EOF'
import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private client: Redis;

  constructor(private config: ConfigService) {}

  onModuleInit() {
    this.client = new Redis(this.config.get<string>('REDIS_URL')!, {
      maxRetriesPerRequest: 3,
      lazyConnect: false,
    });

    this.client.on('connect', () => this.logger.log('✅ Conectado a Redis'));
    this.client.on('error',   (err) => this.logger.error('Redis error', err));
  }

  async onModuleDestroy() {
    await this.client.quit();
  }

  // ── Cache básico ────────────────────────────────────────────
  async get(key: string): Promise<string | null> {
    return this.client.get(key);
  }

  async set(key: string, value: string, ttlSeconds?: number): Promise<void> {
    if (ttlSeconds) {
      await this.client.set(key, value, 'EX', ttlSeconds);
    } else {
      await this.client.set(key, value);
    }
  }

  async del(key: string): Promise<void> {
    await this.client.del(key);
  }

  async exists(key: string): Promise<boolean> {
    return (await this.client.exists(key)) === 1;
  }

  // ── Acceso al cliente raw para operaciones avanzadas ────────
  getClient(): Redis {
    return this.client;
  }
}
EOF

cat > src/shared/redis/geo.service.ts << 'EOF'
import { Injectable } from '@nestjs/common';
import { RedisService } from './redis.service';

const DRIVERS_GEO_KEY = 'drivers:locations';
const DRIVER_STATUS_TTL = 35; // segundos — heartbeat cada 30s

export interface DriverLocation {
  driverId: string;
  latitude: number;
  longitude: number;
  distanceKm?: number;
}

@Injectable()
export class GeoService {
  constructor(private redis: RedisService) {}

  // Publicar o actualizar posición del conductor
  async updateDriverLocation(
    driverId: string,
    longitude: number,
    latitude: number,
  ): Promise<void> {
    const client = this.redis.getClient();

    // Actualizar posición en el GeoSet
    await client.geoadd(DRIVERS_GEO_KEY, longitude, latitude, driverId);

    // Renovar heartbeat — si no se renueva en 35s, el conductor desaparece
    await this.redis.set(`driver:status:${driverId}`, 'available', DRIVER_STATUS_TTL);
  }

  // Buscar conductores en radio (km) desde un punto
  async findDriversNearby(
    longitude: number,
    latitude: number,
    radiusKm: number = 3,
    limit: number = 10,
  ): Promise<DriverLocation[]> {
    const client = this.redis.getClient();

    const results = await client.georadius(
      DRIVERS_GEO_KEY,
      longitude,
      latitude,
      radiusKm,
      'km',
      'ASC',
      'COUNT', limit,
      'WITHCOORD',
      'WITHDIST',
    ) as any[];

    return results.map(([driverId, distanceKm, [lon, lat]]) => ({
      driverId,
      latitude: parseFloat(lat),
      longitude: parseFloat(lon),
      distanceKm: parseFloat(distanceKm),
    }));
  }

  // Eliminar conductor del mapa (desconexión)
  async removeDriver(driverId: string): Promise<void> {
    const client = this.redis.getClient();
    await client.zrem(DRIVERS_GEO_KEY, driverId);
    await this.redis.del(`driver:status:${driverId}`);
  }
}
EOF
ok "shared/redis"

# ============================================================
# SHARED — QueueModule (BullMQ)
# ============================================================
log "Creando shared/queue..."
cat > src/shared/queue/queue.module.ts << 'EOF'
import { BullModule } from '@nestjs/bull';
import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

// Nombres de las queues — exportar para usar en otros módulos
export const QUEUE_NOTIFICATIONS  = 'notifications';
export const QUEUE_SUBSCRIPTIONS  = 'subscriptions';
export const QUEUE_UF_REFRESH     = 'uf-refresh';
export const QUEUE_FUEL_REFRESH   = 'fuel-refresh';

@Module({
  imports: [
    BullModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        redis: config.get<string>('REDIS_URL'),
        defaultJobOptions: {
          removeOnComplete: 100,  // mantener los últimos 100 jobs completados
          removeOnFail: 200,      // mantener los últimos 200 jobs fallidos para debug
        },
      }),
    }),

    BullModule.registerQueue(
      { name: QUEUE_NOTIFICATIONS },
      { name: QUEUE_SUBSCRIPTIONS },
      { name: QUEUE_UF_REFRESH },
      { name: QUEUE_FUEL_REFRESH },
    ),
  ],
  exports: [BullModule],
})
export class QueueModule {}
EOF
ok "shared/queue"

# ============================================================
# SHARED — UF Service (Mindicador API)
# ============================================================
log "Creando shared/uf..."
cat > src/shared/uf/uf.service.ts << 'EOF'
import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { RedisService } from '../redis/redis.service';
import { firstValueFrom } from 'rxjs';

const UF_CACHE_KEY = 'uf:current_value';
const UF_TTL       = 60 * 60 * 24; // 24 horas

@Injectable()
export class UfService {
  private readonly logger = new Logger(UfService.name);

  constructor(
    private http: HttpService,
    private redis: RedisService,
  ) {}

  async getCurrentValue(): Promise<number> {
    // Intentar desde caché primero
    const cached = await this.redis.get(UF_CACHE_KEY);
    if (cached) return parseFloat(cached);

    // Si no hay caché, consultar Mindicador API
    return this.refresh();
  }

  async refresh(): Promise<number> {
    try {
      const { data } = await firstValueFrom(
        this.http.get('https://mindicador.cl/api/uf'),
      );

      const value: number = data.serie[0].valor;
      await this.redis.set(UF_CACHE_KEY, value.toString(), UF_TTL);

      this.logger.log(`UF actualizada: $${value.toLocaleString('es-CL')}`);
      return value;
    } catch (err) {
      this.logger.error('Error al obtener UF desde Mindicador', err);
      throw err;
    }
  }

  // Convierte monto UF a CLP usando el valor actual
  async toCLP(amountUF: number): Promise<number> {
    const ufValue = await this.getCurrentValue();
    return Math.round(amountUF * ufValue);
  }
}
EOF
ok "shared/uf"

# ============================================================
# MÓDULOS DE DOMINIO — Stubs listos para implementar
# Cada módulo tiene su module, controller y service base
# ============================================================
log "Creando módulos de dominio..."

create_module() {
    local NAME=$1       # ej: auth
    local CLASS=$2      # ej: Auth
    local DIR="src/modules/$NAME"
    
  cat > "$DIR/${NAME}.module.ts" << EOF
import { Module } from '@nestjs/common';
import { ${CLASS}Controller } from './${NAME}.controller';
import { ${CLASS}Service }    from './${NAME}.service';

@Module({
  controllers: [${CLASS}Controller],
  providers:   [${CLASS}Service],
  exports:     [${CLASS}Service],
})
export class ${CLASS}Module {}
EOF
    
  cat > "$DIR/${NAME}.controller.ts" << EOF
import { Controller } from '@nestjs/common';
import { ${CLASS}Service } from './${NAME}.service';

@Controller('${NAME}')
export class ${CLASS}Controller {
  constructor(private readonly ${NAME}Service: ${CLASS}Service) {}
}
EOF
    
  cat > "$DIR/${NAME}.service.ts" << EOF
import { Injectable } from '@nestjs/common';

@Injectable()
export class ${CLASS}Service {}
EOF
}

create_module "auth"          "Auth"
create_module "users"         "Users"
create_module "vehicles"      "Vehicles"
create_module "subscriptions" "Subscriptions"
create_module "trips"         "Trips"
create_module "pricing"       "Pricing"
create_module "payments"      "Payments"
create_module "ratings"       "Ratings"
create_module "paxi-card"     "PaxiCard"

ok "Módulos de dominio"

# ============================================================
# Prisma schema
# ============================================================
log "Creando prisma/schema.prisma..."
cat > prisma/schema.prisma << 'EOF'
// PAXI — Prisma Schema
// Documentación: https://pris.ly/d/prisma-schema

generator client {
  provider        = "prisma-client-js"
  previewFeatures = ["postgresqlExtensions"]
}

datasource db {
  provider   = "postgresql"
  url        = env("DATABASE_URL")
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

  // Relaciones
  vehicles              Vehicle[]
  paxiCard              PaxiCard?
  subscriptions         Subscription[]
  tripsAsDriver         Trip[]           @relation("DriverTrips")
  tripsAsPassenger      Trip[]           @relation("PassengerTrips")
  offersAsDriver        PriceOffer[]
  ratingsGiven          Rating[]         @relation("RaterRatings")
  ratingsReceived       Rating[]         @relation("RatedRatings")

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

  driver  User   @relation(fields: [driverId], references: [id])
  trips   Trip[]

  @@map("vehicles")
}

model PaxiCard {
  id                String    @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  driverId          String    @unique @db.Uuid
  handle            String    @unique
  qrToken           String    @unique @default(dbgenerated("encode(gen_random_bytes(32), 'hex')"))
  walletBalanceClp  Int       @default(0)
  isActive          Boolean   @default(true)
  issuedAt          DateTime  @default(now())
  lastScannedAt     DateTime?

  driver           User               @relation(fields: [driverId], references: [id])
  fuelTransactions FuelTransaction[]

  @@map("paxi_card")
}

model Subscription {
  id                String    @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  driverId          String    @db.Uuid
  planType          PlanType
  status            SubStatus @default(pending_payment)
  amountUf          Decimal   @db.Decimal(6, 4)
  amountClp         Int
  ufValueAtCharge   Decimal   @db.Decimal(10, 2)
  validFrom         DateTime
  validUntil        DateTime
  isLaunchPromo     Boolean   @default(false)
  tbkInscriptionId  String?
  autoRenew         Boolean   @default(true)
  cancelledAt       DateTime?
  createdAt         DateTime  @default(now())

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
  id               String     @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  driverId         String?    @db.Uuid
  passengerId      String     @db.Uuid
  vehicleId        String?    @db.Uuid
  acceptedOfferId  String?    @unique @db.Uuid
  status           TripStatus @default(requested)
  // Geometría almacenada como texto WKT — PostGIS la interpreta
  originLng        Decimal    @db.Decimal(10, 7)
  originLat        Decimal    @db.Decimal(10, 7)
  destLng          Decimal    @db.Decimal(10, 7)
  destLat          Decimal    @db.Decimal(10, 7)
  originAddress    String
  destAddress      String
  distanceKm       Decimal?   @db.Decimal(8, 2)
  durationMin      Int?
  finalAmountClp   Int?
  cancelReason     String?
  requestedAt      DateTime   @default(now())
  acceptedAt       DateTime?
  startedAt        DateTime?
  completedAt      DateTime?
  cancelledAt      DateTime?

  driver          User?        @relation("DriverTrips",    fields: [driverId],   references: [id])
  passenger       User         @relation("PassengerTrips", fields: [passengerId], references: [id])
  vehicle         Vehicle?     @relation(fields: [vehicleId],  references: [id])
  acceptedOffer   PriceOffer?  @relation("AcceptedOffer",  fields: [acceptedOfferId], references: [id])
  offers          PriceOffer[] @relation("TripOffers")
  payment         TripPayment?
  ratings         Rating[]
  locations       TripLocation[]

  @@map("trips")
}

model PriceOffer {
  id                   String      @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tripId               String      @db.Uuid
  driverId             String      @db.Uuid
  proposedClp          Int
  fuelCostClp          Int         @default(0)
  distanceToOriginKm   Decimal     @db.Decimal(6, 2)
  fuelPricePerL        Decimal     @db.Decimal(8, 2)
  status               OfferStatus @default(pending)
  expiresAt            DateTime
  respondedAt          DateTime?
  createdAt            DateTime    @default(now())

  trip           Trip  @relation("TripOffers",   fields: [tripId],    references: [id])
  driver         User  @relation(fields: [driverId],  references: [id])
  acceptedInTrip Trip? @relation("AcceptedOffer")

  @@map("price_offers")
}

model TripPayment {
  id            String        @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tripId        String        @unique @db.Uuid
  method        PaymentMethod
  amountClp     Int
  status        PaymentStatus @default(pending)
  tbkToken      String?
  tbkOrderId    String?
  tbkAuthCode   String?
  khipuId       String?
  authorizedAt  DateTime?
  createdAt     DateTime      @default(now())

  trip Trip @relation(fields: [tripId], references: [id])

  @@map("trip_payments")
}

model Rating {
  id         String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tripId     String   @db.Uuid
  raterId    String   @db.Uuid
  ratedId    String   @db.Uuid
  raterRole  UserRole
  score      Int
  tags       String[]
  comment    String?
  isVisible  Boolean  @default(true)
  createdAt  DateTime @default(now())

  trip  Trip @relation(fields: [tripId],  references: [id])
  rater User @relation("RaterRatings", fields: [raterId], references: [id])
  rated User @relation("RatedRatings", fields: [ratedId], references: [id])

  @@unique([tripId, raterId])
  @@map("ratings")
}

model TripLocation {
  id          BigInt   @id @default(autoincrement())
  tripId      String   @db.Uuid
  coordLng    Decimal  @db.Decimal(10, 7)
  coordLat    Decimal  @db.Decimal(10, 7)
  accuracyM   Decimal? @db.Decimal(6, 2)
  speedKmh    Decimal? @db.Decimal(5, 2)
  bearing     Decimal? @db.Decimal(5, 2)
  recordedAt  DateTime

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
ok "prisma/schema.prisma"

# ============================================================
# .env.example
# ============================================================
log "Creando .env.example..."
cat > .env.example << 'EOF'
# ── Base de datos ─────────────────────────────────────────────
DATABASE_URL="postgresql://admin:password@localhost:5432/paxi_db"

# ── Redis ─────────────────────────────────────────────────────
REDIS_URL="redis://localhost:6379"

# ── JWT ───────────────────────────────────────────────────────
JWT_SECRET="cambiar_por_secret_seguro_minimo_32_caracteres"
JWT_EXPIRES_IN="7d"

# ── Google Maps ───────────────────────────────────────────────
GOOGLE_MAPS_API_KEY=""

# ── Transbank ─────────────────────────────────────────────────
TBK_COMMERCE_CODE=""
TBK_API_KEY=""
TBK_ENVIRONMENT="integration"   # integration | production

# ── GCP ───────────────────────────────────────────────────────
GCP_PROJECT_ID=""

# ── App ───────────────────────────────────────────────────────
NODE_ENV="development"
PORT=3000
ALLOWED_ORIGINS="http://localhost:3000,http://localhost:8081"

# ── Configuración de negocio ──────────────────────────────────
OFFER_TTL_SECONDS=90
SEARCH_RADIUS_KM=3
MAX_OFFERS_PER_TRIP=5
EOF

# Crear .env local copiando el ejemplo
cp .env.example .env
ok ".env.example y .env"

# ============================================================
# Dockerfile
# ============================================================
log "Creando Dockerfile..."
cat > Dockerfile << 'EOF'
# ── Stage 1: Builder ────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app

COPY package*.json ./
COPY prisma ./prisma/
RUN npm ci

COPY . .
RUN npx prisma generate
RUN npm run build

# ── Stage 2: Runner ─────────────────────────────────────────
FROM node:20-alpine AS runner
WORKDIR /app

ARG NODE_ENV=production
ARG GIT_SHA=unknown
ENV NODE_ENV=${NODE_ENV}
ENV GIT_SHA=${GIT_SHA}

COPY package*.json ./
COPY prisma ./prisma/
RUN npm ci --only=production && npm cache clean --force

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma

EXPOSE 3000
USER node
CMD ["node", "dist/main.js"]
EOF
ok "Dockerfile"

# ============================================================
# .dockerignore
# ============================================================
cat > .dockerignore << 'EOF'
node_modules
dist
.env
.env.*
!.env.example
.git
.github
*.md
coverage
test
EOF
ok ".dockerignore"

# ============================================================
# GitHub Actions workflow
# ============================================================
log "Creando .github/workflows/deploy.yml..."
cat > .github/workflows/deploy.yml << 'EOF'
name: PAXI CI/CD

on:
  push:
    branches: [develop, main]
  pull_request:
    branches: [develop, main]

concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: false

env:
  GCP_REGION: southamerica-east1
  CLOUD_RUN_SERVICE_STAGING: paxi-api-staging
  CLOUD_RUN_SERVICE_PRODUCTION: paxi-api

jobs:

  test:
    name: 🧪 Tests
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgis/postgis:16-3.4
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: paxi_test
        ports: ["5432:5432"]
        options: --health-cmd pg_isready --health-interval 10s --health-timeout 5s --health-retries 5
      redis:
        image: redis:7-alpine
        ports: ["6379:6379"]
        options: --health-cmd "redis-cli ping" --health-interval 10s --health-timeout 5s --health-retries 5
    env:
      NODE_ENV: test
      DATABASE_URL: postgresql://test:test@localhost:5432/paxi_test
      REDIS_URL: redis://localhost:6379
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci
      - run: npx prisma migrate deploy
      - run: npm run lint
      - run: npm run test -- --coverage
      - run: npm run test:e2e

  build:
    name: 🐳 Build & Push
    runs-on: ubuntu-latest
    needs: test
    if: github.event_name == 'push'
    outputs:
      image: ${{ steps.image.outputs.name }}
    steps:
      - uses: actions/checkout@v4
      - uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}
      - uses: google-github-actions/setup-gcloud@v2
      - run: gcloud auth configure-docker ${{ env.GCP_REGION }}-docker.pkg.dev --quiet
      - id: image
        run: |
          IMAGE="${{ env.GCP_REGION }}-docker.pkg.dev/${{ secrets.GCP_PROJECT_ID }}/paxi/paxi-api:sha-${{ github.sha }}"
          echo "name=$IMAGE" >> $GITHUB_OUTPUT
      - run: docker build --tag ${{ steps.image.outputs.name }} --build-arg GIT_SHA=${{ github.sha }} .
      - run: docker push ${{ steps.image.outputs.name }}

  deploy-staging:
    name: 🚀 Deploy → Staging
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/develop'
    environment:
      name: staging
      url: https://staging-api.paxi.cl
    steps:
      - uses: actions/checkout@v4
      - uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}
      - uses: google-github-actions/setup-gcloud@v2
      - run: npx prisma migrate deploy
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL_STAGING }}
      - run: |
          gcloud run deploy ${{ env.CLOUD_RUN_SERVICE_STAGING }} \
            --image ${{ needs.build.outputs.image }} \
            --region ${{ env.GCP_REGION }} \
            --platform managed \
            --allow-unauthenticated \
            --min-instances 0 \
            --max-instances 5 \
            --memory 512Mi \
            --cpu 1 \
            --port 3000 \
            --set-env-vars NODE_ENV=staging \
            --set-secrets DATABASE_URL=paxi-database-url-staging:latest \
            --set-secrets REDIS_URL=paxi-redis-url-staging:latest \
            --set-secrets JWT_SECRET=paxi-jwt-secret:latest

  deploy-production:
    name: 🚀 Deploy → Producción
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/main'
    environment:
      name: production
      url: https://api.paxi.cl
    steps:
      - uses: actions/checkout@v4
      - uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}
      - uses: google-github-actions/setup-gcloud@v2
      - run: npx prisma migrate deploy
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL_PRODUCTION }}
      - run: |
          gcloud run deploy ${{ env.CLOUD_RUN_SERVICE_PRODUCTION }} \
            --image ${{ needs.build.outputs.image }} \
            --region ${{ env.GCP_REGION }} \
            --platform managed \
            --allow-unauthenticated \
            --min-instances 1 \
            --max-instances 20 \
            --memory 1Gi \
            --cpu 2 \
            --port 3000 \
            --set-env-vars NODE_ENV=production \
            --set-secrets DATABASE_URL=paxi-database-url-production:latest \
            --set-secrets REDIS_URL=paxi-redis-url-production:latest \
            --set-secrets JWT_SECRET=paxi-jwt-secret:latest
      - uses: actions/github-script@v7
        with:
          script: |
            const date = new Date().toISOString().split('T')[0].replace(/-/g,'');
            const sha  = context.sha.substring(0,7);
            await github.rest.git.createRef({
              owner: context.repo.owner, repo: context.repo.repo,
              ref: `refs/tags/release-${date}-${sha}`, sha: context.sha
            });
EOF
ok ".github/workflows/deploy.yml"

# ============================================================
# Actualizar .gitignore
# ============================================================
log "Actualizando .gitignore..."
cat >> .gitignore << 'EOF'

# PAXI — adicionales
.env
!.env.example
dist/
coverage/
*.log
EOF
ok ".gitignore"

# ============================================================
# Limpiar archivos de ejemplo de Nest que no usaremos
# ============================================================
log "Limpiando archivos de ejemplo de Nest..."
rm -f src/app.controller.ts
rm -f src/app.controller.spec.ts
rm -f src/app.service.ts
ok "Archivos de ejemplo eliminados"

# ============================================================
# Primera migración de Prisma
# ============================================================
log "Generando cliente Prisma..."
npx prisma generate
ok "Prisma client generado"

# ============================================================
# Resumen final
# ============================================================
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ PAXI scaffold completado            ${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo "Estructura creada:"
echo "  src/"
echo "  ├── main.ts                  → configurado para producción"
echo "  ├── app.module.ts            → todos los módulos importados"
echo "  ├── shared/"
echo "  │   ├── database/            → PrismaService"
echo "  │   ├── redis/               → RedisService + GeoService"
echo "  │   ├── queue/               → BullMQ (4 queues)"
echo "  │   └── uf/                  → UfService (Mindicador API)"
echo "  └── modules/"
echo "      ├── auth/                → stub listo"
echo "      ├── users/               → stub listo"
echo "      ├── vehicles/            → stub listo"
echo "      ├── subscriptions/       → stub listo"
echo "      ├── trips/               → stub listo"
echo "      ├── pricing/             → stub listo"
echo "      ├── payments/            → stub listo"
echo "      ├── ratings/             → stub listo"
echo "      └── paxi-card/           → stub listo"
echo ""
echo "Archivos de infraestructura:"
echo "  prisma/schema.prisma         → modelo completo de PAXI"
echo "  Dockerfile                   → multi-stage, listo para Cloud Run"
echo "  .dockerignore"
echo "  .env / .env.example          → todas las variables necesarias"
echo "  .github/workflows/deploy.yml → pipeline CI/CD completo"
echo ""
echo "Próximo paso:"
echo "  1. Editar .env con tus valores locales"
echo "  2. npx prisma migrate dev --name init"
echo "  3. npm run start:dev"
echo ""