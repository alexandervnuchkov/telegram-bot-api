ARG ALPINE_VERSION=latest
FROM alpine:${ALPINE_VERSION} as builder

RUN apk --no-cache add \
    build-base \
    cmake \
    openssl-dev \
    zlib-dev \
    gperf \
    linux-headers

WORKDIR /usr/src/telegram-bot-api

COPY upstream/CMakeLists.txt .
COPY upstream/td ./td
COPY upstream/telegram-bot-api ./telegram-bot-api
COPY entrypoint.sh ./entrypoint.sh

RUN  mkdir -p build \
 && cd build \
 && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=.. .. \
 && cmake --build . --target install -j "$(nproc)"\
 && strip /usr/src/telegram-bot-api/bin/telegram-bot-api

FROM alpine:${ALPINE_VERSION}

ENV TELEGRAM_WORK_DIR="/var/lib/telegram-bot-api" \
    TELEGRAM_TEMP_DIR="/tmp/telegram-bot-api"

RUN apk --no-cache --update add \
    libstdc++ \
    openssl

COPY --from=builder \
    /usr/src/telegram-bot-api/bin/telegram-bot-api \
    /usr/local/bin/telegram-bot-api

#COPY entrypoint.sh /entrypoint.sh

RUN addgroup -g 101 -S telegram-bot-api \
 && adduser -S -D -H -u 101 -h ${TELEGRAM_WORK_DIR} -s /sbin/nologin -G telegram-bot-api -g telegram-bot-api telegram-bot-api \
# && chmod +x /entrypoint.sh \
 && mkdir -p ${TELEGRAM_WORK_DIR} ${TELEGRAM_TEMP_DIR} \
 && chown telegram-bot-api:telegram-bot-api ${TELEGRAM_WORK_DIR} ${TELEGRAM_TEMP_DIR}

EXPOSE 8081/tcp 8082/tcp

HEALTHCHECK \
    --interval=5s \
    --timeout=30s \
    --retries=3 \
    CMD nc -z localhost 8081 || exit 1

#ENTRYPOINT ["/entrypoint.sh"]
ENTRYPOINT ["/usr/local/bin/telegram-bot-api"]