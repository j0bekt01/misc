# syntax=docker/dockerfile:1.7

# Dockerfile to easily build ConnectorX Python wheel for Linux ARM64/aarch64 architecture,
# with configurable versions of Python, ConnectorX, and Rust.
#
# https://sfu-db.github.io/connector-x/install.html#build-from-source-code
#
# To find the required Rust toolchain version, check under 'linux-aarch':
# https://github.com/sfu-db/connector-x/blob/main/.github/workflows/release.yml
#
# Usage:
# To build the Docker image with default versions:
#     DOCKER_BUILDKIT=1 docker build --output type=local,dest=./wheels -t connectorx-arm64 .
#
# To build the Docker image with specific versions:
#     DOCKER_BUILDKIT=1 docker build --output type=local,dest=./wheels \
#         --build-arg PYTHON_VERSION=3.12.3 \
#         --build-arg CONNECTORX_VERSION=0.3.3 \
#         --build-arg RUST_VERSION=1.71.1 \
#         -t connectorx-arm64 .
#
# Output:
# The built .whl file will be copied to the /wheels directory, 
# which will be in the same directory as this Dockerfile (your working directory).

ARG PYTHON_VERSION=3.9.19
ARG CONNECTORX_VERSION=0.3.3
ARG RUST_VERSION=1.78.0

FROM arm64v8/python:3.9.19-bookworm AS builder

ARG PYTHON_VERSION
ARG CONNECTORX_VERSION
ARG RUST_VERSION

# Install dependencies
RUN apt-get update && apt-get install -y --fix-missing \
    libmariadb-dev-compat \
    libmariadb-dev \
    freetds-dev \
    libpq-dev \
    wget \
    curl \
    build-essential \
    libkrb5-dev \
    clang \
    git && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create workspace directory
RUN mkdir /workspace
WORKDIR /workspace

# Install rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs --insecure | bash -s -- -y --default-toolchain ${RUST_VERSION}
ENV PATH="/root/.cargo/bin:/usr/local/bin:$PATH"
RUN rustc 
RUN cargo
# Install Python from source
# RUN wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz && \
#     tar -xvf Python-${PYTHON_VERSION}.tgz && \
#     cd Python-${PYTHON_VERSION} && \
#     ./configure --enable-optimizations && \
#     make install && \
#     cd .. && rm -rf Python-${PYTHON_VERSION}*

# Install poetry and maturin
# RUN ln -s /usr/local/bin/pip3 /usr/local/bin/pip 
RUN pip install --no-cache-dir poetry maturin[patchelf]

# Clone the connectorx repo at the specified tag
RUN git clone --depth 1 --branch v${CONNECTORX_VERSION} https://github.com/sfu-db/connector-x.git
WORKDIR /workspace/connector-x

# Build the python wheel through maturin
RUN maturin build -m connectorx-python/Cargo.toml -i python3 --release

# Copy the built wheel to the output directory
FROM scratch AS output
COPY --from=builder /workspace/connector-x/connectorx-python/target/wheels /