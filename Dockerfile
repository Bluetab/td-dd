### Minimal runtime image based on alpine:3.13
ARG RUNTIME_BASE=alpine:3.13

FROM ${RUNTIME_BASE}

LABEL maintainer="info@truedat.io"

ARG MIX_ENV=prod
ARG APP_VERSION
ARG APP_NAME

WORKDIR /app

COPY _build/${MIX_ENV}/*.tar.gz .

RUN apk --no-cache update && \
    apk --no-cache upgrade && \
    apk --no-cache add ncurses-libs openssl bash ca-certificates && \
    rm -rf /var/cache/apk/* && \
    tar -xzf *.tar.gz && \
    rm *.tar.gz && \
    adduser -h /app -D app && \
    chown -R app: /app

USER app

ENV APP_NAME ${APP_NAME}
ENTRYPOINT ["/bin/bash", "-c", "bin/start.sh"]
