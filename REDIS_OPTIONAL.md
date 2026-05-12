# Redis Opcional - Guía de Implementación

## Resumen

Redis ha sido configurado como **opcional** a través de la variable de entorno `ENABLE_REDIS`. Esto permite deshabilitar Redis completamente para la fase de pruebas, reduciendo costos de infraestructura y acelerando los deploys.

---

## Configuración

### Variables de Entorno

```bash
# Habilitar/Deshabilitar Redis (por defecto: "true")
ENABLE_REDIS="true"  # "true" para habilitar, "false" o ausente para deshabilitar

# URL de conexión a Redis (requerido si ENABLE_REDIS=true)
REDIS_URL="redis://localhost:6379"
```

### Ejemplos de Configuración

#### Fase de Desarrollo CON Redis:

```bash
ENABLE_REDIS=true
REDIS_URL=redis://localhost:6379
```

#### Fase de Pruebas SIN Redis (más rápido):

```bash
ENABLE_REDIS=false
# REDIS_URL puede omitirse o ser cualquier valor
```

---

## Comportamiento Cuando Redis Está Deshabilitado

### 1. **RedisService** (`src/shared/redis/redis.service.ts`)

- ✅ Se inicializa sin conectarse a Redis
- ✅ Métodos `get()`, `set()`, `del()`, `exists()` son no-op (no hacen nada)
- ✅ `getClient()` retorna `null`
- ✅ Se loguea: `⚠️ Redis está DESHABILITADO`

### 2. **GeoService** (`src/shared/redis/geo.service.ts`)

- ✅ `updateDriverLocation()` es no-op
- ✅ `findDriversNearby()` retorna array vacío `[]`
- ✅ `removeDriver()` es no-op
- **Implicación**: Los conductores no se rastrean geográficamente

### 3. **UfService** (`src/shared/uf/uf.service.ts`)

- ✅ Se ignora la caché de 24 horas
- ✅ **Cada solicitud** consulta la API externa de Mindicador
- **Implicación**: Más latencia, pero valores siempre frescos

### 4. **QueueModule** (`src/shared/queue/queue.module.ts`)

- ✅ BullMQ se deshabilita
- ✅ No hay procesamiento de jobs en background
- ✅ Se loguea: `⚠️ BullMQ queues DESHABILITADAS`
- **Implicación**: Notificaciones, refrescado de UF y otras tareas no se procesan async

---

## Archivos Modificados

| Archivo                             | Cambios                                                                    |
| ----------------------------------- | -------------------------------------------------------------------------- |
| `src/shared/redis/redis.service.ts` | Añadida lógica condicional en `onModuleInit()`, métodos ahora son graceful |
| `src/shared/redis/geo.service.ts`   | Añadidas verificaciones `isRedisEnabled()` en todos los métodos            |
| `src/shared/uf/uf.service.ts`       | Lógica de caché condicional en `getCurrentValue()`                         |
| `src/shared/queue/queue.module.ts`  | Configuración dinámica de BullMQ según `ENABLE_REDIS`                      |
| `.env.example`                      | Añadida variable `ENABLE_REDIS`                                            |
| `docs/environment.md`               | Documentación de `ENABLE_REDIS` y comportamiento cuando está deshabilitado |

---

## Consideraciones para Producción

⚠️ **IMPORTANTE**: Se recomienda mantener `ENABLE_REDIS=true` en producción porque:

1. **Geolocalización**: Sin Redis, `findDriversNearby()` siempre retorna `[]`
2. **Caché**: Sin caché de UF, cada request a conversiones UF→CLP toma 100-300ms extra
3. **Jobs en background**: Las notificaciones y tareas async no se procesarán

### Para Fases de Prueba:

✅ `ENABLE_REDIS=false` es perfecto para:

- Desarrollo local rápido
- Testing en CI/CD sin servicios externos
- Pruebas de carga sin infraestructura adicional
- Deploys rápidos (no necesita esperar a Redis)

---

## Verificación

Para verificar que Redis está deshabilitado en los logs:

```bash
npm run start:dev

# Deberías ver:
# ⚠️  Redis está DESHABILITADO (ENABLE_REDIS=false o REDIS_URL no configurado)
# ⚠️  BullMQ queues DESHABILITADAS (ENABLE_REDIS=false o REDIS_URL no configurado)
```

---

## Testing

Los tests pueden omitir Redis mockeando o dejando `ENABLE_REDIS=false`:

```typescript
// En tu .env.test
ENABLE_REDIS = false;
```

---

## Resumen de Beneficios

✅ **Reducción de costos**: No pagar por Redis en fase de pruebas  
✅ **Deploys más rápidos**: Menos servicios que levantar  
✅ **Desarrollo local flexible**: Elige si necesitas cache o no  
✅ **Backwards compatible**: Código existente funciona igual  
✅ **Graceful degradation**: La app funciona sin Redis, solo con limitaciones esperadas
