# ── Stage 1: Builder ────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app

COPY package*.json ./
COPY prisma ./prisma/
RUN npm ci

COPY . .
ARG DATABASE_URL=postgresql://dummy:dummy@localhost:5432/dummy
ENV DATABASE_URL=$DATABASE_URL
RUN npx prisma generate
RUN npm run build

# ── Stage 2: Runner ─────────────────────────────────────────
FROM node:20-alpine AS runner
WORKDIR /app

ARG NODE_ENV=production
ARG GIT_SHA=unknown
ENV NODE_ENV=${NODE_ENV}
ENV GIT_SHA=${GIT_SHA}

COPY package*.json ./
COPY prisma ./prisma/
RUN npm ci --only=production && npm cache clean --force

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma

EXPOSE 3000
USER node
CMD ["node", "dist/main.js"]
