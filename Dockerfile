# syntax=docker/dockerfile:1
FROM python:3.13-slim-bookworm

VOLUME [ "/etc/weewx" ]

RUN adduser \
 --system --uid 1000 --group \
 --comment "WeeWX Server" --home /home/weewx \
 weewx

RUN pip install --no-cache-dir -U weewx six

RUN mkdir -p "/etc/weewx" "/etc/dist-weewx" && chown -R weewx: /etc/weewx/ /etc/dist-weewx/

USER weewx

WORKDIR /home/weewx

RUN weectl station create --no-prompt /etc/weewx

RUN weectl extension install --yes https://github.com/gjr80/weewx-gw1000/releases/latest/download/gw1000.zip

RUN rm -f /etc/weewx/weewx.conf.*

RUN cp -a /etc/weewx/. /etc/dist-weewx/

ADD entrypoint.sh /usr/local/bin/

ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]
