#!/usr/bin/env bash
# Экспорт полного установленного почтового комплекта без изменения служб.
# Архив содержит пароли SQL/TLS keys: хранить только вне Git, каталог root 0700.
set -euo pipefail
[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "Запустите sudo" >&2; exit 1; }
[ "$#" -eq 1 ] || { echo "Использование: sudo $0 /закрытый/новый-каталог" >&2; exit 2; }
out=$1
[ ! -e "$out" ] || { echo "Каталог уже существует; перезапись запрещена" >&2; exit 1; }
umask 077
install -d -m 0700 "$out"
out=$(realpath "$out")
# Три основных дерева обязательны; без них это не готовый iRedMail стенд.
for dir in /etc/postfix /etc/dovecot /etc/nginx; do
    [ -d "$dir" ] || { echo "Отсутствует $dir" >&2; exit 1; }
done
# Сохраняем полные деревья, включая SQL maps, include-файлы, TLS и конфиги webmail.
# Большие mailboxes /var/vmail и SQL data сюда не входят: это не backup писем/БД.
paths=(etc/postfix etc/dovecot etc/nginx)
for dir in etc/iredmail etc/amavis etc/amavisd etc/clamav etc/fail2ban etc/ssl \
           etc/pki/tls etc/php etc/php-fpm.conf etc/php-fpm.d etc/roundcube \
           etc/mysql etc/my.cnf etc/my.cnf.d opt/iredapd opt/iredadmin opt/www; do
    [ ! -e "/$dir" ] || paths+=("$dir")
done
# Символические ссылки сохраняются: после tar -tvf проверьте внешние targets,
# если TLS/приложения установлены в нестандартный каталог, добавьте их в backup.
tar --acls --xattrs -C / -czf "$out/full-configs.tar.gz" "${paths[@]}"
# Effective configs дополняют, а не заменяют исходные полные файлы.
postconf -n > "$out/postfix-effective.txt"
postconf -M > "$out/postfix-master.txt"
doveconf -n > "$out/dovecot-effective.txt"
nginx -T > "$out/nginx-effective.txt" 2>&1
# Package versions нужны для восстановления на совместимом образе.
if command -v rpm >/dev/null; then
    rpm -qa | sort > "$out/packages.txt"
else
    dpkg-query -W > "$out/packages.txt"
fi
(cd "$out" && sha256sum full-configs.tar.gz > SHA256SUMS && tar -tzf full-configs.tar.gz > FILES.txt)
echo "Полные конфиги: $out (секретный архив; не добавлять в Git)."
