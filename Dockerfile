FROM rust:1.81 AS rust-builder

WORKDIR /usr/src/app
COPY . .
RUN cargo build --release

FROM node:latest AS elm-builder

WORKDIR /usr/src/app
COPY frontend .
RUN sed -i 's/http:\/\/localhost:3000/https:\/\/unpacking.fly.dev/g' client/src/Api.elm
RUN yarn install
RUN yarn prod

FROM debian:bookworm-slim
RUN apt-get update && apt-get install postgresql -y

COPY --from=rust-builder /usr/src/app/target/release/unpacking /usr/local/bin
COPY --from=elm-builder /usr/src/app/public frontend/public
COPY --from=elm-builder /usr/src/app/dist frontend/dist
COPY --from=elm-builder /usr/src/app/translations frontend/translations

CMD /bin/bash -c "/usr/local/bin/unpacking"s
