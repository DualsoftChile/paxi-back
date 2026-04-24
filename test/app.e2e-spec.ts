import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from '../src/app.module';

describe('Auth (e2e)', () => {
  let app: INestApplication<App>;

  const email = `e2e-${Date.now()}@paxi.cl`;
  const password = 'E2eTest1234!';
  let accessToken: string;
  let refreshToken: string;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
    );
    await app.init();

    // Registra el usuario que usarán los tests dependientes
    const res = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send({ email, password, fullName: 'E2E Test User' });

    accessToken = res.body.accessToken as string;
    refreshToken = res.body.refreshToken as string;
  });

  afterAll(() => app.close());

  // ── POST /register ──────────────────────────────────────────

  describe('POST /api/v1/auth/register', () => {
    it('returns 409 when email is already registered', () => {
      return request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({ email, password, fullName: 'Duplicate' })
        .expect(409);
    });

    it('returns 400 when email format is invalid', () => {
      return request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({ email: 'not-an-email', password, fullName: 'Bad Email' })
        .expect(400);
    });

    it('returns 400 when password is shorter than 8 characters', () => {
      return request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({ email: `short-pw-${Date.now()}@paxi.cl`, password: '1234567', fullName: 'Short' })
        .expect(400);
    });
  });

  // ── POST /login ─────────────────────────────────────────────

  describe('POST /api/v1/auth/login', () => {
    it('returns 200 with token pair for valid credentials', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email, password })
        .expect(200);

      expect(res.body.accessToken).toBeDefined();
      expect(res.body.tokenType).toBe('Bearer');
    });

    it('returns 401 for wrong password', () => {
      return request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email, password: 'wrong-password-xyz' })
        .expect(401);
    });

    it('returns 401 for unknown email', () => {
      return request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'nobody@paxi.cl', password })
        .expect(401);
    });
  });

  // ── POST /refresh ───────────────────────────────────────────

  describe('POST /api/v1/auth/refresh', () => {
    it('returns 200 with a new token pair for a valid refresh token', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/refresh')
        .send({ refreshToken })
        .expect(200);

      expect(res.body.accessToken).toBeDefined();
    });

    it('returns 401 for a malformed token', () => {
      return request(app.getHttpServer())
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: 'garbage.token.value' })
        .expect(401);
    });
  });

  // ── GET /me ─────────────────────────────────────────────────

  describe('GET /api/v1/auth/me', () => {
    it('returns 200 with user profile for a valid Bearer token', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/auth/me')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(res.body.email).toBe(email);
      expect(res.body.role).toBe('passenger');
      expect(res.body).not.toHaveProperty('passwordHash');
    });

    it('returns 401 when no Authorization header is sent', () => {
      return request(app.getHttpServer()).get('/api/v1/auth/me').expect(401);
    });

    it('returns 401 for an invalid token', () => {
      return request(app.getHttpServer())
        .get('/api/v1/auth/me')
        .set('Authorization', 'Bearer invalid.token.here')
        .expect(401);
    });
  });
});
