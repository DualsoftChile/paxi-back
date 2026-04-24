import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { RedisService } from './redis.service';
import { GeoService }   from './geo.service';

@Global()
@Module({
  providers: [RedisService, GeoService],
  exports:   [RedisService, GeoService],
})
export class RedisModule {}
