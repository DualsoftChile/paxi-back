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
