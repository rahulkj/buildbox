FROM ubuntu:20.04
MAINTAINER rahulkj@gmail.com

ADD install-cli.sh /

RUN apt-get update && apt-get install -y --no-install-recommends git python \
  nano unzip uuid-runtime iputils-ping dnsutils ca-certificates \
  netcat telnet gnupg2 curl wget jq && apt-get autoremove \
  && apt-get autoremove \
  && chmod +x ./install-cli.sh \
  && ./install-cli.sh
