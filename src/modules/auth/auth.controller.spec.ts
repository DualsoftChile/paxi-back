import { Test, TestingModule } from '@nestjs/testing';
import { UserRole } from '@prisma/client';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import type { AuthUser } from './interfaces/auth-user.interface';

describe('AuthController', () => {
  let controller: AuthController;
  let service: jest.Mocked<
    Pick<AuthService, 'register' | 'login' | 'refresh' | 'getMe'>
  >;

  const mockTokens = {
    accessToken: 'access.token',
    refreshToken: 'refresh.token',
    tokenType: 'Bearer' as const,
  };

  beforeEach(async () => {
    service = {
      register: jest.fn().mockResolvedValue(mockTokens),
      login: jest.fn().mockResolvedValue(mockTokens),
      refresh: jest.fn().mockResolvedValue(mockTokens),
      getMe: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [{ provide: AuthService, useValue: service }],
    }).compile();

    controller = module.get(AuthController);
  });

  afterEach(() => jest.clearAllMocks());

  it('should be defined', () => expect(controller).toBeDefined());

  it('register — delegates to AuthService and returns token pair', async () => {
    const dto = { email: 'new@paxi.cl', password: 'Pass1!', fullName: 'Test' };

    const result = await controller.register(dto);

    expect(service.register).toHaveBeenCalledWith(dto);
    expect(result).toEqual(mockTokens);
  });

  it('login — delegates to AuthService and returns token pair', async () => {
    const dto = { email: 'test@paxi.cl', password: 'Pass1!' };

    const result = await controller.login(dto);

    expect(service.login).toHaveBeenCalledWith(dto);
    expect(result).toEqual(mockTokens);
  });

  it('refresh — extracts refreshToken string and delegates to AuthService', async () => {
    const result = await controller.refresh({
      refreshToken: 'my.refresh.token',
    });

    expect(service.refresh).toHaveBeenCalledWith('my.refresh.token');
    expect(result).toEqual(mockTokens);
  });

  it('getMe — passes user.id to AuthService and returns profile', async () => {
    const user: AuthUser = {
      id: 'uuid-1',
      email: 'me@paxi.cl',
      role: UserRole.passenger,
    };
    const profile = { ...user, fullName: 'Me', createdAt: new Date() };
    service.getMe.mockResolvedValue(profile as never);

    const result = await controller.getMe(user);

    expect(service.getMe).toHaveBeenCalledWith('uuid-1');
    expect(result).toEqual(profile);
  });
});
