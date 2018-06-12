FROM elixir:1.5.2-alpine

MAINTAINER True-Dat Dev Team

RUN apk --no-cache update \
    && apk --no-cache add git make g++ \
    &&  rm -fr /var/cache/apk/*

# MS Logic
RUN mkdir /app
WORKDIR /app
COPY . /app

RUN mix local.hex --force
RUN mix local.rebar --force
RUN rm -rf ./_build
RUN mix deps.clean --all
RUN mix deps.get
RUN MIX_ENV=prod mix phx.swagger.generate priv/static/swagger.json

CMD mix phx.server
