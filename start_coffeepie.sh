#!/bin/bash
# =============================================================================
# CoffeePie Startup Script — Radxa Zero 3 / Armbian + Sway
# =============================================================================
# Usage:
#   ./start_coffeepie.sh
#
# This script:
#   1. Starts XWayland on display :1 (X11 bridge for Sway/Wayland)
#   2. Grants Docker access to the display
#   3. Pulls the latest image from Docker Hub
#   4. Runs the CoffeePie container
# =============================================================================

set -e

DOCKER_IMAGE="juandaniel666/coffeepiefront:arm64"
CONTAINER_NAME="coffeepie"
DISPLAY_NUM=":1"
XWAYLAND_SOCKET="/tmp/.X11-unix/X1"
XDG_RUNTIME="/run/user/1000"

echo "============================================"
echo "  CoffeePie Startup"
echo "============================================"

# ── 1. Set Wayland environment ────────────────────────────────────────────────
export WAYLAND_DISPLAY=wayland-1
export XDG_RUNTIME_DIR=$XDG_RUNTIME
export DISPLAY=$DISPLAY_NUM

echo "[1/5] Wayland display: $WAYLAND_DISPLAY"

# ── 2. Start XWayland ─────────────────────────────────────────────────────────
echo "[2/5] Starting XWayland on $DISPLAY_NUM..."

# Kill any stale instance first
pkill -f "Xwayland $DISPLAY_NUM" 2>/dev/null || true
sleep 1

# Remove stale socket if it exists
if [ -S "$XWAYLAND_SOCKET" ]; then
    echo "      Removing stale socket $XWAYLAND_SOCKET"
    sudo rm -f "$XWAYLAND_SOCKET"
fi

# Start XWayland with no access control (-ac)
Xwayland $DISPLAY_NUM -ac &
XWAYLAND_PID=$!
sleep 2

# Verify it started
if [ ! -S "$XWAYLAND_SOCKET" ]; then
    echo "ERROR: XWayland did not create socket $XWAYLAND_SOCKET"
    echo "       Make sure xwayland is installed: sudo apt install xwayland"
    exit 1
fi
echo "      XWayland running (PID $XWAYLAND_PID)"

# ── 3. Grant Docker access to display ────────────────────────────────────────
echo "[3/5] Granting display access..."
xhost +local:docker

# ── 4. Pull latest image ──────────────────────────────────────────────────────
echo "[4/5] Pulling latest image from Docker Hub..."
docker pull $DOCKER_IMAGE

# ── 5. Run the container ──────────────────────────────────────────────────────
echo "[5/5] Starting container '$CONTAINER_NAME'..."

# Remove any existing stopped container with the same name
docker rm -f $CONTAINER_NAME 2>/dev/null || true

docker run \
    --name $CONTAINER_NAME \
    --network host \
    -e DISPLAY=$DISPLAY_NUM \
    -e QT_QPA_PLATFORM=xcb \
    -e QT_AUTO_SCREEN_SCALE_FACTOR=1 \
    -e QML_FULLSCREEN=1 \
    -e QT_SCALE_FACTOR=1 \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    $DOCKER_IMAGE

echo "============================================"
echo "  CoffeePie exited."
echo "============================================"
