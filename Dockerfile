# syntax=docker/dockerfile:1

ARG ALPINE_VERSION=3.19
ARG TEMURIN_VERSION=17-jre-alpine

FROM alpine:${ALPINE_VERSION} AS downloader

ARG SQLCL_VERSION=24.3.2.330.1718

RUN apk add --no-cache ca-certificates curl unzip

WORKDIR /opt

RUN curl --fail --show-error --silent --location \
      --retry 3 \
      --output /tmp/sqlcl.zip \
      "https://download.oracle.com/otn_software/java/sqldeveloper/sqlcl-${SQLCL_VERSION}.zip" \
    && unzip -q /tmp/sqlcl.zip -d /opt \
    && rm -f /tmp/sqlcl.zip

FROM eclipse-temurin:${TEMURIN_VERSION}

RUN apk add --no-cache \
      bash \
      ca-certificates \
      coreutils \
      findutils \
      libstdc++ \
      ncurses

COPY --from=downloader /opt/sqlcl /opt/sqlcl

RUN addgroup -S sqlcl \
    && adduser -S sqlcl -G sqlcl \
    && chown -R sqlcl:sqlcl /opt/sqlcl \
    && chmod -R 755 /opt/sqlcl/bin/sql

ENV PATH="/opt/sqlcl/bin:${PATH}"

RUN sql -v

USER sqlcl
WORKDIR /home/sqlcl

