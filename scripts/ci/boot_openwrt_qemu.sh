#!/usr/bin/env bash
set -eo pipefail

# OpenWrt QEMU Boot & Provisioning Script for CI Matrix
# Usage: ./boot_openwrt_qemu.sh <version> <image_url> <port>

VERSION="${1:-24.10.0}"
IMAGE_URL="${2:-https://downloads.openwrt.org/releases/24.10.0/targets/x86/64/openwrt-24.10.0-x86-64-generic-squashfs-combined.img.gz}"
HOST_PORT="${3:-8080}"

WORK_DIR="/tmp/openwrt_qemu_${VERSION}"
IMG_FILE="${WORK_DIR}/openwrt.img"

mkdir -p "${WORK_DIR}"
echo "==> Downloading OpenWrt ${VERSION} image from ${IMAGE_URL}..."
curl -sL -o "${WORK_DIR}/openwrt.img.gz" "${IMAGE_URL}"
gunzip -f "${WORK_DIR}/openwrt.img.gz"

echo "==> Booting OpenWrt ${VERSION} in QEMU (Host Port: ${HOST_PORT})..."

# Launch QEMU with port forwarding (host TCP port -> guest 80)
KVM_FLAG="-enable-kvm"
if [ ! -r /dev/kvm ] || [ ! -w /dev/kvm ]; then
    echo "Notice: /dev/kvm not writable, falling back to TCG mode"
    KVM_FLAG=""
fi

qemu-system-x86_64 \
    -m 256M \
    -smp 2 \
    -drive file="${IMG_FILE}",format=raw \
    -net nic,model=e1000 \
    -net user,hostfwd=tcp::${HOST_PORT}-:80 \
    -nographic \
    ${KVM_FLAG} > "${WORK_DIR}/qemu.log" 2>&1 &

QEMU_PID=$!
echo "${QEMU_PID}" > "${WORK_DIR}/qemu.pid"
echo "==> QEMU PID: ${QEMU_PID}"

# Wait for HTTP service / OpenWrt readiness (poll up to 45 seconds)
echo "==> Polling HTTP endpoint on 127.0.0.1:${HOST_PORT}..."
MAX_WAIT=45
WAIT_COUNT=0
READY=0

while [ ${WAIT_COUNT} -lt ${MAX_WAIT} ]; do
    if curl -s -m 2 "http://127.0.0.1:${HOST_PORT}/ubus" >/dev/null 2>&1 || \
       curl -s -m 2 "http://127.0.0.1:${HOST_PORT}/cgi-bin/luci" >/dev/null 2>&1; then
        READY=1
        break
    fi
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
done

if [ ${READY} -eq 1 ]; then
    echo "==> OpenWrt ${VERSION} successfully booted and responsive on port ${HOST_PORT} in ${WAIT_COUNT}s!"
else
    echo "==> WARNING: HTTP endpoint timeout after ${MAX_WAIT}s. QEMU log snippet:"
    tail -n 20 "${WORK_DIR}/qemu.log" || true
fi
