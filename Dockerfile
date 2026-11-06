# syntax=docker/dockerfile:1.7
# CodeAlpha DevOps Task 1 — container image pushed to Azure Container Registry

########## Stage 1: test ##########
FROM node:22-alpine AS test
WORKDIR /src
COPY app/package.json ./
COPY app/src ./src
COPY app/public ./public
COPY app/test ./test
RUN npm test

########## Stage 2: runtime ##########
FROM node:22-alpine AS runtime

ARG APP_VERSION=dev
ARG BUILD_ID=local
ARG GIT_SHA=unknown

LABEL org.opencontainers.image.title="codealpha-azure-cicd" \
      org.opencontainers.image.description="CodeAlpha DevOps Task 1 - Azure Pipelines + ACR + App Service" \
      org.opencontainers.image.authors="Michael Gbenga Abajemito" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.revision="${GIT_SHA}"

ENV NODE_ENV=production \
    PORT=3000 \
    APP_VERSION=${APP_VERSION} \
    BUILD_ID=${BUILD_ID}

WORKDIR /app
# No third-party deps: copy only what runs (tests stay in the test stage)
COPY --chown=node:node app/package.json ./
COPY --chown=node:node app/src ./src
COPY --chown=node:node app/public ./public

USER 1000
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD ["wget", "-q", "--spider", "http://127.0.0.1:3000/health"]

CMD ["node", "src/server.js"]
