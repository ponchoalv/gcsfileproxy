# Stage 1: Build the application
FROM node:16-alpine AS builder

WORKDIR /app

COPY package*.json ./
COPY package-lock.json ./
RUN npm install
COPY . .
RUN npm run build

# Stage 2: Create the production image
FROM node:16-alpine

WORKDIR /app

COPY package*.json ./
COPY package-lock.json ./
RUN npm install --omit=dev
COPY --from=builder /app/dist ./dist

ENV NODE_ENV=production

CMD ["node", "dist/index.js"]
