import { BullModule } from '@nestjs/bull';
import { Module, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

// Nombres de las queues — exportar para usar en otros módulos
export const QUEUE_NOTIFICATIONS = 'notifications';
export const QUEUE_SUBSCRIPTIONS = 'subscriptions';
export const QUEUE_UF_REFRESH = 'uf-refresh';
export const QUEUE_FUEL_REFRESH = 'fuel-refresh';

@Module({
  imports: [
    BullModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => {
        const enableRedis = config.get<string>('ENABLE_REDIS');
        const redisUrl = config.get<string>('REDIS_URL');
        const isEnabled = enableRedis === 'true' && redisUrl;

        if (!isEnabled) {
          Logger.warn(
            '⚠️ BullMQ queues DESHABILITADAS (ENABLE_REDIS=false o REDIS_URL no configurado)',
            'QueueModule',
          );
          // Retornar configuración vacía si Redis no está habilitado
          return { redis: '' };
        }

        return {
          redis: redisUrl,
          defaultJobOptions: {
            removeOnComplete: 100, // mantener los últimos 100 jobs completados
            removeOnFail: 200, // mantener los últimos 200 jobs fallidos para debug
          },
        };
      },
    }),

    BullModule.registerQueue(
      { name: QUEUE_NOTIFICATIONS },
      { name: QUEUE_SUBSCRIPTIONS },
      { name: QUEUE_UF_REFRESH },
      { name: QUEUE_FUEL_REFRESH },
    ),
  ],
  exports: [BullModule],
})
export class QueueModule {}
