# ---- Copy Files/Build ----
FROM elixir:1.5.2-alpine AS build

MAINTAINER True-Dat Dev Team

RUN apk --no-cache update \
    && apk --no-cache add git make g++ \
    &&  rm -fr /var/cache/apk/*

# MS Logic
RUN mkdir /build
WORKDIR /build
COPY . /build

ARG MIX_ENV
ARG APP_VERSION
ARG APP_NAME

RUN mix local.hex --force
RUN mix local.rebar --force

RUN mix deps.get
RUN MIX_ENV=${MIX_ENV} mix phx.swagger.generate priv/static/swagger.json

RUN mix release --env=${MIX_ENV}

# --- Release with Alpine ----
### Minimal run-time image
FROM alpine:latest

RUN apk --no-cache update && apk --no-cache upgrade && apk --no-cache add ncurses-libs openssl bash ca-certificates

ARG MIX_ENV
ARG APP_VERSION
ARG APP_NAME

ENV APP_NAME ${APP_NAME}

WORKDIR /app

COPY --from=build /build/_build/${MIX_ENV}/rel/${APP_NAME}/releases/${APP_VERSION}/*.tar.gz ./

RUN tar -xzvf ${APP_NAME}.tar.gz

ENTRYPOINT ["/bin/bash", "-c", "bin/${APP_NAME} foreground"]

