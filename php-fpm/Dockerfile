#syntax=docker/dockerfile:1
# Adapted from docker-library/php 5ec2a6a0dad498e89a91a39454dbb52e98ce2bdb, 8.6-rc/alpine3.24/fpm.
# PHP 8.2–8.5 build options follow e3eaff845f7a9f7259c31da54dce0320b47a3bbd.

ARG ALPINE_VERSION=3.24
FROM alpine:${ALPINE_VERSION} AS php

# dependencies required for running "phpize"
# these get automatically installed and removed by "docker-php-ext-*" (unless they're already installed)
ENV PHPIZE_DEPS="autoconf dpkg-dev dpkg file g++ gcc libc-dev make pkgconf re2c"

# persistent / runtime deps
RUN apk add --no-cache \
		ca-certificates \
		curl \
		openssl \
		tar \
		xz

# ensure www-data user exists
RUN set -eux; \
	adduser -u 82 -D -S -G www-data www-data
# 82 is the standard uid/gid for "www-data" in Alpine
# https://git.alpinelinux.org/aports/tree/main/apache2/apache2.pre-install?h=3.14-stable
# https://git.alpinelinux.org/aports/tree/main/lighttpd/lighttpd.pre-install?h=3.14-stable
# https://git.alpinelinux.org/aports/tree/main/nginx/nginx.pre-install?h=3.14-stable

ENV PHP_INI_DIR=/usr/local/etc/php
RUN set -eux; \
	mkdir -p "$PHP_INI_DIR/conf.d"; \
# allow running as an arbitrary user (https://github.com/docker-library/php/issues/743)
	[ ! -d /var/www/html ]; \
	mkdir -p /var/www/html; \
	chown www-data:www-data /var/www/html; \
	chmod 1777 /var/www/html

# Apply stack smash protection to functions using local buffers and alloca()
# Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
# Enable optimization (-O2)
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# https://github.com/docker-library/php/issues/272
# -D_LARGEFILE_SOURCE and -D_FILE_OFFSET_BITS=64 (https://www.php.net/manual/en/intro.filesystem.php)
ENV PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"
ENV PHP_CPPFLAGS="$PHP_CFLAGS"
ENV PHP_LDFLAGS="-Wl,-O1 -pie"

ARG PHP_VERSION
ARG PHP_SHA256
ARG GPG_KEYS
ENV PHP_VERSION=${PHP_VERSION} \
    PHP_SHA256=${PHP_SHA256} \
    GPG_KEYS=${GPG_KEYS}
ENV PHP_URL="https://www.php.net/distributions/php-${PHP_VERSION}.tar.xz" \
    PHP_ASC_URL="https://www.php.net/distributions/php-${PHP_VERSION}.tar.xz.asc"

RUN set -eux; \
	\
	apk add --no-cache --virtual .fetch-deps gnupg; \
	\
	mkdir -p /usr/src; \
	cd /usr/src; \
	\
	curl -fsSL -o php.tar.xz "$PHP_URL"; \
	\
	test -n "$PHP_VERSION"; \
	test -n "$PHP_SHA256"; \
	test -n "$GPG_KEYS"; \
	echo "$PHP_SHA256 *php.tar.xz" | sha256sum -c -; \
	\
	curl -fsSL -o php.tar.xz.asc "$PHP_ASC_URL"; \
	export GNUPGHOME="$(mktemp -d)"; \
	for key in $GPG_KEYS; do \
		gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key"; \
	done; \
	gpg --batch --verify php.tar.xz.asc php.tar.xz; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME"; \
	\
	apk del --no-network .fetch-deps

COPY docker-php-source /usr/local/bin/

RUN set -eux; \
	apk add --no-cache --virtual .build-deps \
		$PHPIZE_DEPS \
		argon2-dev \
		coreutils \
		curl-dev \
		gnu-libiconv-dev \
		libsodium-dev \
		libxml2-dev \
		linux-headers \
		oniguruma-dev \
		openssl-dev \
		readline-dev \
		sqlite-dev \
	; \
	\
# make sure musl's iconv doesn't get used (https://www.php.net/manual/en/intro.iconv.php)
	rm -vf /usr/include/iconv.h; \
	\
	export \
		CFLAGS="$PHP_CFLAGS" \
		CPPFLAGS="$PHP_CPPFLAGS" \
		LDFLAGS="$PHP_LDFLAGS" \
