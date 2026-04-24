import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Global() // disponible en toda la app sin necesidad de importar en cada módulo
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class DatabaseModule {}
