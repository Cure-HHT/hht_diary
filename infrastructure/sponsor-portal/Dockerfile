# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: Pulumi IaC for portal deployment
#   REQ-p00042: Container deployment for portal

# Multi-stage Dockerfile for Clinical Trial Portal
# Stage 1: Runtime (nginx serving static Flutter web build)

FROM nginx:alpine AS runtime

# Install wget for health checks
RUN apk add --no-cache wget

# Copy Flutter web build output
COPY build/web /usr/share/nginx/html

# Copy custom nginx configuration for SPA routing
COPY apps/portal-cloud/nginx.conf /etc/nginx/conf.d/default.conf

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Expose port 8080 (Cloud Run expects 8080)
EXPOSE 8080

# Start nginx in foreground
CMD ["nginx", "-g", "daemon off;"]
