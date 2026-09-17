FROM ghcr.io/gleam-lang/gleam:v1.18.1-erlang-alpine AS build

COPY . /app
WORKDIR /app/api
RUN gleam export erlang-shipment

FROM ghcr.io/gleam-lang/gleam:v1.18.1-erlang-alpine

RUN addgroup -S tennis && adduser -S tennis -G tennis
COPY --from=build /app/api/build/erlang-shipment /app

USER tennis
WORKDIR /app
EXPOSE 10000

ENTRYPOINT ["/bin/sh", "/app/entrypoint.sh"]
CMD ["run"]
