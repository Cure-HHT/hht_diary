# common-config/

Shared configuration assets used across multiple containers in this repository.

## Structure

```
common-config/
└── nginx/
    ├── common-http.conf       # Shared http { } level directives
    └── common-locations.conf  # Shared server { } location blocks
```

## nginx/

Contains nginx include fragments shared by:
- `apps/sponsor-portal/portal-container/` — listens on 8080, serves Flutter web UI + proxies to Dart API
- `apps/daily-diary/diary-server-container/` — listens on 8081, serves static assets only

### How includes work

Each container's `nginx.conf` uses nginx's `include` directive to pull in the shared fragments:

```nginx
http {
    include /etc/nginx/common-http.conf;     # shared http-level settings
    server {
        ...
        include /etc/nginx/common-locations.conf;  # shared location blocks
    }
}
```

Each container's Dockerfile COPYs both files to `/etc/nginx/` so the include paths resolve
correctly at runtime inside the container.

### Modifying shared config

Changes here affect **both** containers. Build and test both images after any change:

```bash
docker build -f apps/sponsor-portal/portal-container/Dockerfile -t portal-test . && docker run --rm portal-test nginx -t
docker build -f apps/daily-diary/diary-server-container/Dockerfile -t diary-test . && docker run --rm diary-test nginx -t
```

## Related files

| File | Purpose |
|------|---------|
| `apps/sponsor-portal/portal-container/nginx.conf` | Portal-specific: listen 8080, /health + /api/ proxy |
| `apps/daily-diary/diary-server-container/nginx.conf` | Diary-specific: listen 8081, static assets only |
| `apps/sponsor-portal/portal-container/Dockerfile` | COPYs common-http.conf + common-locations.conf |
| `apps/daily-diary/diary-server-container/Dockerfile` | COPYs common-http.conf + common-locations.conf |
