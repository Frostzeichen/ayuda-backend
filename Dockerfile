# --- Stage 1: Build (Compiler Environment) ---
FROM rust:1.81-slim-bookworm AS builder

WORKDIR /app

# Install dependencies required for compiling Rust crypto/SSL crates
RUN apt-get update && apt-get install -y \
  curl \
  pkg-config \
  libssl-dev \
  && rm -rf /var/lib/apt/lists/*

# Copy your source code
COPY . .

# Build the release binary
# (This creates /target/release/backend)
RUN cargo build --release

# Install Stellar CLI by downloading the pre-built binary directly.
# Pinned to a specific release to avoid GitHub API rate limits during CI builds.
RUN curl -Lsf https://github.com/stellar/stellar-cli/releases/download/v26.0.0/stellar-cli-26.0.0-x86_64-unknown-linux-gnu.tar.gz \
    | tar -xz -C /usr/local/bin stellar

# --- Stage 2: Runtime (Production Environment) ---
FROM debian:bookworm-slim

WORKDIR /app

# 1. Install runtime dependencies for SSL
RUN apt-get update && apt-get install -y \
  ca-certificates \
  libssl3 \
  && rm -rf /var/lib/apt/lists/*

# 2. Copy the Stellar CLI binary from the builder stage
COPY --from=builder /usr/local/bin/stellar /usr/local/bin/stellar

# 3. Copy only the compiled binary from the builder stage
COPY --from=builder /app/target/release/backend /usr/local/bin/ayuda-backend

# 4. Networking
# Render provides the $PORT variable automatically.
ENV PORT=10000
EXPOSE 10000

# 5. Start the application
CMD ["ayuda-backend"]
