import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Test, TestingModule } from '@nestjs/testing';
import { UserRole } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../../shared/database/prisma.service';
import { AuthService } from './auth.service';

jest.mock('bcrypt');
const bcryptMock = bcrypt as jest.Mocked<typeof bcrypt>;

describe('AuthService', () => {
  let service: AuthService;
  let userMock: {
    findUnique: jest.Mock;
    create: jest.Mock;
    findUniqueOrThrow: jest.Mock;
  };
  let jwtMock: jest.Mocked<Pick<JwtService, 'sign' | 'verify'>>;

  const dbUser = {
    id: 'uuid-driver-1',
    email: 'driver@paxi.cl',
    role: UserRole.driver,
    passwordHash: '$2b$12$hashedpassword',
    isActive: true,
  };

  beforeEach(async () => {
    userMock = {
      findUnique: jest.fn(),
      create: jest.fn(),
      findUniqueOrThrow: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: { user: userMock } },
        {
          provide: JwtService,
          useValue: { sign: jest.fn().mockReturnValue('mock.jwt'), verify: jest.fn() },
        },
        {
          provide: ConfigService,
          useValue: { get: jest.fn().mockReturnValue(null), getOrThrow: jest.fn().mockReturnValue('test-secret') },
        },
      ],
    }).compile();

    service = module.get(AuthService);
    jwtMock = module.get(JwtService);
  });

  afterEach(() => jest.clearAllMocks());

  // ── register ────────────────────────────────────────────────

  describe('register', () => {
    const dto = { email: 'new@paxi.cl', password: 'Password1!', fullName: 'Nuevo Usuario' };

    beforeEach(() => {
      userMock.findUnique.mockResolvedValue(null);
      userMock.create.mockResolvedValue({ id: 'uuid-new', email: dto.email, role: UserRole.passenger });
      bcryptMock.hash.mockResolvedValue('$2b$12$hashed' as never);
    });

    it('creates a user and returns an access + refresh token pair', async () => {
      const result = await service.register(dto);

      expect(result.accessToken).toBeDefined();
      expect(result.refreshToken).toBeDefined();
      expect(result.tokenType).toBe('Bearer');
    });

    it('defaults the role to passenger when not provided', async () => {
      await service.register(dto);

      expect(userMock.create).toHaveBeenCalledWith(
        expect.objectContaining({ data: expect.objectContaining({ role: UserRole.passenger }) }),
      );
    });

    it('hashes the password before persisting', async () => {
      await service.register(dto);

      expect(bcryptMock.hash).toHaveBeenCalledWith(dto.password, 12);
      expect(userMock.create).toHaveBeenCalledWith(
        expect.objectContaining({ data: expect.objectContaining({ passwordHash: '$2b$12$hashed' }) }),
      );
    });

    it('throws ConflictException when email is already registered', async () => {
      userMock.findUnique.mockResolvedValue(dbUser);

      await expect(service.register(dto)).rejects.toThrow(ConflictException);
      await expect(service.register(dto)).rejects.toThrow('Email ya registrado');
    });

    it('throws ConflictException when phone is already registered', async () => {
      userMock.findUnique
        .mockResolvedValueOnce(null)     // email → free
        .mockResolvedValueOnce(dbUser);  // phone → taken

      await expect(service.register({ ...dto, phone: '+56912345678' })).rejects.toThrow(
        new ConflictException('Teléfono ya registrado'),
      );
    });
  });

  // ── login ───────────────────────────────────────────────────

  describe('login', () => {
    it('returns tokens for correct credentials', async () => {
      userMock.findUnique.mockResolvedValue(dbUser);
      bcryptMock.compare.mockResolvedValue(true as never);

      const result = await service.login({ email: dbUser.email, password: 'correct' });

      expect(result.accessToken).toBeDefined();
    });

    it('throws UnauthorizedException when user does not exist', async () => {
      userMock.findUnique.mockResolvedValue(null);

      await expect(service.login({ email: 'ghost@paxi.cl', password: 'any' })).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it('throws UnauthorizedException when password is wrong', async () => {
      userMock.findUnique.mockResolvedValue(dbUser);
      bcryptMock.compare.mockResolvedValue(false as never);

      await expect(service.login({ email: dbUser.email, password: 'wrong' })).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it('throws UnauthorizedException when the account is inactive', async () => {
      userMock.findUnique.mockResolvedValue({ ...dbUser, isActive: false });
      bcryptMock.compare.mockResolvedValue(true as never);

      await expect(service.login({ email: dbUser.email, password: 'correct' })).rejects.toThrow(
        UnauthorizedException,
      );
    });
  });

  // ── refresh ─────────────────────────────────────────────────

  describe('refresh', () => {
    const jwtPayload = { sub: dbUser.id, email: dbUser.email, role: dbUser.role };

    it('issues a new token pair for a valid refresh token', async () => {
      (jwtMock.verify as jest.Mock).mockReturnValue(jwtPayload);
      userMock.findUnique.mockResolvedValue(dbUser);

      const result = await service.refresh('valid.refresh.token');

      expect(result.accessToken).toBeDefined();
      expect(jwtMock.verify).toHaveBeenCalledWith('valid.refresh.token', expect.any(Object));
    });

    it('throws UnauthorizedException for an invalid or expired token', async () => {
      (jwtMock.verify as jest.Mock).mockImplementation(() => { throw new Error('jwt expired'); });

      await expect(service.refresh('expired.token')).rejects.toThrow(UnauthorizedException);
    });

    it('throws UnauthorizedException when the user account is inactive', async () => {
      (jwtMock.verify as jest.Mock).mockReturnValue(jwtPayload);
      userMock.findUnique.mockResolvedValue({ ...dbUser, isActive: false });

      await expect(service.refresh('valid.token')).rejects.toThrow(UnauthorizedException);
    });
  });

  // ── getMe ───────────────────────────────────────────────────

  describe('getMe', () => {
    it('returns the user profile without the passwordHash field', async () => {
      const profile = {
        id: dbUser.id, email: dbUser.email, phone: '+56911111111',
        fullName: 'Carlos Pérez', rut: '12345678-9', role: UserRole.driver,
        kycStatus: 'pending', avatarUrl: null, ratingAvg: '5.00',
        ratingCount: 0, isActive: true, createdAt: new Date(),
      };
      userMock.findUniqueOrThrow.mockResolvedValue(profile);

      const result = await service.getMe(dbUser.id);

      expect(result).toEqual(profile);
      expect(result).not.toHaveProperty('passwordHash');
      expect(userMock.findUniqueOrThrow).toHaveBeenCalledWith(
        expect.objectContaining({ where: { id: dbUser.id } }),
      );
    });
  });
});
