FROM docker.io/archlinux:latest
COPY ./zig-out/bin/zblog /usr/local/bin/zblog
CMD zblog