# https://github.com/php/php-src/blob/d6299206dd828382753453befd1b915491b741c6/configure.ac#L1496-L1511
		PHP_BUILD_PROVIDER='https://github.com/shopware/docker' \
		PHP_UNAME='Linux - Docker' \
	; \
	docker-php-source extract; \
	cd /usr/src/php; \
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	case "$gnuArch" in \
		'i686-linux-'*) \
			# php zend jit assumes SSE registers, xmm0-7, are available (and "Pentium4"/SSE2 is a reasonable baseline)
			# https://github.com/php/php-src/pull/22832
			# so, allow it and use SSE/SSE2 floating-point unit instead of the legacy stack
			export \
				CFLAGS="$CFLAGS -msse2 -mfpmath=sse" \
				CPPFLAGS="$CPPFLAGS -msse2 -mfpmath=sse" \
			; \
			;; \
	esac; \
	test "$PHP_INI_DIR" != "${PHP_INI_DIR%/php}"; \
	./configure \
		--build="$gnuArch" \
		--sysconfdir="${PHP_INI_DIR%/php}" \
		--with-config-file-path="$PHP_INI_DIR" \
		--with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
		\
# make sure invalid --configure-flags are fatal errors instead of just warnings
		--enable-option-checking=fatal \
		\
# https://github.com/docker-library/php/issues/439
		--with-mhash \
		\
# PHP 8.2–8.5 require these options for shared extensions and mbstring.
		--with-pic \
		--enable-mbstring \
# --enable-mysqlnd is included here because it's harder to compile after the fact than extensions are (since it's a plugin for several extensions, not an extension in itself)
		--enable-mysqlnd \
# https://wiki.php.net/rfc/argon2_password_hash
		--with-password-argon2 \
# https://wiki.php.net/rfc/libsodium
		--with-sodium=shared \
# always build against system sqlite3 (https://github.com/php/php-src/commit/6083a387a81dbbd66d6316a3a12a63f06d5f7109)
		--with-pdo-sqlite=/usr \
		--with-sqlite3=/usr \
		\
		--with-curl \
		--with-iconv=/usr \
		--with-openssl \
		--with-readline \
		--with-zlib \
		\
# https://github.com/bwoebi/phpdbg-docs/issues/1#issuecomment-163872806 ("phpdbg is primarily a CLI debugger, and is not suitable for debugging an fpm stack.")
		--disable-phpdbg \
		--with-pear \
		\
		\
		--disable-cgi \
		\
		--enable-fpm \
		--with-fpm-user=www-data \
		--with-fpm-group=www-data \
	; \
	make -j "$(nproc)"; \
	find -type f -name '*.a' -delete; \
	make install; \
	find \
		/usr/local \
		-type f \
		-perm '/0111' \
		-exec sh -euxc ' \
			strip --strip-all "$@" || : \
		' -- '{}' + \
	; \
	make clean; \
	\
# https://github.com/docker-library/php/issues/692 (copy default example "php.ini" files somewhere easily discoverable)
	cp -v php.ini-* "$PHP_INI_DIR/"; \
	\
	cd /; \
	docker-php-source delete; \
	\
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --no-cache $runDeps; \
	\
	apk del --no-network .build-deps; \
	\
	pecl update-channels; \
	rm -rf /tmp/pear ~/.pearrc; \
	\
# smoke test
	php --version

COPY docker-php-ext-* docker-php-entrypoint /usr/local/bin/

# sodium was built as a shared module (so that it can be replaced later if so desired), so let's enable it too (https://github.com/docker-library/php/issues/598)
# OPcache is built in starting with PHP 8.5; older releases use a shared module.
RUN if ! php -r 'exit(extension_loaded("Zend OPcache") ? 0 : 1);'; then \
        docker-php-ext-enable opcache; \
    fi && docker-php-ext-enable sodium

ENTRYPOINT ["docker-php-entrypoint"]
WORKDIR /var/www/html

