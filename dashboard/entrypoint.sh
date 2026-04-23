#!/bin/sh
# Generate nginx.conf with dynamic resolver from /etc/resolv.conf

RESOLVER=$(awk '/^nameserver / {print $2; exit}' /etc/resolv.conf)
if [ -z "$RESOLVER" ]; then
    RESOLVER="127.0.0.11"
fi

export RESOLVER
envsubst '\${RESOLVER}' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf

exec nginx -g 'daemon off;'
