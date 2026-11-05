# Updated 2025-05-09: Modern Docker image for Flutter server app
FROM ghcr.io/cirruslabs/flutter:latest AS build

WORKDIR /app

# Copy pubspec files and get dependencies.
# The cnativeapi path override must exist before pub get.
COPY pubspec.* ./
COPY tool/cnativeapi/ tool/cnativeapi/
COPY tool/linux_native_deps/ tool/linux_native_deps/
RUN flutter pub get

# Copy the rest of the app
COPY . .

# Build the server/CLI app (example: bin/server.dart)
RUN mkdir -p /output && dart compile exe bin/tunnel_server.dart -o /output/server

# Final stage - slim image to run the server
FROM debian:bullseye-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /output/server /app/server

# Expose port if needed (example: 9001 for admin daemon)
EXPOSE 9001

# Default command to run the server
ENTRYPOINT ["/app/server"]
