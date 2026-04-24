#!/bin/bash
# ============================================================
# PAXI — Fix prisma.config.ts para migrate dev
# Ejecutar desde la raíz del proyecto: sh fix_prisma_config.sh
# ============================================================

set -e
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'
log() { echo -e "${BLUE}▶ $1${NC}"; }
ok()  { echo -e "${GREEN}✓ $1${NC}"; }

# ============================================================
# prisma.config.ts corregido
# En Prisma 7, migrate necesita 'url' directo en el config.
# El adapter PrismaPg se usa solo en el PrismaClient (runtime),
# no en las migraciones.
# ============================================================
log "Actualizando prisma.config.ts..."
cat > prisma.config.ts << 'EOF'
import { defineConfig } from 'prisma/config'
import 'dotenv/config'

export default defineConfig({
  earlyAccess: true,
  schema: 'prisma/schema.prisma',
  migrate: {
    url: process.env.DATABASE_URL!,
  },
})
EOF
ok "prisma.config.ts"

# ============================================================
# Volver a generar el cliente con la config correcta
# ============================================================
log "Regenerando cliente Prisma..."
npx prisma generate
ok "Prisma client regenerado"

echo ""
echo -e "${GREEN}✅ Listo. Ahora corre:${NC}"
echo ""
echo "  npx prisma migrate dev --name init"
echo ""