FROM docker.io/alpine:latest
WORKDIR /root
COPY . /root
RUN apk add curl
RUN curl -LO https://ziglang.org/download/0.11.0/zig-linux-x86_64-0.11.0.tar.xz
RUN tar xf ./zig-linux-x86_64-0.11.0.tar.xz
RUN rm ./zig-linux-x86_64-0.11.0.tar.xz
RUN ./zig-linux-x86_64-0.11.0/zig build -Doptimize=ReleaseFast
ENTRYPOINT ["./zig-out/bin/zblog"]
