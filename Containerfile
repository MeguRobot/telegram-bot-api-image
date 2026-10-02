FROM alpine:latest AS build
ENV CXXFLAGS=""

WORKDIR /usr/src/telegram-bot-api
RUN apk add --no-cache --update alpine-sdk linux-headers git zlib-dev openssl-dev gperf cmake
COPY telegram-bot-api /usr/src/telegram-bot-api

RUN mkdir -p build \
    && cd build \
    && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=.. .. \
    && cmake --build . --target install -j "$(nproc)" \
    && strip /usr/src/telegram-bot-api/bin/telegram-bot-api

FROM alpine:latest

ENV TELEGRAM_WORK_DIR="/var/lib/telegram-bot-api" \
    TELEGRAM_TEMP_DIR="/tmp/telegram-bot-api"

RUN apk add --no-cache --update openssl libstdc++

COPY --from=build /usr/src/telegram-bot-api/bin/telegram-bot-api /usr/local/bin/telegram-bot-api
COPY entrypoint.sh /entrypoint.sh

# The directories must be writable by any uid so the container also works when
# started as a non-root user (e.g. Podman rootless with `userns_mode: keep-id`
# or `--user`) on a freshly created named volume.
RUN chmod +x /entrypoint.sh \
    && mkdir -p "${TELEGRAM_WORK_DIR}" "${TELEGRAM_TEMP_DIR}" \
    && chmod 0777 "${TELEGRAM_WORK_DIR}" \
    && chmod 1777 "${TELEGRAM_TEMP_DIR}"

VOLUME ["/var/lib/telegram-bot-api"]

EXPOSE 8081/tcp 8082/tcp

ENTRYPOINT ["/entrypoint.sh"]
