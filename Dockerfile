FROM docker.io/debian:bookworm-slim AS builder

USER root

# Install necessary build tools and ca-certificates for curl/https.
# Use --no-install-recommends to keep the builder stage as lean as possible.
# Clean up apt lists to reduce size.
RUN apt-get update  \
    && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        jq \
    && rm -rf /var/lib/apt/lists/*

# Install oauth2-proxy
RUN set -x; \
    cd /tmp; \
    latest=$(curl -s "https://api.github.com/repos/oauth2-proxy/oauth2-proxy/releases/latest" | jq -r ". .tag_name" | sed 's/v//'); \
    curl -L "https://github.com/oauth2-proxy/oauth2-proxy/releases/download/v${latest}/oauth2-proxy-v${latest}.linux-amd64.tar.gz" --output oauth2-proxy.tar.gz; \
    tar zxvf oauth2-proxy.tar.gz; \
    cp oauth2-proxy-v${latest}.linux-amd64/oauth2-proxy /usr/local/bin/oauth2-proxy; \
    chmod 755 /usr/local/bin/oauth2-proxy

# Stage 2: Final distroless image
# Using distroless/base-debian12 because helm, uv, and kubectl are dynamically linked
# and require a C standard library (glibc), which is provided by this image.
FROM gcr.io/distroless/cc-debian12

# Copy the compiled binaries from the builder stage into the final image.
COPY --from=builder /usr/local/bin/oauth2-proxy /usr/local/bin/oauth2-proxy

# Set user and group to a non-root user (e.g., UID 1000, GID 1000).
# Distroless images do not have useradd/groupadd, so we specify numeric IDs.
# This aligns with the original intent of running as a non-root 'kubectl' user.
USER 1000:1000

CMD ['/usr/local/bin/oauth2-proxy']