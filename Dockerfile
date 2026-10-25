# Build stage & production container for Release Console
FROM node:20-alpine

# Set dedicated working directory
WORKDIR /app

# Ensure non-root ownership of app directory
RUN chown -R node:node /app

# Accept build arguments for release versioning
ARG APP_VERSION=dev-local
ARG GIT_COMMIT=local-dev-commit

# Set production environment variables
ENV NODE_ENV=production \
    PORT=3000 \
    DEPLOY_ENV=minikube-local \
    APP_VERSION=${APP_VERSION} \
    GIT_COMMIT=${GIT_COMMIT}

# Copy package manifests first for efficient layer caching
COPY --chown=node:node package.json package-lock.json ./

# Install production dependencies reproducibly
RUN npm ci --only=production --ignore-scripts && npm cache clean --force

# Copy application source code and public assets
COPY --chown=node:node src/ ./src/
COPY --chown=node:node public/ ./public/

# Switch to non-root user for security compliance
USER node

# Expose internal application port
EXPOSE 3000

# Container entry point
CMD ["node", "src/index.js"]
