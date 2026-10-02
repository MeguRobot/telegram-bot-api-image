# telegram-bot-api-image
[![Image build](https://github.com/MeguRobot/telegram-bot-api-image/actions/workflows/image.yml/badge.svg)](https://github.com/MeguRobot/telegram-bot-api-docker/actions/workflows/image.yml)
[![Docker Hub](https://img.shields.io/docker/v/megurobot/telegram-bot-api?sort=semver&logo=docker&label=docker%20hub)](https://hub.docker.com/r/megurobot/telegram-bot-api)
[![Docker pulls](https://img.shields.io/docker/pulls/megurobot/telegram-bot-api?logo=docker)](https://hub.docker.com/r/megurobot/telegram-bot-api)
[![Image size](https://img.shields.io/docker/image-size/megurobot/telegram-bot-api/latest?logo=docker)](https://hub.docker.com/r/megurobot/telegram-bot-api/tags)
[![GHCR](https://img.shields.io/badge/ghcr.io-megurobot%2Ftelegram--bot--api-2088ff?logo=github)](https://github.com/MeguRobot/telegram-bot-api-image/pkgs/container/telegram-bot-api)
[![Last commit](https://img.shields.io/github/last-commit/MeguRobot/telegram-bot-api-image?logo=github)](https://github.com/MeguRobot/telegram-bot-api-docker/commits/main)

This repository provides a Docker/Podman image for running a Telegram Bot API server on the latest Alpine Linux.

## Setup

### Prerequisites

Docker with Compose, or Podman with `podman compose`.

### Setup Steps

1. **Create a `compose.yml`** (see [compose.example.yml](compose.example.yml)):

```yaml
services:
  telegram-bot-api:
    container_name: telegram-bot-api
    image: megurobot/telegram-bot-api:latest
    restart: unless-stopped
    environment:
      TELEGRAM_API_ID: "123456"
      TELEGRAM_API_HASH: "abcdefghijklmnopqrstuvwyz123456789"
      TELEGRAM_STAT: "true"
      TELEGRAM_LOCAL: "true"
    volumes:
      - telegram-bot-api:/var/lib/telegram-bot-api
    networks:
      - telegram-bot-api
    expose:
      - "8081"
      - "8082"

volumes:
  telegram-bot-api:
    name: telegram-bot-api

networks:
  telegram-bot-api:
    name: telegram-bot-api
```

   Adjust the ports and environment variables as needed.

2. **Start it:**

```
docker compose up -d
# or
podman compose up -d
```

## Podman rootless

In rootless Podman, container `root` is your own user on the host, and any other
uid/gid inside the container is mapped to a sub-uid/gid (that is why a bind mount
used to end up owned by something like `10099`).

So, by default, the image **does not remap the uid/gid when it detects a user
namespace**: the server runs as container root, which is *you* on the host. Named
volumes and bind mounts both work with no extra configuration and the files stay
owned by your user.

- **Do not set** `USER_UID` / `USER_GID` in rootless mode.
- **Bind mounts:** create the folder first (`mkdir -p ./data`) and use
  `./data:/var/lib/telegram-bot-api`. On SELinux hosts add `:Z` (private) or `:z`
  (shared with other containers).
- **Run as non-root inside the container too (optional):** add
  `userns_mode: keep-id` to the service. The server then runs with your host
  uid/gid and files are still owned by you.
- If another container (e.g. your bot) reads the files in `TELEGRAM_LOCAL` mode,
  run both with the same user mapping (both default, or both `keep-id`).

For rootful Docker nothing changes: the server still drops privileges to
`USER_UID:USER_GID` (default `101:101`). Set `USER_UID=0` to keep running as root.

## Environment Variables

- `USER_UID`: (Optional) UID of the telegram-bot-api user (default: 101). Unset in rootless mode. `0` = do not drop privileges
- `USER_GID`: (Optional) GID of the telegram-bot-api group (default: 101). Unset in rootless mode
- `HTTP_PORT`: (Optional) HTTP port for the API (default: 8081)
- `STAT_PORT`: (Optional) HTTP stats port (default: 8082)
- `TELEGRAM_LOG_FILE`: (Optional) Path to the Telegram Bot API log file
- `TELEGRAM_STAT`: (Optional) Enable HTTP stats (true/false)
- `TELEGRAM_LOCAL`: (Optional) Enable local data storage (true/false)
- `TELEGRAM_FILTER`: (Optional) Filter for Telegram Bot API updates
- `TELEGRAM_MAX_WEBHOOK_CONNECTIONS`: (Optional) Maximum number of webhook connections
- `TELEGRAM_VERBOSITY`: (Optional) Verbosity level of the Telegram Bot API logs
- `TELEGRAM_MAX_CONNECTIONS`: (Optional) Maximum number of Telegram Bot API connections
- `TELEGRAM_PROXY`: (Optional) Proxy configuration for the Telegram Bot API
- `TELEGRAM_HTTP_IP_ADDRESS`: (Optional) HTTP IP address for the Telegram Bot API
