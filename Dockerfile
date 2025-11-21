FROM ubuntu:22.04

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libphonenumber-dev \
    libprotobuf-dev \
    libicu-dev \
    cmake \
    build-essential \
    wget \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Zig (using latest stable release)
ARG ZIG_VERSION=0.13.0
RUN wget https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz \
    && tar -xf zig-linux-x86_64-${ZIG_VERSION}.tar.xz \
    && mv zig-linux-x86_64-${ZIG_VERSION} /usr/local/zig \
    && ln -s /usr/local/zig/zig /usr/local/bin/zig \
    && rm zig-linux-x86_64-${ZIG_VERSION}.tar.xz

# Set working directory
WORKDIR /app

# Copy source code
COPY . .

# Build C++ wrapper
RUN chmod +x build_wrapper.sh && ./build_wrapper.sh

# Build Zig application
RUN zig build -Doptimize=ReleaseFast

# Expose port
EXPOSE 8080

# Run the application
CMD ["./zig-out/bin/phonecheck"]
