import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

// Shared
import { DatabaseModule } from './shared/database/database.module';
import { RedisModule } from './shared/redis/redis.module';
import { QueueModule } from './shared/queue/queue.module';

// Módulos de dominio
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { VehiclesModule } from './modules/vehicles/vehicles.module';
import { SubscriptionsModule } from './modules/subscriptions/subscriptions.module';
import { TripsModule } from './modules/trips/trips.module';
import { PricingModule } from './modules/pricing/pricing.module';
import { PaymentsModule } from './modules/payments/payments.module';
import { RatingsModule } from './modules/ratings/ratings.module';
import { PaxiCardModule } from './modules/paxi-card/paxi-card.module';

@Module({
  imports: [
    // Variables de entorno disponibles en toda la app
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),

    // Infraestructura compartida
    DatabaseModule,
    RedisModule,
    QueueModule,

    // Dominios de negocio
    AuthModule,
    UsersModule,
    VehiclesModule,
    SubscriptionsModule,
    TripsModule,
    PricingModule,
    PaymentsModule,
    RatingsModule,
    PaxiCardModule,
  ],
})
export class AppModule {}
