FROM alpine:3.20

LABEL org.opencontainers.image.source=https://github.com/liehendr/alpine-php-nginx

# ENV DEBIAN_FRONTEND=noninteractive

ENV TERM=linux
ENV TZ=UTC
ENV PHP_FPM_USER="worker"
ENV PHP_FPM_GROUP="worker"
ENV PHP_FPM_LISTEN_MODE="0660"
ENV PHP_MEMORY_LIMIT="512M"
ENV PHP_MAX_UPLOAD="50M"
ENV PHP_MAX_FILE_UPLOAD="200"
ENV PHP_MAX_POST="100M"
ENV PHP_DISPLAY_ERRORS="On"
ENV PHP_DISPLAY_STARTUP_ERRORS="On"
ENV PHP_ERROR_REPORTING="E_COMPILE_ERROR\|E_RECOVERABLE_ERROR\|E_ERROR\|E_CORE_ERROR"
ENV PHP_CGI_FIX_PATHINFO=0

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apk update \
    && apk add tzdata bash curl ca-certificates sed zip unzip git sqlite libcap libpng \
        php83-fpm php83-soap php83-openssl php83-gmp php83-pdo_odbc php83-json \
        php83-dom php83-pdo php83-zip php83-mysqli php83-sqlite3 php83-apcu \
        php83-pdo_pgsql php83-bcmath php83-gd php83-odbc php83-pdo_mysql \
        php83-pdo_sqlite php83-gettext php83-xmlreader php83-bz2 php83-iconv \
        php83-pdo_dblib php83-curl php83-ctype php83-session php83-tokenizer composer \
        nginx supervisor \
    && composer global require --quiet --no-ansi laravel/envoy \
    && composer clear-cache --quiet \
    && ln -s /root/.composer/vendor/laravel/envoy/bin/envoy /usr/local/bin/envoy

RUN sed -i "s|;*date.timezone =.*|date.timezone = ${TZ}|i" /etc/php83/php.ini

# PHP-FPM packages need a nudge to make them docker-friendly
COPY overrides.conf /etc/php83/php-fpm.d/z-overrides.conf

# PHP-FPM has really dirty logs, certainly not good for dockerising
# The following startup script contains some magic to clean these up
COPY php-fpm-startup /usr/local/bin/php-fpm

RUN mkdir -p /var/www/public
RUN mkdir -p /etc/nginx/conf.d

COPY index.php /var/www/public

COPY nginx.conf /etc/nginx/

COPY site.conf /etc/nginx/conf.d/

COPY supervisor /etc/supervisor

WORKDIR /var/www

# Add a non-root user to prevent files being created with root permissions on host machine.
ARG USER_CONTAINER=worker
ENV USER_CONTAINER=${USER_CONTAINER}
# ARG PUID=1000
# ENV PUID=${PUID}
# ARG PGID=1000
# ENV PGID=${PGID}

RUN adduser -D ${USER_CONTAINER} ${USER_CONTAINER}

EXPOSE 80

STOPSIGNAL SIGTERM

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]

