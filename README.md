# PAXI Backend — Documentación

Plataforma chilena de ride-hailing sin comisiones con modelo de suscripción en UF.

## Índice

| Archivo                                    | Contenido                                          |
| ------------------------------------------ | -------------------------------------------------- |
| [architecture.md](./architecture.md)       | Stack, estructura de módulos, decisiones de diseño |
| [database.md](./database.md)               | Schema Prisma, modelos, enums, migraciones, seed   |
| [auth.md](./auth.md)                       | Autenticación JWT, endpoints, guards, decoradores  |
| [shared-services.md](./shared-services.md) | Redis, GeoService, BullMQ, UfService               |
| [environment.md](./environment.md)         | Variables de entorno y configuración               |

## Inicio rápido

```bash
# 1. Instalar dependencias
npm install

# 2. Copiar y configurar variables de entorno
cp .env.example .env

# 3. Levantar infraestructura (PostgreSQL + Redis)
docker-compose up -d

# 4. Ejecutar migraciones
npx prisma migrate dev

# 5. Poblar base de datos con datos de prueba
npx prisma db seed

# 6. Iniciar servidor en modo desarrollo
npm run start:dev
```

La API queda disponible en `http://localhost:3000/api/v1`.

## Usuarios de prueba

| Rol       | Email             | Password       |
| --------- | ----------------- | -------------- |
| admin     | admin@paxi.cl     | Admin1234!     |
| driver    | driver@paxi.cl    | Driver1234!    |
| passenger | passenger@paxi.cl | Passenger1234! |
