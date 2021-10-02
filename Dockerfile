FROM alpine:latest

RUN apk --no-cache add openssh-client

COPY docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]