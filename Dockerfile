# ══════════════════════════════════════════════════════════════════════════════
#  PayrollPro — Multi-Stage Dockerfile
#  Stage 1 (builder): Installs deps and builds the React app with Vite
#  Stage 2 (runner):  Runs the Express server, which serves both
#                     the /api routes AND the built React static files
# ══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────
#  Stage 1 · Build React frontend
# ─────────────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /build

# Copy frontend source
COPY react-app/package*.json ./react-app/
RUN cd react-app && npm ci --legacy-peer-deps

COPY react-app/ ./react-app/

# Build Vite production bundle → react-app/dist/
RUN cd react-app && npm run build

# ─────────────────────────────────────────────────────────────────────────────
#  Stage 2 · Production Express server
# ─────────────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS runner

WORKDIR /app

# Install only production server dependencies
COPY server/package*.json ./
RUN npm ci --omit=dev

# Copy Express server code
COPY server/index.js ./

# Copy the built React app into /app/public
# (Express serves this as static files — see index.js STATIC_DIR)
COPY --from=builder /build/react-app/dist ./public

# Back4App injects PORT via environment variable
# Default fallback is 8080 (Back4App standard)
ENV NODE_ENV=production
ENV PORT=8080

EXPOSE 8080

# Health-check so Back4App knows the container is ready
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD wget -qO- http://localhost:8080/api/health || exit 1

CMD ["node", "index.js"]
