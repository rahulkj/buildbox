FROM ubuntu:23.04
LABEL maintainer="rahulkj@gmail.com"
LABEL maintainer_name="Rahul Jain"

ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN true

ADD install-cli.sh /
ADD tkgi/tkgi-* /usr/local/bin/tkgi

RUN apt-get update && apt-get install -y --no-install-recommends git python3.10 \
  vim unzip uuid-runtime \
  iputils-ping dnsutils ca-certificates \
  telnet gnupg2 \
  curl wget jq \
  && apt-get autoremove \
  && chmod +x ./install-cli.sh \
  && ./install-cli.sh \
  && chmod +x /usr/local/bin/tkgi
