# apps/common-config/

Shared configuration assets used across multiple containers in this repository.

## Structure

```
apps/common-config/
└── nginx/
    ├── common-http.conf       # Shared http { } level directives
    └── common-locations.conf  # Shared server { } location blocks
```

## nginx/

Contains nginx include fragments used by:
- `apps/daily-diary/diary-server-container/` — listens on 8081, serves static assets only

Previously also consumed by `apps/sponsor-portal/portal-container/`, which was removed when the portal deployment moved to the sponsor-owned Callisto `portal-final` image (see `hht_diary_callisto/deployment/docker/portal-final.Dockerfile`).

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

Build and test the diary container after any change:

```bash
docker build -f apps/daily-diary/diary-server-container/Dockerfile -t diary-test . && docker run --rm diary-test nginx -t
```

## Related files

| File | Purpose |
| ------ | ------- |
| `apps/daily-diary/diary-server-container/nginx.conf` | Diary-specific: listen 8081, static assets only |
| `apps/daily-diary/diary-server-container/Dockerfile` | COPYs common-http.conf + common-locations.conf |