RUN set -eux; \
	cd "${PHP_INI_DIR%/php}"; \
	\
	cp -v php-fpm.conf.default php-fpm.conf; \
	cp -v php-fpm.d/www.conf.default php-fpm.d/www.conf; \
	\
	# comment out localhost-only listen address
	grep -E '^listen = 127.0.0.1:9000' php-fpm.d/www.conf; \
	sed -ri 's/^(listen = 127.0.0.1:9000)/;\1/' php-fpm.d/www.conf; \
	grep -E '^;listen = 127.0.0.1:9000' php-fpm.d/www.conf; \
	\
	{ \
		echo '[global]'; \
		echo 'error_log = /proc/self/fd/2'; \
		echo; echo '; https://github.com/docker-library/php/pull/725#issuecomment-443540114'; echo 'log_limit = 8192'; \
		echo; \
		echo '[www]'; \
		echo '; php-fpm closes STDOUT on startup, so sending logs to /proc/self/fd/1 does not work.'; \
		echo '; https://bugs.php.net/bug.php?id=73886'; \
		echo 'access.log = /proc/self/fd/2'; \
		echo; \
		echo 'clear_env = no'; \
		echo; \
		echo '; Ensure worker stdout and stderr are sent to the main error log.'; \
		echo 'catch_workers_output = yes'; \
		echo 'decorate_workers_output = no'; \
		echo; \
		echo '; default listen address for easy override in later php-fpm.d/*.conf files'; \
		echo 'listen = 9000'; \
	} | tee php-fpm.d/docker.conf; \
	{ \
		echo '[global]'; \
		echo 'daemonize = no'; \
	} | tee php-fpm.d/zz-docker.conf; \
	mkdir -p "$PHP_INI_DIR/conf.d"; \
	{ \
		echo '; https://github.com/docker-library/php/issues/878#issuecomment-938595965'; \
		echo 'fastcgi.logging = Off'; \
	} > "$PHP_INI_DIR/conf.d/docker-fpm.ini"

# Override stop signal to stop process gracefully
# https://github.com/php/php-src/blob/17baa87faddc2550def3ae7314236826bc1b1398/sapi/fpm/php-fpm.8.in#L163
STOPSIGNAL SIGQUIT

EXPOSE 9000
CMD ["php-fpm"]

# PHP extensions used by all image generations.
FROM php AS fpm

ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN <<EOF
    set -e

    apk add --no-cache icu-data-full curl jq trurl rabbitmq-c zstd-libs lz4-libs liblzf
    chmod +x /usr/local/bin/install-php-extensions
    install-php-extensions bcmath gd intl mysqli pdo_mysql pcntl sockets bz2 gmp soap zip ftp ffi opcache xsl
EOF

RUN --mount=type=secret,id=composer_auth \
    --mount=type=bind,from=ghcr.io/php/pie:bin,source=/pie,target=/usr/local/bin/pie <<EOF
    set -e
    if [ -f /run/secrets/composer_auth ]; then
        export COMPOSER_AUTH="$(cat /run/secrets/composer_auth)"
    fi
    export PIE_WORKING_DIRECTORY=/tmp/pie
    apk add --no-cache --virtual .pie-build-deps $PHPIZE_DEPS libtool unzip rabbitmq-c-dev zstd-dev lz4-dev liblzf-dev
    pie install --no-interaction --no-cache --skip-enable-extension phpredis/phpredis --enable-redis-lzf --with-liblzf=yes --enable-redis-zstd --enable-redis-lz4 --with-liblz4=yes
    pie install --no-interaction --no-cache --skip-enable-extension apcu/apcu:5.1.27
    pie install --no-interaction --no-cache --skip-enable-extension kjdev/zstd:0.15.2
    pie install --no-interaction --no-cache --skip-enable-extension php-amqp/php-amqp:2.2.0
    docker-php-ext-enable redis apcu zstd amqp
    rm -rf /tmp/pie
    apk del --no-cache .pie-build-deps
    mv "${PHP_INI_DIR}/php.ini-production" "${PHP_INI_DIR}/php.ini"
EOF

USER root

