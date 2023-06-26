FROM alpine:3.17.3
MAINTAINER boredazfcuk

ENV config_dir="/config" TZ="UTC"

ARG build_dependencies="git gcc python3-dev musl-dev rust cargo libffi-dev openssl-dev"
ARG app_dependencies="py3-pip exiftool coreutils tzdata curl imagemagick shadow jq"
ARG app_repo="icloud-photos-downloader/icloud_photos_downloader"

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** Build started for boredazfcuk's docker-icloudpd *****" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install build dependencies" && \
  apk add --no-progress --no-cache --virtual=build-deps ${build_dependencies} && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install requirements" && \
   apk add --no-progress --no-cache ${app_dependencies} && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Clone ${app_repo}" && \
   app_temp_dir=$(mktemp -d) && \
   git clone -b master "https://github.com/${app_repo}.git" "${app_temp_dir}" && \
   cd "${app_temp_dir}" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install iOS 16 Shared Libraries patch" && \
   curl https://patch-diff.githubusercontent.com/raw/icloud-photos-downloader/icloud_photos_downloader/pull/489.patch | git apply && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install Python dependencies" && \
   pip3 install --upgrade pip && \
   pip3 install --no-cache-dir -r requirements.txt && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install iOS 16 Shared Librares pyicloud_ipd patch" && \
   cd /usr/lib/python3.10/site-packages && \
   mv pyicloud_ipd pyicloud && \
   curl https://patch-diff.githubusercontent.com/raw/icloud-photos-downloader/pyicloud/pull/8.patch | git apply && \
   mv pyicloud pyicloud_ipd && \
   cd - && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install iCloudPD latest release" && \
   python -m venv /opt/icloudpd_latest && \
   source /opt/icloudpd_latest/bin/activate && \
   pip3 install --upgrade pip && \
   pip3 install --no-cache-dir wheel && \
   pip3 install --no-cache-dir icloudpd && \
   sed -i 's/from collections import Callable/from collections.abc import Callable/' \
      "/opt/icloudpd_latest/lib/python3.10/site-packages/keyring/util/properties.py" && \
   sed -i -e 's/password_encrypted = base64.decodestring(password_base64)/password_encrypted = base64.decodebytes(password_base64)/' \
      -e 's/password_base64 = base64.encodestring(password_encrypted).decode()/password_base64 = base64.encodebytes(password_encrypted).decode()/' \
      "/opt/icloudpd_latest/lib/python3.10/site-packages/keyrings/alt/file_base.py" && \
   sed -i 's/again in a few minutes/again later. This process may take a day or two./' \
      "/opt/icloudpd_latest/lib/python3.10/site-packages/pyicloud_ipd/services/photos.py" && \
   deactivate && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Clean up" && \
   apk del --no-progress --purge build-deps 

COPY build_version.txt /
COPY --chmod=0755 *.sh /usr/local/bin/

HEALTHCHECK --start-period=10s --interval=1m --timeout=10s CMD /usr/local/bin/healthcheck.sh
  
VOLUME "${config_dir}"

CMD /usr/local/bin/sync-icloud.sh
