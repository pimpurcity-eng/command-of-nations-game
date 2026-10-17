# Warfront Mandate match server (docs/MULTIPLAYER_SERVER.md).
# Build from the repository root:  docker build -f server/Dockerfile -t warfront-server .
FROM debian:bookworm-slim
ARG GODOT_VERSION=4.6.3
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip libfontconfig1 \
 && curl -fsSL -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
 && unzip /tmp/godot.zip -d /opt && mv /opt/Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot \
 && rm /tmp/godot.zip && apt-get purge -y curl unzip && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*
RUN useradd --create-home warfront
COPY --chown=warfront game /srv/game
USER warfront
WORKDIR /srv/game
# Import once at build time so the server starts quickly.
RUN godot --headless --path . --import
ENV WM_PORT=8910 WM_MATCH=main WM_MAP=regional WM_SPEED=1 WM_INACTIVE=172800
# Saves live in ~/.local/share/godot/app_userdata/<project>/matches: mount a volume there.
VOLUME ["/home/warfront/.local/share/godot"]
EXPOSE 8910
CMD ["godot", "--headless", "--path", ".", "--script", "res://scripts/net/server_main.gd"]
