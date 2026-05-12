# Variables de entorno

Copiar `.env.example` a `.env` y completar los valores antes de iniciar.

```bash
cp .env.example .env
```

---

## Base de datos

| Variable       | Ejemplo                                              | Descripción                                                                  |
| -------------- | ---------------------------------------------------- | ---------------------------------------------------------------------------- |
| `DATABASE_URL` | `postgresql://admin:password@localhost:5432/paxi_db` | Connection string de PostgreSQL. En Cloud Run apuntar al proxy de Cloud SQL. |

---

## Redis

| Variable       | Ejemplo                  | Descripción                                                                                                                                             |
| -------------- | ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ENABLE_REDIS` | `true`                   | Habilitar/deshabilitar Redis. Por defecto `true` para producción, cambiar a `false` para fase de pruebas sin servicios adicionales.                     |
| `REDIS_URL`    | `redis://localhost:6379` | URL de conexión a Redis. Requerido si `ENABLE_REDIS=true`. Usado por RedisService, GeoService y BullMQ. Si está deshabilitado, se ignora esta variable. |

---

**Nota sobre Redis deshabilitado:**

- **Cache de UF**: Se ignora la caché, cada solicitud consulta la API de Mindicador.
- **Ubicación de conductores (GeoService)**: `findDriversNearby()` retorna array vacío; `updateDriverLocation()` es no-op.
- **Queues (BullMQ)**: Las colas se deshabilitan, los jobs no se procesan en background.

## JWT

| Variable             | Ejemplo                    | Descripción                                                                                                            |
| -------------------- | -------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `JWT_SECRET`         | `s3cr3t_m1n_32_chars_aqui` | Secret para firmar access tokens. Mínimo 32 caracteres.                                                                |
| `JWT_EXPIRES_IN`     | `7d`                       | Expiración del access token. Formato de la librería `ms` (`7d`, `1h`, `3600`).                                         |
| `JWT_REFRESH_SECRET` | `otro_s3cr3t_diferente`    | Secret para firmar refresh tokens. Si se omite, usa `JWT_SECRET`. Se recomienda usar un secret distinto en producción. |

---

## Google Maps

| Variable              | Ejemplo     | Descripción                                                                               |
| --------------------- | ----------- | ----------------------------------------------------------------------------------------- |
| `GOOGLE_MAPS_API_KEY` | `AIzaSy...` | Para cálculo de rutas, distancias y geocoding. Habilitado para la app móvil y el backend. |

---

## Transbank (Webpay Plus)

| Variable            | Ejemplo                                                            | Descripción                                               |
| ------------------- | ------------------------------------------------------------------ | --------------------------------------------------------- |
| `TBK_COMMERCE_CODE` | `597055555532`                                                     | Código de comercio otorgado por Transbank.                |
| `TBK_API_KEY`       | `579B532A7440BB0C9079DED94D31EA1615BACEB56610332264630D42D0A36B1C` | API key del comercio.                                     |
| `TBK_ENVIRONMENT`   | `integration`                                                      | `integration` para pruebas, `production` para producción. |

En integración se pueden usar las credenciales de prueba públicas de Transbank.

---

## GCP

| Variable         | Ejemplo            | Descripción                                                           |
| ---------------- | ------------------ | --------------------------------------------------------------------- |
| `GCP_PROJECT_ID` | `paxi-prod-123456` | ID del proyecto GCP. Usado para Cloud Run, Cloud SQL, Secret Manager. |

---

## Aplicación

| Variable          | Ejemplo                                       | Descripción                                                                                 |
| ----------------- | --------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `NODE_ENV`        | `development`                                 | `development` activa el logging de queries Prisma.                                          |
| `PORT`            | `3000`                                        | Puerto en que escucha el servidor. Cloud Run inyecta este valor automáticamente.            |
| `ALLOWED_ORIGINS` | `http://localhost:3000,http://localhost:8081` | CORS: lista separada por comas. En producción poner el dominio del frontend y la app móvil. |

---

## Configuración de negocio

| Variable              | Ejemplo | Descripción                                                                                   |
| --------------------- | ------- | --------------------------------------------------------------------------------------------- |
| `OFFER_TTL_SECONDS`   | `90`    | Tiempo en segundos que tiene un driver para que su oferta expire si el passenger no responde. |
| `SEARCH_RADIUS_KM`    | `3`     | Radio en kilómetros para buscar drivers cercanos al origen del viaje.                         |
| `MAX_OFFERS_PER_TRIP` | `5`     | Máximo de ofertas simultáneas que puede recibir un viaje.                                     |

---

## Configuración en producción (Cloud Run)

Las variables sensibles (`JWT_SECRET`, `TBK_API_KEY`, credenciales DB) deben
almacenarse en **GCP Secret Manager** y montarse como variables de entorno en el
servicio de Cloud Run. No incluirlas en el repositorio ni en la imagen Docker.

```bash
# Crear un secret en GCP
gcloud secrets create JWT_SECRET --data-file=-  <<< "mi_secret_seguro"

# Referenciar en Cloud Run (en el cloudbuild.yaml o al desplegar)
gcloud run services update paxi-api \
  --update-secrets=JWT_SECRET=JWT_SECRET:latest
```
