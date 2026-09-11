#!/usr/bin/env bash
# Штатные parser проверки полных лекционных конфигов в одноразовом контейнере.
# Никакие службы не публикуются и не запускаются на компьютере преподавателя.
set -euo pipefail
[ -f /run/.containerenv ] || [ -f /.dockerenv ] || {
    echo "Запуск допустим только внутри контейнера" >&2; exit 2;
}
cd /materials
. /etc/os-release
if [ "$ID" = rocky ]; then
    dnf -y install httpd nginx squid dovecot openssl python3
    family=rhel
    webuser=nginx
else
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y apache2 nginx squid dovecot-imapd openssl python3
    family=debian
    webuser=www-data
fi
# TLS dependency files создаются внутри контейнера, repo остается read-only.
./scripts/generate-lab-pki.sh --tls-only /tmp/lecture-pki
install -d /etc/nginx/tls /srv/www/app /etc/dovecot/private
cp /tmp/lecture-pki/app.crt /etc/nginx/tls/fullchain.pem
cp /tmp/lecture-pki/app.key /etc/nginx/tls/server.key
cp /tmp/lecture-pki/mail.crt /tmp/lecture-pki/mail.key /etc/dovecot/private/
for source in lecture-examples/nginx/*.conf; do
    # Только platform user отличается; server blocks остаются исходными.
    sed "s/^user nginx;/user $webuser;/" "$source" > /tmp/nginx-lecture.conf
    nginx -t -c /tmp/nginx-lecture.conf
done
if [ "$family" = rhel ]; then
    httpd -t -f /materials/lecture-examples/apache/app-rhel.conf
else
    # Apache Debian main config использует переменные штатного envvars.
    set +u
    . /etc/apache2/envvars
    set -u
    apache2 -t -f /materials/lecture-examples/apache/app-debian.conf
fi
sed 's/192.168.X/192.168.10/g' labs/15-squid/squid.conf.template > /tmp/squid-lab.conf
squid -k parse -f /tmp/squid-lab.conf
# Выбор действительно установленной ветки Dovecot, без предположения по имени ОС.
dovecot_version=$(dovecot --version)
case "$dovecot_version" in
    2.3*) conf=dovecot-2.3.conf ;;
    2.4*) conf=dovecot-2.4.conf ;;
    *) echo "Нет эталона для Dovecot $dovecot_version" >&2; exit 1 ;;
esac
doveconf -c "/materials/lecture-examples/dovecot/$conf" -n > /tmp/dovecot-lecture.txt
printf 'PASS: %s — Nginx/Apache/Squid/Dovecot %s\n' "$PRETTY_NAME" "$dovecot_version"
