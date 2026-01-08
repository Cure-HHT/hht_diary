# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: Pulumi IaC for portal deployment
#   REQ-p00042: Container deployment for portal
#   REQ-p01018: Security scanning compliance (non-root container)

# Multi-stage Dockerfile for Clinical Trial Portal
# Stage 1: Runtime (nginx serving static Flutter web build)

FROM nginx:alpine AS runtime

# Install wget for health checks
RUN apk add --no-cache wget

# Create non-root user for running nginx (security best practice)
# nginx:alpine already has nginx user (uid 101), but we need to ensure
# proper ownership and a writable pid file location for non-root execution
RUN mkdir -p /var/run/nginx /var/cache/nginx/client_temp /var/log/nginx && \
    chown -R nginx:nginx /var/run/nginx /var/cache/nginx /var/log/nginx && \
    chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /etc/nginx/conf.d && \
    # Update main nginx.conf to use non-root-writable pid file location
    sed -i 's|/var/run/nginx.pid|/var/run/nginx/nginx.pid|g' /etc/nginx/nginx.conf && \
    # Ensure nginx can write to the error log during startup
    touch /var/log/nginx/error.log /var/log/nginx/access.log && \
    chown nginx:nginx /var/log/nginx/error.log /var/log/nginx/access.log

# Copy Flutter web build output
COPY --chown=nginx:nginx build/web /usr/share/nginx/html

# Copy custom nginx configuration for SPA routing
COPY --chown=nginx:nginx nginx.conf /etc/nginx/conf.d/default.conf

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Expose port 8080 (Cloud Run expects 8080, >1024 allows non-root binding)
EXPOSE 8080

# Run as non-root user (security best practice - DS002)
USER nginx

# Start nginx in foreground
CMD ["nginx", "-g", "daemon off;"]
