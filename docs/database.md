# Base de datos

## Conexión

Prisma 7 usa el driver nativo `@prisma/adapter-pg` con un `pg.Pool`, lo que evita
el proxy TCP interno de versiones anteriores y habilita connection pooling real.

La configuración vive en `prisma.config.ts` (no en `schema.prisma`):

```ts
// prisma.config.ts
defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: { path: 'prisma/migrations', seed: '...' },
  datasource: { url: env('DATABASE_URL') },
})
```

## Extensiones PostgreSQL

| Extensión | Uso |
|-----------|-----|
| `pgcrypto` | `gen_random_uuid()` y `gen_random_bytes()` para IDs y QR tokens |
| `postgis` | Futura indexación geoespacial de coordenadas de viaje |

## Modelos

### User
Campo principal de toda la plataforma. Un mismo modelo sirve para drivers, passengers y admins.

| Campo | Tipo | Notas |
|-------|------|-------|
| id | UUID | `gen_random_uuid()` |
| email | String | único |
| phone | String? | único, formato `+56XXXXXXXXX` |
| fullName | String | |
| rut | String? | único, formato chileno |
| passwordHash | String? | bcrypt 12 rounds |
| role | UserRole | `driver \| passenger \| admin` |
| kycStatus | KycStatus | default `pending` |
| ratingAvg | Decimal(3,2) | default 5.00, actualizado tras cada calificación |
| isActive | Boolean | soft-ban sin borrar el registro |
| deletedAt | DateTime? | soft-delete |

### Vehicle
Un driver puede tener múltiples vehículos; sólo uno puede estar activo por viaje.

| Campo | Tipo | Notas |
|-------|------|-------|
| plate | String | único, patente chilena |
| fuelType | FuelType | usado para calcular costo de combustible en ofertas |
| lPer100km | Decimal(5,2) | consumo real del vehículo |
| soatExpiry / revisionExpiry | Date? | para alertas de vencimiento |

### Trip
El objeto central del negocio. Coordenadas almacenadas como `Decimal(10,7)`.

| Estado | Descripción |
|--------|-------------|
| `requested` | Passenger solicitó, aún no hay ofertas |
| `awaiting_offer` | Sistema enviando solicitud a drivers cercanos |
| `offer_received` | Al menos una oferta disponible |
| `accepted` | Passenger aceptó una oferta |
| `driver_en_route` | Driver en camino al origen |
| `in_progress` | Viaje en curso |
| `completed` | Viaje terminado, pendiente calificación/pago |
| `cancelled` | Cancelado por cualquiera de las partes |

### PriceOffer
Cada driver hace su propia oferta por un viaje. Tiene TTL de 90 segundos (configurable
con `OFFER_TTL_SECONDS`). El precio incluye desglose de costo de combustible.

### Subscription
Modelo de suscripción del driver. El campo `amountUf` almacena el monto en UF y
`ufValueAtCharge` el valor del peso en el momento del cobro, para auditoría.

| Plan | Descripción |
|------|-------------|
| `daily` | Acceso por 1 día |
| `weekly` | Acceso por 7 días |
| `monthly_uf` | Acceso por 30 días, cobrado en UF convertida a CLP |

### PaxiCard
Tarjeta digital del conductor. Genera un `qrToken` con `gen_random_bytes(32)` en hex
al momento de la creación. Tiene billetera en CLP (`walletBalanceClp`).

### TripLocation
Tabla de alta frecuencia. Almacena el historial de coordenadas GPS del viaje.
Indexada por `(tripId, recordedAt DESC)` para consultas de último punto conocido.

### Rating
Calificación bidireccional (driver califica passenger y viceversa).
Constraint único `(tripId, raterId)` previene doble calificación.

## Enums

```
UserRole:       driver | passenger | admin
KycStatus:      pending | in_review | approved | rejected | suspended
FuelType:       gasoline_93 | gasoline_95 | gasoline_97 | diesel | electric | hybrid
PlanType:       daily | weekly | monthly_uf
SubStatus:      pending_payment | active | grace_period | expired | cancelled
TripStatus:     requested | awaiting_offer | offer_received | accepted |
                driver_en_route | in_progress | completed | cancelled
OfferStatus:    pending | accepted | rejected | expired
PaymentMethod:  cash | webpay | khipu | paxi_wallet
PaymentStatus:  pending | authorized | captured | failed | reversed
```

## Comandos Prisma

```bash
# Crear y aplicar nueva migración
npx prisma migrate dev --name descripcion_del_cambio

# Aplicar migraciones en producción (sin crear archivos nuevos)
npx prisma migrate deploy

# Regenerar cliente TypeScript tras cambios en el schema
npx prisma generate

# Poblar base de datos con usuarios de prueba
npx prisma db seed

# Inspeccionar la DB en el navegador
npx prisma studio
```

## Seed

El seed (`prisma/seed.ts`) crea 3 usuarios con `upsert` (idempotente):

| Rol | Email | Password |
|-----|-------|----------|
| admin | admin@paxi.cl | Admin1234! |
| driver | driver@paxi.cl | Driver1234! |
| passenger | passenger@paxi.cl | Passenger1234! |

Es seguro re-ejecutarlo: sólo actualiza el `passwordHash`, no duplica registros.