RUN apk add --no-cache git grpc-cpp grpc-dev $PHPIZE_DEPS && \
    GRPC_VERSION=$(apk info grpc -d | grep grpc | cut -d- -f2) && \
    git clone --depth 1 -b v${GRPC_VERSION} https://github.com/grpc/grpc /tmp/grpc && \
    cd /tmp/grpc/src/php/ext/grpc && \
    phpize && \
    ./configure && \
    make -j"$(nproc)" && \
    make install && \
    rm -rf /tmp/grpc && \
    apk del --no-cache git grpc-dev $PHPIZE_DEPS && \
    echo "extension=grpc.so" > /usr/local/etc/php/conf.d/grpc.ini

RUN --mount=type=secret,id=composer_auth \
    --mount=type=bind,from=ghcr.io/php/pie:bin,source=/pie,target=/usr/local/bin/pie <<EOF
    set -e
    if [ -f /run/secrets/composer_auth ]; then
        export COMPOSER_AUTH="$(cat /run/secrets/composer_auth)"
    fi
    export PIE_WORKING_DIRECTORY=/tmp/pie
    apk add --no-cache --virtual .pie-build-deps $PHPIZE_DEPS libtool unzip
    pie install --no-interaction --no-cache --skip-enable-extension open-telemetry/ext-opentelemetry
    docker-php-ext-enable opentelemetry
    rm -rf /tmp/pie
    apk del --no-cache .pie-build-deps
EOF

USER root
RUN --mount=type=secret,id=composer_auth \
    --mount=type=bind,from=ghcr.io/php/pie:bin,source=/pie,target=/usr/local/bin/pie <<'EOF'
    set -eu
    if [ -f /run/secrets/composer_auth ]; then
        export COMPOSER_AUTH="$(cat /run/secrets/composer_auth)"
    fi
    export PIE_WORKING_DIRECTORY=/tmp/pie
    install-php-extensions tideways blackfire
    apk add --no-cache --virtual .pie-build-deps $PHPIZE_DEPS libtool unzip linux-headers zlib-dev
    pie install --no-interaction --no-cache --skip-enable-extension xdebug/xdebug:3.5.0
    pie install --no-interaction --no-cache --skip-enable-extension noisebynorthwest/php-spx
    docker-php-ext-enable xdebug spx
    rm -rf /tmp/pie
    apk del --no-cache .pie-build-deps

    cd /usr/local/etc/php/conf.d
    mv docker-php-ext-opentelemetry.ini docker-php-ext-opentelemetry.disabled
    mv docker-php-ext-xdebug.ini docker-php-ext-xdebug.disabled
    mv docker-php-ext-tideways.ini docker-php-ext-tideways.disabled
    mv docker-php-ext-blackfire.ini docker-php-ext-blackfire.disabled
    mv docker-php-ext-spx.ini docker-php-ext-spx.disabled

EOF

# Optional extensions are enabled only by downstream image configuration.
RUN mv /usr/local/etc/php/conf.d/grpc.ini /usr/local/etc/php/conf.d/grpc.disabled

COPY LICENSE.docker-library-php /usr/local/share/licenses/docker-library-php/LICENSE

# Record runtime libraries for every binary and extension, including disabled ones.
RUN <<'EOF'
    set -eu
    apk add --no-cache --virtual .runtime-scan pax-utils
    scanelf --needed --nobanner --format '%n#p' --recursive /usr/local > /tmp/runtime-needed
    tr ',' '\n' < /tmp/runtime-needed \
        | sort -u \
        | awk 'NF && system("test -e /usr/local/lib/" $1) != 0 { print "so:" $1 }' \
        > /runtime-dependencies.txt
    test -s /runtime-dependencies.txt
    # Data and helper programs cannot be discovered through ELF dependencies.
    printf '%s\n' ca-certificates curl openssl tar xz icu-data-full jq trurl \
        >> /runtime-dependencies.txt
    sort -u -o /runtime-dependencies.txt /runtime-dependencies.txt
    cut -d. -f1,2 /etc/alpine-release > /alpine-version
    php-config --version > /php-version
EOF

# Consumers start from Alpine and install the runtime packages themselves.
FROM scratch AS artifacts
COPY --from=fpm /usr/local/ /usr/local/
COPY --from=fpm /usr/src/php.tar.xz /usr/src/php.tar.xz
COPY --from=fpm /runtime-dependencies.txt /runtime-dependencies.txt
COPY --from=fpm /alpine-version /alpine-version
COPY --from=fpm /php-version /php-version
