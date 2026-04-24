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
