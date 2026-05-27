FROM alpine:3.20
RUN apk add --no-cache openssl
COPY init.sh /init.sh
RUN chmod +x /init.sh
ENTRYPOINT ["/init.sh"]
