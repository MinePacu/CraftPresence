FROM node:22-alpine AS build
WORKDIR /app
RUN npm install -g pnpm@9.15.0
COPY package.json pnpm-workspace.yaml tsconfig.json tsconfig.base.json vitest.config.ts drizzle.config.ts ./
COPY packages ./packages
COPY apps ./apps
RUN pnpm install --frozen-lockfile=false
RUN pnpm build

FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
RUN npm install -g pnpm@9.15.0
COPY package.json pnpm-workspace.yaml ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/packages ./packages
COPY --from=build /app/apps/server ./apps/server
COPY --from=build /app/apps/client/dist ./apps/client/dist
RUN mkdir -p /app/data/images
EXPOSE 8080
CMD ["node", "apps/server/dist/main.js"]
