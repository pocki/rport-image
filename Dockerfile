FROM alpine:3.18 as downloader

ARG RPORT_VERSION=0.9.12
ARG FRONTEND_BUILD=0.9.12-build-1128
#ARG rportplus=0.1.0
ARG NOVNC_VERSION=1.3.0

RUN apk add unzip

WORKDIR /app/

RUN set -e \
    && wget https://github.com/cloudradar-monitoring/rport/releases/download/${RPORT_VERSION}/rportd_${RPORT_VERSION}_Linux_$(uname -m).tar.gz -O rportd.tar.gz \
    && tar xzf rportd.tar.gz rportd

RUN set -e \
    && wget https://downloads.rport.io/frontend/stable/rport-frontend-${FRONTEND_BUILD}.zip -O frontend.zip \
    && unzip frontend.zip -d ./frontend

RUN set -e \
    && wget https://github.com/novnc/noVNC/archive/refs/tags/v${NOVNC_VERSION}.zip -O novnc.zip \
    && unzip novnc.zip && mv noVNC-${NOVNC_VERSION} ./novnc

WORKDIR /envplate
RUN set -e \
    && arch=$(uname -m) \
    && if [ "${arch}" == "aarch64" ]; then release_arch="arm64"; else release_arch=${arch}; fi \
    && release_name=envplate_1.0.2_$(uname -s)_${release_arch}.tar.gz \
    && wget https://github.com/kreuzwerker/envplate/releases/download/v1.0.2/${release_name} -O envplate.tar.gz \
    && tar -xf envplate.tar.gz

FROM debian:11

COPY --from=downloader /app/rportd /usr/local/bin/rportd
COPY --from=downloader /app/frontend/ /var/www/html/
COPY --from=downloader /app/novnc/ /var/lib/rport-novnc
COPY --from=downloader /envplate/envplate /usr/local/bin/ep

COPY entrypoint.sh /entrypoint.sh

ARG UID=1233
ARG GID=1233

RUN groupadd -g "${GID}" rport \
    && useradd -d /var/lib/rport -m -r -u "${UID}" -g "${GID}" -s /bin/false rport \
    && mkdir -p /etc/rport && chown rport:rport /etc/rport

USER rport

COPY --chown=rport:rport rportd.conf.template /etc/rportd.conf.template

VOLUME [ "/var/lib/rport/" ]
LABEL maintainer="Christoph Pock <dev+github@pocki.xyz>" \
    org.label-schema.schema-version="1.0" \
    org.label-schema.vcs-ref="github.com/pocki/rport-image" \
    org.label-schema.name="rport" \
    org.label-schema.description="RPort" \
    org.label-schema.url="https://github.com/pocki/rport-image" \
    org.label-schema.vcs-url="https://github.com/pocki/rport-image"

EXPOSE 8080
EXPOSE 3000

ENTRYPOINT [ "/bin/bash", "/entrypoint.sh", "/usr/local/bin/rportd", "--data-dir", "/var/lib/rport", "--config", "/etc/rport/rportd.conf" ]
