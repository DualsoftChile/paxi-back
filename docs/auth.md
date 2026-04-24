# Autenticación

## Tokens

| Token | Duración | Secret |
|-------|----------|--------|
| Access token | 7 días (`JWT_EXPIRES_IN`) | `JWT_SECRET` |
| Refresh token | 30 días | `JWT_REFRESH_SECRET` (fallback a `JWT_SECRET`) |

El payload JWT contiene:

```json
{
  "sub": "<uuid del usuario>",
  "email": "usuario@paxi.cl",
  "role": "driver",
  "iat": 1714000000,
  "exp": 1714604800
}
```

## Endpoints

### POST /api/v1/auth/register

Registra un nuevo usuario. Por defecto crea un `passenger`; pasar `role: "driver"` para conductores.

**Body:**
```json
{
  "email": "nuevo@paxi.cl",
  "password": "MiPassword1!",
  "fullName": "Juan Pérez",
  "phone": "+56912345678",
  "rut": "12345678-9",
  "role": "passenger"
}
```

| Campo | Requerido | Validación |
|-------|-----------|-----------|
| email | Sí | formato email válido |
| password | Sí | mínimo 8 caracteres |
| fullName | Sí | mínimo 2 caracteres |
| phone | No | formato `+56XXXXXXXXX` |
| rut | No | string libre (validación formato pendiente) |
| role | No | `driver` o `passenger` (default: `passenger`) |

**Respuesta 201:**
```json
{
  "accessToken": "eyJhbG...",
  "refreshToken": "eyJhbG...",
  "tokenType": "Bearer"
}
```

**Errores:**
- `409 Conflict` — email o teléfono ya registrado

---

### POST /api/v1/auth/login

**Body:**
```json
{
  "email": "usuario@paxi.cl",
  "password": "MiPassword1!"
}
```

**Respuesta 200:**
```json
{
  "accessToken": "eyJhbG...",
  "refreshToken": "eyJhbG...",
  "tokenType": "Bearer"
}
```

**Errores:**
- `401 Unauthorized` — credenciales inválidas o cuenta desactivada

---

### POST /api/v1/auth/refresh

Emite un nuevo par de tokens usando el refresh token. El refresh token anterior
sigue siendo válido hasta su expiración (no hay rotación con invalidación en esta versión).

**Body:**
```json
{
  "refreshToken": "eyJhbG..."
}
```

**Respuesta 200:** mismo formato que login.

**Errores:**
- `401 Unauthorized` — token inválido, expirado, o usuario desactivado

---

### GET /api/v1/auth/me

Requiere `Authorization: Bearer <accessToken>`.

**Respuesta 200:**
```json
{
  "id": "uuid",
  "email": "usuario@paxi.cl",
  "phone": "+56912345678",
  "fullName": "Juan Pérez",
  "rut": "12345678-9",
  "role": "driver",
  "kycStatus": "pending",
  "avatarUrl": null,
  "ratingAvg": "5.00",
  "ratingCount": 0,
  "isActive": true,
  "createdAt": "2026-04-23T00:00:00.000Z"
}
```

**Errores:**
- `401 Unauthorized` — token ausente, inválido o expirado

---

## Proteger nuevos endpoints

### 1. Importar AuthModule en el módulo de destino

```typescript
// trips.module.ts
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [AuthModule],
  controllers: [TripsController],
  providers: [TripsService],
})
export class TripsModule {}
```

### 2. Usar JwtAuthGuard y @CurrentUser() en el controller

```typescript
import { UseGuards, Get } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { AuthUser } from '../auth/interfaces/auth-user.interface';

@Controller('trips')
export class TripsController {
  @Get()
  @UseGuards(JwtAuthGuard)
  getMyTrips(@CurrentUser() user: AuthUser) {
    // user.id, user.email, user.role disponibles aquí
    return this.tripsService.findByUser(user.id);
  }
}
```

### AuthUser

El decorator `@CurrentUser()` devuelve el objeto que establece `JwtStrategy.validate()`:

```typescript
interface AuthUser {
  id: string;      // UUID del usuario (= payload.sub)
  email: string;
  role: UserRole;  // 'driver' | 'passenger' | 'admin'
}
```

No contiene campos sensibles ni hace una consulta extra a la DB. Si necesitas el
usuario completo, llama a `PrismaService` en el servicio usando `user.id`.

## Seguridad

- Contraseñas hasheadas con **bcrypt** (12 rounds).
- El endpoint de login usa comparación en tiempo constante (`bcrypt.compare`) para
  evitar timing attacks.
- El mensaje de error es idéntico para "usuario no existe" y "contraseña incorrecta"
  para no filtrar información de la existencia del email.
- `passwordHash` **nunca** aparece en ninguna respuesta (los `select` de Prisma lo
  excluyen explícitamente).
