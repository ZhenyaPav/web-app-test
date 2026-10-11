FROM nginxinc/nginx-unprivileged:1.28.2-alpine@sha256:7377697a821c131a924a7105fafbe7414db4e9fcc77a6f08f776f33f141ec3f8

COPY --chown=101:101 nginx.conf /etc/nginx/conf.d/default.conf
COPY --chown=101:101 app/ /usr/share/nginx/html/
ARG VERSION=local
USER root
RUN printf '%s\n' "$VERSION" > /usr/share/nginx/html/version.txt
USER 101:101
LABEL org.opencontainers.image.source="https://github.com/ZhenyaPav/web-app-test"
EXPOSE 8080
