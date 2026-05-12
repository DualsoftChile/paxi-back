import {
  Injectable,
  OnModuleInit,
  OnModuleDestroy,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private client: Redis | null = null;
  private isEnabled = false;

  constructor(private config: ConfigService) {}

  onModuleInit() {
    const enableRedis = this.config.get<string>('ENABLE_REDIS');
    const redisUrl = this.config.get<string>('REDIS_URL');

    // Redis está habilitado si ENABLE_REDIS=true Y REDIS_URL está configurado
    this.isEnabled =
      enableRedis === 'true' && !!redisUrl && redisUrl.length > 0;

    if (!this.isEnabled) {
      this.logger.warn(
        '⚠️  Redis está DESHABILITADO (ENABLE_REDIS=false o REDIS_URL no configurado)',
      );
      return;
    }

    this.client = new Redis(redisUrl!, {
      maxRetriesPerRequest: 3,
      lazyConnect: false,
    });

    this.client.on('connect', () => this.logger.log('✅ Conectado a Redis'));
    this.client.on('error', (err) => this.logger.error('Redis error', err));
  }

  async onModuleDestroy() {
    if (this.client) {
      await this.client.quit();
    }
  }

  isRedisEnabled(): boolean {
    return this.isEnabled;
  }

  // ── Cache básico ────────────────────────────────────────────
  async get(key: string): Promise<string | null> {
    if (!this.isEnabled) return null;
    return this.client!.get(key);
  }

  async set(key: string, value: string, ttlSeconds?: number): Promise<void> {
    if (!this.isEnabled) return;
    if (ttlSeconds) {
      await this.client!.set(key, value, 'EX', ttlSeconds);
    } else {
      await this.client!.set(key, value);
    }
  }

  async del(key: string): Promise<void> {
    if (!this.isEnabled) return;
    await this.client!.del(key);
  }

  async exists(key: string): Promise<boolean> {
    if (!this.isEnabled) return false;
    return (await this.client!.exists(key)) === 1;
  }

  // ── Acceso al cliente raw para operaciones avanzadas ────────
  getClient(): Redis | null {
    if (!this.isEnabled) return null;
    return this.client;
  }
}
