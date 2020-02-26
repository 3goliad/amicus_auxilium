FROM alpine:3.11
RUN apk add --no-cache openssl openssl-dev nodejs npm
RUN apk -X http://dl-3.alpinelinux.org/alpine/edge/community \
    add rust cargo
WORKDIR /app
COPY . .
RUN cargo build --release
RUN cd client && npm run build
ENTRYPOINT ["target/release/amicus_auxilium"]
