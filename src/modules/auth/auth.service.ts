import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { UserRole } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../../shared/database/prisma.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { JwtPayload } from './interfaces/jwt-payload.interface';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async register(dto: RegisterDto) {
    const emailTaken = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    if (emailTaken) throw new ConflictException('Email ya registrado');

    if (dto.phone) {
      const phoneTaken = await this.prisma.user.findUnique({
        where: { phone: dto.phone },
      });
      if (phoneTaken) throw new ConflictException('Teléfono ya registrado');
    }

    const passwordHash = await bcrypt.hash(dto.password, 12);

    const user = await this.prisma.user.create({
      data: {
        email: dto.email,
        fullName: dto.fullName,
        phone: dto.phone ?? null,
        rut: dto.rut ?? null,
        passwordHash,
        role: dto.role ?? UserRole.passenger,
      },
      select: { id: true, email: true, role: true },
    });

    return this.buildTokenPair(user);
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
      select: {
        id: true,
        email: true,
        role: true,
        passwordHash: true,
        isActive: true,
      },
    });

    if (!user?.passwordHash) {
      throw new UnauthorizedException('Credenciales inválidas');
    }

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) throw new UnauthorizedException('Credenciales inválidas');

    if (!user.isActive) throw new UnauthorizedException('Cuenta desactivada');

    return this.buildTokenPair({
      id: user.id,
      email: user.email,
      role: user.role,
    });
  }

  async refresh(rawToken: string) {
    const refreshSecret =
      this.config.get<string>('JWT_REFRESH_SECRET') ??
      this.config.getOrThrow<string>('JWT_SECRET');

    let payload: JwtPayload;
    try {
      payload = this.jwt.verify<JwtPayload>(rawToken, {
        secret: refreshSecret,
      });
    } catch {
      throw new UnauthorizedException('Refresh token inválido o expirado');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      select: { id: true, email: true, role: true, isActive: true },
    });

    if (!user?.isActive) throw new UnauthorizedException('Cuenta desactivada');

    return this.buildTokenPair(user);
  }

  async getMe(userId: string) {
    return this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        phone: true,
        fullName: true,
        rut: true,
        role: true,
        kycStatus: true,
        avatarUrl: true,
        ratingAvg: true,
        ratingCount: true,
        isActive: true,
        createdAt: true,
      },
    });
  }

  private buildTokenPair(user: { id: string; email: string; role: UserRole }) {
    const payload: JwtPayload = {
      sub: user.id,
      email: user.email,
      role: user.role,
    };

    const refreshSecret =
      this.config.get<string>('JWT_REFRESH_SECRET') ??
      this.config.getOrThrow<string>('JWT_SECRET');

    const accessToken = this.jwt.sign(payload);
    const refreshToken = this.jwt.sign(payload, {
      secret: refreshSecret,
      expiresIn: '30d',
    });

    return { accessToken, refreshToken, tokenType: 'Bearer' as const };
  }
}
