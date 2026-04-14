


# Stage 1: Builder
FROM ubuntu:24.04 AS builder
 
ENV DEBIAN_FRONTEND=noninteractive \
    QT_VERSION=5 \
    CMAKE_VERSION=3.27
 
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    python3 \
    python3-pip \
    libgl1-mesa-dev \
    libxkbcommon-dev \
    libxkbcommon-x11-dev \
    libdbus-1-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libx11-dev \
    libxext-dev \
    libxfixes-dev \
    libxi-dev \
    libxrender-dev \
    libxrandr-dev \
    libxcursor-dev \
    libxtst-dev \
    libxinerama-dev \
    qtbase5-dev \
    qtdeclarative5-dev \
    qt5-qmake \
    libqt5core5a \
    libqt5gui5 \
    libqt5qml5 \
    libqt5network5 \
    libqt5dbus5 \
    libqt5widgets5 \
    libqt5sql5 \
    && rm -rf /var/lib/apt/lists/*
 
WORKDIR /build
COPY . .
 
RUN python3 -m pip install --no-cache-dir --break-system-packages -r requirements_current.txt
 
 
# -----------------------------------------------------------------------------
# Stage 2: Runtime
# -----------------------------------------------------------------------------
FROM ubuntu:24.04
 
ENV DEBIAN_FRONTEND=noninteractive \
   # DISPLAY=:0 \

   # --- Wayland display ---
    QT_QPA_PLATFORM=wayland \
    XDG_RUNTIME_DIR=/run/user/1000 \
    WAYLAND_DISPLAY=wayland-1 \
    QT_QPA_PLATFORM=xcb \
    QT_AUTO_SCREEN_SCALE_FACTOR=1 \
    QT_WAYLAND_DISABLE_WINDOWDECORATION=1 \
    QT_XCB_GL_INTEGRATION=none \
     # --- Rendering: try Panfrost (RK3566/Mali-G52) first, fall back to sw ---
    LIBGL_ALWAYS_SOFTWARE=0 \
    # --- Rendering: try Panfrost (RK3566/Mali-G52) first, fall back to sw ---
    PYOPENGL_PLATFORM=egl \
    QT_LOGGING_RULES="qt.qpa.*=false;qt.qpa.xcb.*=false" \
    LIBGL_ALWAYS_SOFTWARE=1 \
    PYOPENGL_PLATFORM=osmesa
 
# Runtime deps — xvfb and x11vnc removed (not needed for X11 forwarding)

# Stage 2 Runtime — fixed package names for Ubuntu 24.04
# Stage 2 Runtime — fixed package names for Ubuntu 24.04
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    python3 \
    python3-pip \
    ca-certificates \
    # --- OpenGL / EGL — FIXED names for Ubuntu 24.04 ---
    libgl1-mesa-dri \
    libgles2 \
    libegl1 \
    libegl-mesa0 \
    libosmesa6 \
    libglvnd0 \
    libglx0 \
    # --- Wayland ---
    libwayland-client0 \
    libwayland-egl1 \
    libwayland-cursor0 \
    # --- Qt5 Wayland plugin ---
    qtwayland5 \
    libqt5waylandclient5 \
    # --- Qt5 QML modules ---
    qml-module-qtquick2 \
    qml-module-qtquick-controls2 \
    qml-module-qtquick-layouts \
    qml-module-qtquick-window2 \
    # --- Input / fonts ---
    libxkbcommon0 \
    libxkbcommon-x11-0 \
    libfontconfig1 \
    libfreetype6 \
    fonts-dejavu-core \
    fontconfig-config \
    # --- DBus ---
    libdbus-1-3 \
    dbus \
    # --- GLib / GTK ---
    libglib2.0-0 \
    libgtk-3-0 \
    libpango-1.0-0 \
    libpangoft2-1.0-0 \
    libdbus-glib-1-2 \
    # --- X11 compat (Qt pulls even in Wayland mode) ---
    libx11-6 \
    libxext6 \
    libxrender1 \
    libxfixes3 \
    libxcb1 \
    # --- Audio ---
    libasound2t64 \
    # --- SSL / network ---
    libssl3 \
    libnss3 \
    libnspr4 \
    libsm6 \
    && rm -rf /var/lib/apt/lists/*
# Install browser depending on architecture:
#   amd64 → Google Chrome (real .deb from Google)
#   arm64 → Chromium from Debian repos (not a snap)
RUN ARCH=$(dpkg --print-architecture) && \
    echo "Detected architecture: $ARCH" && \
    if [ "$ARCH" = "amd64" ]; then \
        wget -q -O /tmp/google-chrome.deb \
            https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
        && apt-get update \
        && apt-get install -y /tmp/google-chrome.deb \
        && rm /tmp/google-chrome.deb \
        && rm -rf /var/lib/apt/lists/* ; \
    elif [ "$ARCH" = "arm64" ]; then \
        apt-get update \
        && apt-get install -y chromium chromium-driver \
        && rm -rf /var/lib/apt/lists/* ; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1 ; \
    fi






COPY --from=builder /build/CoffeePieContent       /app/CoffeePieContent
COPY --from=builder /build/requirements_current.txt /app/requirements_current.txt
 
RUN python3 -m pip install --no-cache-dir --break-system-packages -r /app/requirements_current.txt && \
    python3 -m pip install --no-cache-dir --break-system-packages -r /app/CoffeePieContent/python/requirements.txt
 
WORKDIR /app
 
# Direct entrypoint — talks to host X server via the mounted socket
ENTRYPOINT ["python3"]
CMD ["CoffeePieContent/python/main.py"]