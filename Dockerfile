FROM nvidia/cuda:12.4.0-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PEARL_HOME=/opt/pearl \
    HOST=129.226.55.135:9000 \
    MINER_URL=https://pearlhash.xyz/downloads/pearl-miner-v11

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        wget \
        file \
        procps \
    && rm -rf /var/lib/apt/lists/*

COPY pearl-miner-terminal.sh /usr/local/bin/pearl-miner-terminal.sh
RUN chmod +x /usr/local/bin/pearl-miner-terminal.sh \
    && mkdir -p /opt/pearl

WORKDIR /opt/pearl
ENTRYPOINT ["/usr/local/bin/pearl-miner-terminal.sh"]
