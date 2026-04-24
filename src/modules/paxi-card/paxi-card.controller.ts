import { Controller } from '@nestjs/common';
import { PaxiCardService } from './paxi-card.service';

@Controller('paxi-card')
export class PaxiCardController {
  constructor(private readonly paxiCardService: PaxiCardService) {}
}
