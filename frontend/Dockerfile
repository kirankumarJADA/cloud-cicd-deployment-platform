# syntax=docker/dockerfile:1

###############################################################################
# Stage 1 — Build the React app with Vite
###############################################################################
FROM node:20-alpine AS build
WORKDIR /app

# Install dependencies first for layer caching.
COPY package.json package-lock.json* ./
RUN npm ci || npm install

COPY . .
RUN npm run build

###############################################################################
# Stage 2 — Serve the static bundle with nginx
###############################################################################
FROM nginx:1.27-alpine AS runtime

# SPA-aware nginx config (history fallback + asset caching).
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

# wget is part of busybox in alpine; used by the container HEALTHCHECK.
HEALTHCHECK --interval=20s --timeout=4s --start-period=10s --retries=3 \
    CMD wget -q --spider http://127.0.0.1/ || exit 1
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
