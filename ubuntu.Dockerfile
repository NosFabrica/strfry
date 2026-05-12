FROM ubuntu:jammy as build

WORKDIR /build

ARG DEBCONF_NOWARNINGS="yes"
ARG DEBIAN_FRONTEND noninteractive
ARG DEBCONF_NONINTERACTIVE_SEEN true

RUN apt-get update && apt-get -y upgrade && \
    apt-get --no-install-recommends -y install \
    git g++ make pkg-config libtool ca-certificates \
    libssl-dev zlib1g-dev liblmdb-dev libflatbuffers-dev \
    libsecp256k1-dev libzstd-dev libhiredis-dev

COPY . .
RUN git submodule update --init
RUN make setup-golpe
RUN --mount=type=cache,target=/build/.cache \
    make -j4

FROM ubuntu:jammy AS runner
WORKDIR /app

RUN apt-get update && apt-get -y upgrade && \
    apt-get --no-install-recommends -y install \
    liblmdb0 libflatbuffers1 libsecp256k1-0 libb2-1 libzstd1 libhiredis0.14 curl python3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

HEALTHCHECK --interval=60s --retries=2 --timeout=10s CMD curl -ILfSs http://localhost:7777/ > /dev/null || exit 1

COPY strfry.sh /app/strfry.sh
COPY strfry.conf /etc/strfry.conf.default
COPY write-policy.py /app/write-policy.py
COPY strfry-router.conf /etc/strfry-router.conf

RUN chmod +x /app/strfry.sh
RUN chmod +x /app/write-policy.py

COPY --from=build /build/strfry strfry

EXPOSE 7777

CMD ["/app/strfry.sh"]
