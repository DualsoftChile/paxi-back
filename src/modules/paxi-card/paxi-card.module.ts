import { Module } from '@nestjs/common';
import { PaxiCardController } from './paxi-card.controller';
import { PaxiCardService } from './paxi-card.service';

@Module({
  controllers: [PaxiCardController],
  providers: [PaxiCardService],
  exports: [PaxiCardService],
})
export class PaxiCardModule {}
