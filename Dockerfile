# syntax=docker/dockerfile:1
FROM ghcr.io/linuxserver/baseimage-alpine:3.20 AS baseimage-amd64

FROM ghcr.io/linuxserver/baseimage-alpine:arm64v8-3.20 AS baseimage-arm64

FROM baseimage-${TARGETARCH}

# set version label
ARG BUILD_DATE
ARG VERSION
ARG WEEWX_RELEASE=v5.1.0
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="na4ma4"

RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache --upgrade --virtual=build-dependencies \
    build-base \
    cargo \
    jpeg-dev \
    libffi-dev \
    libxslt-dev \
    libxml2-dev \
    openldap-dev \
    openssl-dev \
    postgresql-dev \
    python3-dev \
    py3-pip \
    zlib-dev && \
  echo "**** install runtime packages ****" && \
  apk add --no-cache --upgrade \
    libldap \
    postgresql-client \
    python3 \
    tiff \
    uwsgi \
    uwsgi-python && \
  echo "**** install weewx ****" && \
  mkdir -p /app/weewx && \
  if [ -z ${WEEWX_RELEASE+x} ]; then \
    WEEWX_RELEASE=$(curl -sX GET "https://api.github.com/repos/weewx/weewx/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  fi && \
  curl -o \
  /tmp/weewx.tar.gz -L \
    "https://github.com/weewx/weewx/archive/refs/tags/${WEEWX_RELEASE}.tar.gz" && \
  tar xf \
  /tmp/weewx.tar.gz -C \
    /app/weewx/ --strip-components=1 && \
    echo "**** install pip packages ****" && \
  cd /app/weewx && \
  python3 -m venv /lsiopy && \
  pip install -U --no-cache-dir \
    pip \
    wheel && \
  pip install --no-cache-dir --find-links https://wheel-index.linuxserver.io/alpine-3.20/ -U ephem six && \
  pip install --no-cache-dir . && \
  printf "Linuxserver.io version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version && \
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    /tmp/* \
    ${HOME}/.cargo \
    ${HOME}/.cache

RUN weectl station create --no-prompt /etc/weewx && \
  weectl extension install --yes https://github.com/gjr80/weewx-gw1000/releases/latest/download/gw1000.zip && \
  rm -f /etc/weewx/weewx.conf.* && \
  cp -a /etc/weewx/. /etc/dist-weewx/

# copy local files
COPY root/ /

# ports and volumes
EXPOSE 8000

VOLUME /config
