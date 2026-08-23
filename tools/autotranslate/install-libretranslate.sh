#!/usr/bin/env bash
#
# Stands up LibreTranslate (Russian <-> English only) as a systemd-managed
# Docker container, bound to loopback, resource-capped so it can never starve
# Dream Daemon on a small box.
#
# Tested target: Linux, 2 cores / 6 GB, Docker + systemd.
#
# Usage:  sudo ./install-libretranslate.sh
#
set -euo pipefail

IMAGE="libretranslate/libretranslate:latest"
CONTAINER="libretranslate"
VOLUME="libretranslate-models"
BIND_ADDR="127.0.0.1"
BIND_PORT="5000"
LANGS="en,ru"

# Resource caps. IMPORTANT: these go on `docker run`, not on the systemd unit.
# The container runs in Docker's cgroup hierarchy, not the unit's, so
# MemoryMax=/CPUQuota= in the [Service] section would silently do nothing.
MEM_LIMIT="2g"
CPU_LIMIT="0.5"
# Default share weight is 1024. At 256 the kernel gives Dream Daemon roughly
# four times the CPU under contention, so the game always wins.
CPU_SHARES="256"

# LibreTranslate's RSS creeps upward and never comes back down. On a 6 GB box
# that eventually matters, so systemd cycles the container periodically.
# In-flight requests are dropped; they time out and the message just stays in
# its original language.
RESTART_EVERY_SEC="21600" # 6 hours

UNIT_PATH="/etc/systemd/system/${CONTAINER}.service"

# --- preflight ---------------------------------------------------------------

if [[ "${EUID}" -ne 0 ]]; then
	echo "error: run this with sudo." >&2
	exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
	echo "error: docker is not installed or not on PATH." >&2
	exit 1
fi

DOCKER_BIN="$(command -v docker)"

if ! systemctl --version >/dev/null 2>&1; then
	echo "error: systemd not detected." >&2
	exit 1
fi

# --- image and model volume --------------------------------------------------

echo ">> pulling ${IMAGE}"
docker pull "${IMAGE}"

# Named volume for the Argos model files. The image ships with no models -
# they are downloaded on first boot - so without this every recreate pulls
# them down again.
if ! docker volume inspect "${VOLUME}" >/dev/null 2>&1; then
	echo ">> creating model volume ${VOLUME}"
	docker volume create "${VOLUME}" >/dev/null
fi

# The image runs as an unprivileged user, but Docker creates a fresh named
# volume owned by root. argostranslate then cannot create its packages/
# directory inside it and the container crash-loops on a PermissionError -
# which surfaces confusingly as "Error: '' is not a valid port number",
# because the entrypoint's argument parser dies on the same exception.
# Read the uid/gid out of the image rather than hardcoding them.
LT_UID="$(docker run --rm --entrypoint id "${IMAGE}" -u libretranslate)"
LT_GID="$(docker run --rm --entrypoint id "${IMAGE}" -g libretranslate)"
echo ">> setting model volume ownership to ${LT_UID}:${LT_GID}"
docker run --rm -u root -v "${VOLUME}:/data" \
	--entrypoint chown "${IMAGE}" -R "${LT_UID}:${LT_GID}" /data

# --- unit --------------------------------------------------------------------

echo ">> writing ${UNIT_PATH}"
cat > "${UNIT_PATH}" <<UNIT
[Unit]
Description=LibreTranslate (RU<->EN) for SS13 auto-translation
Documentation=https://docs.libretranslate.com
After=docker.service network-online.target
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=10
# First boot downloads the language models, which is not fast.
TimeoutStartSec=900
RuntimeMaxSec=${RESTART_EVERY_SEC}

ExecStartPre=-${DOCKER_BIN} rm -f ${CONTAINER}
ExecStart=${DOCKER_BIN} run --rm --name ${CONTAINER} \\
	-p ${BIND_ADDR}:${BIND_PORT}:5000 \\
	--memory=${MEM_LIMIT} --memory-swap=${MEM_LIMIT} \\
	--cpus=${CPU_LIMIT} --cpu-shares=${CPU_SHARES} \\
	-e LT_LOAD_ONLY=${LANGS} \\
	-e LT_DISABLE_WEB_UI=true \\
	-e LT_UPDATE_MODELS=false \\
	-e LT_THREADS=1 \\
	-v ${VOLUME}:/home/libretranslate/.local/share/argos-translate \\
	${IMAGE}
ExecStop=${DOCKER_BIN} stop --time 15 ${CONTAINER}

[Install]
WantedBy=multi-user.target
UNIT

# --- start -------------------------------------------------------------------

echo ">> enabling and starting"
systemctl daemon-reload
systemctl enable "${CONTAINER}.service"
systemctl restart "${CONTAINER}.service"

echo -n ">> waiting for the endpoint to answer (first run downloads models)"
DEADLINE=$(( SECONDS + 900 ))
until curl -sf "http://${BIND_ADDR}:${BIND_PORT}/languages" >/dev/null 2>&1; do
	if (( SECONDS > DEADLINE )); then
		echo
		echo "error: endpoint did not come up in time. Check: journalctl -u ${CONTAINER} -n 50" >&2
		exit 1
	fi
	echo -n "."
	sleep 5
done
echo " up."

# --- verify ------------------------------------------------------------------

echo ">> smoke test"
curl -sf -X POST "http://${BIND_ADDR}:${BIND_PORT}/translate" \
	-H 'Content-Type: application/json' \
	-d '{"q":"привет, где сб?","source":"ru","target":"en","format":"text"}'
echo
echo

cat <<NEXT
Done.

Add to config/game_options.txt:

    TRANSLATE_HTTP_URL http://${BIND_ADDR}:${BIND_PORT}
    TRANSLATE_HTTP_TIMEOUT_SECONDS 5

Then restart the server. SSautotranslate probes the endpoint at init; if it
does not answer, translation stays off for the round and nothing else breaks.

Useful commands:
    systemctl status ${CONTAINER}
    journalctl -u ${CONTAINER} -f
    docker stats ${CONTAINER}          # watch RSS creep
    systemctl stop ${CONTAINER} && systemctl disable ${CONTAINER}
NEXT
