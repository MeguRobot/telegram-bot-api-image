#!/bin/sh
set -e

USERNAME=telegram-bot-api
GROUPNAME=telegram-bot-api
HTTP_PORT=${HTTP_PORT:-8081}
STAT_PORT=${STAT_PORT:-8082}
TELEGRAM_WORK_DIR=${TELEGRAM_WORK_DIR:-/var/lib/telegram-bot-api}
TELEGRAM_TEMP_DIR=${TELEGRAM_TEMP_DIR:-/tmp/telegram-bot-api}

is_true() {
    case "$1" in
        [Tt][Rr][Uu][Ee] | 1 | [Yy][Ee][Ss]) return 0 ;;
        *) return 1 ;;
    esac
}

in_user_namespace() {
    [ -r /proc/self/uid_map ] || return 1
    read -r inside outside count < /proc/self/uid_map
    [ "${inside} ${outside} ${count}" != "0 0 4294967295" ]
}

DROP_PRIVILEGES=false

if [ "$(id -u)" -ne 0 ]; then
    echo "Running as uid=$(id -u) gid=$(id -g); skipping user setup"
elif [ -z "${USER_UID}${USER_GID}" ] && in_user_namespace; then
    echo "Rootless container detected; running as the host user (no uid/gid remap)"
else
    USER_UID=${USER_UID:-101}
    USER_GID=${USER_GID:-101}
    # USER_UID=0 explicitly means "do not drop privileges".
    if [ "${USER_UID}" -ne 0 ]; then
        DROP_PRIVILEGES=true
    fi
fi

if [ "${DROP_PRIVILEGES}" = true ]; then
    if ! getent group "${USER_GID}" > /dev/null; then
        addgroup -g "${USER_GID}" -S "${GROUPNAME}"
    fi
    GROUPNAME=$(getent group "${USER_GID}" | cut -d: -f1)

    if ! getent passwd "${USER_UID}" > /dev/null; then
        adduser -S -D -H -u "${USER_UID}" -h "${TELEGRAM_WORK_DIR}" -s /sbin/nologin -G "${GROUPNAME}" "${USERNAME}"
    fi
    USERNAME=$(getent passwd "${USER_UID}" | cut -d: -f1)
fi

mkdir -p "${TELEGRAM_WORK_DIR}" "${TELEGRAM_TEMP_DIR}"

if [ "${DROP_PRIVILEGES}" = true ]; then
    for dir in "${TELEGRAM_WORK_DIR}" "${TELEGRAM_TEMP_DIR}"; do
        if [ "$(stat -c '%u:%g' "${dir}")" != "${USER_UID}:${USER_GID}" ]; then
            chown -R "${USER_UID}:${USER_GID}" "${dir}"
        fi
    done
elif [ ! -w "${TELEGRAM_WORK_DIR}" ]; then
    echo "ERROR: ${TELEGRAM_WORK_DIR} is not writable by uid=$(id -u) gid=$(id -g)." >&2
    echo "Rootless Podman: leave USER_UID/USER_GID unset, or use 'userns_mode: keep-id'" >&2
    echo "and make sure the bind mount is owned by your user." >&2
    exit 1
fi

if [ -n "$1" ]; then
    exec "$@"
fi

set -- telegram-bot-api \
    --http-port "${HTTP_PORT}" \
    --dir="${TELEGRAM_WORK_DIR}" \
    --temp-dir="${TELEGRAM_TEMP_DIR}"

if [ "${DROP_PRIVILEGES}" = true ]; then
    set -- "$@" --username="${USERNAME}" --groupname="${GROUPNAME}"
fi

[ -n "${TELEGRAM_LOG_FILE}" ] && set -- "$@" --log="${TELEGRAM_LOG_FILE}"
is_true "${TELEGRAM_STAT}" && set -- "$@" --http-stat-port="${STAT_PORT}"
is_true "${TELEGRAM_LOCAL}" && set -- "$@" --local
[ -n "${TELEGRAM_FILTER}" ] && set -- "$@" --filter="${TELEGRAM_FILTER}"
[ -n "${TELEGRAM_MAX_WEBHOOK_CONNECTIONS}" ] && set -- "$@" --max-webhook-connections="${TELEGRAM_MAX_WEBHOOK_CONNECTIONS}"
[ -n "${TELEGRAM_VERBOSITY}" ] && set -- "$@" --verbosity="${TELEGRAM_VERBOSITY}"
[ -n "${TELEGRAM_MAX_CONNECTIONS}" ] && set -- "$@" --max-connections="${TELEGRAM_MAX_CONNECTIONS}"
[ -n "${TELEGRAM_PROXY}" ] && set -- "$@" --proxy="${TELEGRAM_PROXY}"
[ -n "${TELEGRAM_HTTP_IP_ADDRESS}" ] && set -- "$@" --http-ip-address="${TELEGRAM_HTTP_IP_ADDRESS}"

echo "$*"
exec "$@"
