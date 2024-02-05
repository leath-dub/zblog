FROM docker.io/alpine:edge
WORKDIR /root
COPY . /root
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
RUN apk add curl zig
RUN zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux
RUN rm ./zig-cache
CMD ./zig-out/bin/zblog
