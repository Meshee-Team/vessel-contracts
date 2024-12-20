FROM ghcr.io/foundry-rs/foundry:nightly-31c24b0b901d6fd393d52070221cccab54e45e80 AS builder

WORKDIR /app
COPY ./lib ./lib
COPY ./src ./src

RUN rm -rf cache out abi \
      && forge build --out abi --via-ir

FROM node:19.5.0-alpine

WORKDIR /app
COPY --from=builder /app/abi /app/abi
COPY ./lib ./lib
COPY ./src ./src
COPY ./script ./script
WORKDIR /app/script
RUN npm install && \
      npm install -g typescript tsx && \
      chmod +x ./docker-entrypoint.sh
CMD ["/bin/sh", "-c", "./docker-entrypoint.sh"]
