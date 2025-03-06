#!/bin/bash

if [[ ! -f "/etc/weewx/weewx.conf" ]]; then
    echo "init: copying dist config"
    cp -a /etc/dist-weewx/. /etc/weewx/
fi

exec /usr/local/bin/weewxd "${@}"
