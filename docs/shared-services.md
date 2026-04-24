# Servicios compartidos

Todos los servicios de `src/shared/` son `@Global()` — disponibles en cualquier
módulo sin necesidad de importar explícitamente.

---

## PrismaService

**Archivo:** `src/shared/database/prisma.service.ts`

Extiende `PrismaClient` con el adapter `PrismaPg` para usar el pool de conexiones
nativo de `pg` en lugar del proxy TCP de Prisma.

```typescript
// Uso en cualquier servicio
constructor(private readonly prisma: PrismaService) {}

const user = await this.prisma.user.findUnique({ where: { id } });
```

El nivel de logging se controla con `NODE_ENV`:
- `development` → `['query', 'info', 'warn', 'error']`
- `production` → `['error']`

---

## RedisService

**Archivo:** `src/shared/redis/redis.service.ts`

Wrapper sobre `ioredis` con helpers para cache básico y acceso al cliente raw.

```typescript
constructor(private readonly redis: RedisService) {}

// Cache simple
await this.redis.set('key', 'value', 300);   // con TTL en segundos
await this.redis.get('key');                  // → 'value' | null
await this.redis.del('key');
await this.redis.exists('key');               // → boolean

// Cliente raw para operaciones avanzadas (pipeline, pub/sub, etc.)
const client = this.redis.getClient();
await client.pipeline().set('a', '1').set('b', '2').exec();
```

Configurado con `maxRetriesPerRequest: 3` y reconexión automática.

---

## GeoService

**Archivo:** `src/shared/redis/geo.service.ts`

Gestiona la posición en tiempo real de conductores usando Redis GeoSets (`GEOADD`,
`GEORADIUS`). Todos los conductores activos se almacenan en la key `drivers:locations`.

```typescript
constructor(private readonly geo: GeoService) {}

// El driver reporta su posición (cada ~30s desde el móvil)
await this.geo.updateDriverLocation(driverId, longitude, latitude);

// Buscar conductores en un radio
const drivers = await this.geo.findDriversNearby(
  originLng,
  originLat,
  radiusKm,   // default: 3 (configurable con SEARCH_RADIUS_KM)
  limit,      // default: 10
);
// → [{ driverId, latitude, longitude, distanceKm }]

// Driver se desconecta
await this.geo.removeDriver(driverId);
```

**Heartbeat:** `updateDriverLocation` también escribe `driver:status:<id>` con TTL
de 35 segundos. Si el driver no reporta posición en ese tiempo, desaparece del mapa
aunque su coordenada siga en el GeoSet. El valor `SEARCH_RADIUS_KM` del `.env`
define el radio de búsqueda por defecto.

---

## QueueModule y colas BullMQ

**Archivo:** `src/shared/queue/queue.module.ts`

Define 4 colas sobre Redis. Los nombres se exportan como constantes para evitar
strings hardcodeados.

```typescript
import {
  QUEUE_NOTIFICATIONS,
  QUEUE_SUBSCRIPTIONS,
  QUEUE_UF_REFRESH,
  QUEUE_FUEL_REFRESH,
} from '../../shared/queue/queue.module';
```

| Constante | Nombre | Uso previsto |
|-----------|--------|-------------|
| `QUEUE_NOTIFICATIONS` | `notifications` | Push notifications / SMS |
| `QUEUE_SUBSCRIPTIONS` | `subscriptions` | Cobros automáticos de suscripción |
| `QUEUE_UF_REFRESH` | `uf-refresh` | Actualización diaria del valor UF |
| `QUEUE_FUEL_REFRESH` | `fuel-refresh` | Actualización de precios de combustible |

Configuración de retención de jobs:
- Completados: últimos 100
- Fallidos: últimos 200 (para debug)

Para usar una cola en un módulo:

```typescript
// pricing.module.ts
import { BullModule } from '@nestjs/bull';
import { QUEUE_NOTIFICATIONS } from '../../shared/queue/queue.module';

@Module({
  imports: [
    BullModule.registerQueue({ name: QUEUE_NOTIFICATIONS }),
  ],
})

// pricing.service.ts
@InjectQueue(QUEUE_NOTIFICATIONS) private notifQueue: Queue
await this.notifQueue.add('trip-offer', { tripId, driverId });
```

---

## UfService

**Archivo:** `src/shared/uf/uf.service.ts`

Obtiene el valor actualizado de la UF desde la API pública de Mindicador (`mindicador.cl/api/uf`).
Cachea el resultado en Redis por 24 horas para no depender de la disponibilidad externa.

```typescript
constructor(private readonly uf: UfService) {}

// Valor actual de la UF en CLP
const ufValue = await this.uf.getCurrentValue();  // → 38241.50

// Convertir monto en UF a CLP
const clp = await this.uf.toCLP(0.05);            // → 1912

// Forzar refresco desde Mindicador (usado por QUEUE_UF_REFRESH)
const newValue = await this.uf.refresh();
```

El módulo que contiene `UfService` debe importar `HttpModule` de `@nestjs/axios`.
El `UfService` **no** está marcado como `@Global()` — importarlo en el módulo que lo necesite.
