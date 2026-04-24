# Arquitectura

## Stack

| Capa | Tecnología |
|------|-----------|
| Framework | NestJS 11 + TypeScript 5 |
| Base de datos | PostgreSQL 16 + PostGIS (extensiones `pgcrypto`, `postgis`) |
| ORM | Prisma 7 con driver `@prisma/adapter-pg` (connection pooling nativo) |
| Caché / Geo | Redis 7 vía ioredis |
| Colas | BullMQ (`@nestjs/bull`) sobre Redis |
| Real-time | Socket.IO (`@nestjs/websockets`) |
| HTTP Client | `@nestjs/axios` (para Mindicador API) |
| Deploy | GCP Cloud Run |

## Estructura de directorios

```
src/
├── main.ts                    # Bootstrap, ValidationPipe global, CORS
├── app.module.ts              # Módulo raíz — importa todos los módulos
│
├── shared/                    # Infraestructura transversal (@Global)
│   ├── database/
│   │   ├── database.module.ts # Exporta PrismaService globalmente
│   │   └── prisma.service.ts  # PrismaClient con PrismaPg adapter
│   ├── redis/
│   │   ├── redis.module.ts    # Exporta RedisService y GeoService globalmente
│   │   ├── redis.service.ts   # Cache básico + acceso al cliente ioredis raw
│   │   └── geo.service.ts     # Posicionamiento de conductores con GEORADIUS
│   ├── queue/
│   │   └── queue.module.ts    # Define las 4 colas BullMQ
│   └── uf/
│       └── uf.service.ts      # Valor UF desde Mindicador con cache 24h
│
└── modules/                   # Dominios de negocio
    ├── auth/                  # JWT, registro, login, guards
    ├── users/                 # Perfil, KYC, gestión de cuenta
    ├── vehicles/              # Alta y verificación de vehículos
    ├── subscriptions/         # Planes driver (daily/weekly/monthly_uf)
    ├── trips/                 # Ciclo de vida del viaje
    ├── pricing/               # Motor de oferta de precio + costo combustible
    ├── payments/              # Transbank Webpay, Khipu, wallet
    ├── ratings/               # Calificaciones post-viaje
    └── paxi-card/             # Tarjeta digital del conductor
```

## Módulos compartidos (@Global)

`DatabaseModule`, `RedisModule` y `QueueModule` están marcados como `@Global()`.
Esto significa que `PrismaService`, `RedisService`, `GeoService` y las colas BullMQ
están disponibles en cualquier módulo sin necesidad de importarlos explícitamente.

La excepción es `AuthModule`: debe importarse explícitamente en los módulos que
necesiten `JwtAuthGuard`.

## Flujo de un viaje (overview)

```
Passenger solicita viaje
        │
        ▼
trips → TripStatus.requested
        │
        ▼
pricing notifica drivers cercanos (GeoService.findDriversNearby)
        │
        ▼
Drivers hacen oferta → PriceOffer (OfferStatus.pending, TTL 90s)
        │
        ▼
Passenger acepta oferta → TripStatus.accepted
        │
        ▼
Driver en camino → driver_en_route
Driver recoge pasajero → in_progress
Viaje termina → completed
        │
        ▼
ratings → ambos se califican
payments → se procesa el pago
```

## Convenciones de código

- **DTOs**: en `modules/<nombre>/dto/`, validados con `class-validator`.
- **Entidades**: se usa directamente el tipo generado por Prisma, sin clases duplicadas.
- **Guards**: se importan desde `AuthModule` — nunca se re-crean en otros módulos.
- **Queues**: los nombres de colas se exportan como constantes desde `QueueModule`.
- **Prefijo global**: todos los endpoints son `api/v1/<recurso>`.
