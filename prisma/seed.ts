import { KycStatus, PrismaClient, UserRole } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import * as bcrypt from 'bcrypt';
import pg from 'pg';

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

const HASH_ROUNDS = 12;

const users = [
  {
    email: 'admin@paxi.cl',
    password: 'Admin1234!',
    fullName: 'Admin PAXI',
    phone: '+56912345678',
    role: UserRole.admin,
    kycStatus: KycStatus.approved,
  },
  {
    email: 'driver@paxi.cl',
    password: 'Driver1234!',
    fullName: 'Carlos Pérez',
    phone: '+56987654321',
    rut: '12345678-9',
    role: UserRole.driver,
    kycStatus: KycStatus.approved,
  },
  {
    email: 'passenger@paxi.cl',
    password: 'Passenger1234!',
    fullName: 'María González',
    phone: '+56976543210',
    rut: '98765432-1',
    role: UserRole.passenger,
    kycStatus: KycStatus.approved,
  },
];

async function main() {
  console.log('🌱 Seeding database...\n');

  for (const u of users) {
    const passwordHash = await bcrypt.hash(u.password, HASH_ROUNDS);

    const user = await prisma.user.upsert({
      where: { email: u.email },
      update: { passwordHash },
      create: {
        email: u.email,
        fullName: u.fullName,
        phone: u.phone,
        rut: u.rut ?? null,
        passwordHash,
        role: u.role,
        kycStatus: u.kycStatus,
      },
    });

    console.log(`✅  ${u.role.padEnd(10)} ${user.email}  (password: ${u.password})`);
  }

  console.log('\n🚕 Seed completado.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
    await pool.end();
  });
