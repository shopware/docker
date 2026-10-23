#syntax=docker/dockerfile:1
FROM base AS collect
USER root
COPY collect-runtime.sh /usr/local/bin/collect-runtime
RUN collect-runtime

# Only compiled files and dependency metadata cross into the daily images.
FROM scratch
COPY --from=collect /artifacts/ /
COPY validate-runtime.sh /validate-runtime.sh
