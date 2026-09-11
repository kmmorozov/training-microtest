#!/usr/bin/env bash
# Проверка полных конфигов в одноразовом Podman-контейнере Rocky/Ubuntu.
# Устанавливает пакеты ТОЛЬКО внутри контейнера; репозиторий монтируется read-only.
# Пример: podman run --rm -v REPO:/materials:ro rockylinux/rockylinux:10 bash /materials/scripts/check-platform-configs.sh
set -euo pipefail
[ -f /run/.containerenv ] || [ -f /.dockerenv ] || {
    echo "Этот скрипт предназначен только для одноразового контейнера" >&2; exit 2;
}
cd /materials
. /etc/os-release
# Пакеты из штатных подписанных репозиториев; daemon services здесь не запускаем.
if [ "$ID" = rocky ]; then
    dnf -y install kea bind bind-utils nginx php-fpm php-cli samba-common-tools \
      openssh-server openssl python3
    family=rhel
    kea_bin=kea-dhcp4
    fpm_bin=php-fpm
else
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y kea-dhcp4-server bind9-utils nginx php8.3-fpm php8.3-cli \
      samba-common-bin openssh-server openssl python3 dovecot-imapd postfix
    family=debian
    kea_bin=kea-dhcp4
    fpm_bin=php-fpm8.3
fi
# Независимые ключи/сертификаты генерируются внутри контейнера, не в рабочем Git.
./scripts/generate-lab-pki.sh --tls-only /tmp/lpic103-pki
install -d /etc/nginx/lpic103-tls /etc/lpic103-tls /var/www/lpic103-wp \
  /run/sshd /run/php-fpm /run/php /etc/ssh /var/named /etc/bind
install -m 0644 /tmp/lpic103-pki/wp.crt /etc/nginx/lpic103-tls/wp.crt
install -m 0600 /tmp/lpic103-pki/wp.key /etc/nginx/lpic103-tls/wp.key
# Syntax/semantics Kea: полный конфиг, включая реальный parser option 121.
# Kea -t проверяет существование NIC: заменяем только имя интерфейса на
# реальный NIC контейнера. Адресная схема/опции эталонного файла не меняются.
test_nic=$(find /sys/class/net -mindepth 1 -maxdepth 1 ! -name lo -printf '%f\n' | head -n 1)
[ -n "$test_nic" ] || { echo "Нет NIC контейнера" >&2; exit 1; }
sed "s/enp0s8/$test_nic/g" labs/11-dhcp/kea-dhcp4.conf > /tmp/kea-test.conf
"$kea_bin" -t /tmp/kea-test.conf
testparm -s /materials/labs/12-samba/smb.conf > /tmp/samba-effective.txt
for stage in http tls; do
    nginx -t -c "/materials/labs/16-wordpress/nginx-$family-$stage.conf"
done
"$fpm_bin" -t -y "/materials/labs/16-wordpress/php-fpm-$family.conf"
# Генератор WordPress должен выдавать синтаксически верный PHP с отсутствующими placeholders.
./scripts/prepare-wordpress-config.py /tmp/lpic103-wp-config
php -l /tmp/lpic103-wp-config/wp-config.php
# BIND: создаем зависимости main config, затем проверяем main и обе зоны.
rndc-confgen -a -c /etc/rndc.key
cp /etc/rndc.key /etc/bind/rndc.key
sed -e 's/192.168.X/192.168.10/g' -e 's/192.168.Z/192.168.30/g' \
  labs/14-bind/db.example.test.template > /var/named/db.example.test
cp labs/14-bind/db.192.168.X.template /var/named/db.192.168.10
cp /var/named/db.example.test /var/named/db.192.168.10 /etc/bind/
named-checkconf -z "/materials/labs/14-bind/named-$family.conf"
# sshd -t проверяет конфигурацию, но не интерактивную PAM/FIDO2 аутентификацию.
ssh-keygen -A
ssh-keygen -q -t ed25519 -N '' -f /tmp/lpic103-user-ca
cp /tmp/lpic103-user-ca.pub /etc/ssh/lpic103_user_ca.pub
for stage in ca mfa; do
    /usr/sbin/sshd -t -f "/materials/labs/18-ssh-hardening/sshd_config-$stage.conf"
done
# Dovecot 2.3 и Postfix reference относятся к Ubuntu 24.04.
if [ "$family" = debian ]; then
    install -d /etc/dovecot/private /etc/postfix/lpic103-tls
    cp /tmp/lpic103-pki/mail.crt /etc/dovecot/private/mail.crt
    cp /tmp/lpic103-pki/mail.key /etc/dovecot/private/mail.key
    cp /tmp/lpic103-pki/mail.crt /tmp/lpic103-pki/mail.key /etc/postfix/lpic103-tls/
    doveconf -c /materials/lecture-examples/dovecot/dovecot-2.3.conf -n > /tmp/dovecot-effective.txt
    cp /materials/lecture-examples/postfix/main.cf /materials/lecture-examples/postfix/master.cf /etc/postfix/
    postfix check
fi
echo "PASS: $PRETTY_NAME — Kea, Samba, Nginx, FPM, PHP, BIND, SSH configs"
