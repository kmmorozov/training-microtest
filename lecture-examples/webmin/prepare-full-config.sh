#!/usr/bin/env bash
# Создает полный miniserv.conf из конфига установленного пакета Webmin.
# Сохраняет версионные root/mimetypes/session/users paths, меняет только сеть/TLS.
# Запуск: sudo ./prepare-full-config.sh /root/lpic103-webmin 192.168.10.0/24
set -euo pipefail
[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "Нужен sudo для чтения package config" >&2; exit 1; }
[ "$#" -eq 2 ] || { echo "Нужны новый output directory и management CIDR" >&2; exit 2; }
out=$1
cidr=$2
# Разрешаем только IPv4 CIDR, не произвольную вставку директив/переносов строки.
python3 -c 'import ipaddress,sys; ipaddress.IPv4Network(sys.argv[1], strict=True)' "$cidr"
[ -f /etc/webmin/miniserv.conf ] || { echo "Сначала установите Webmin" >&2; exit 1; }
[ ! -e "$out" ] || { echo "Выходной каталог уже существует" >&2; exit 1; }
umask 077
install -d -m 0700 "$out"
# Удаляем все старые экземпляры изменяемых параметров, чтобы не было конфликтов.
{
    echo '# Полный miniserv.conf, основанный на установленной версии Webmin.'
    echo '# Установить целиком в /etc/webmin/miniserv.conf, сохранив резервную копию.'
    awk '!/^(port|listen|ssl|allow)=/' /etc/webmin/miniserv.conf
    echo '# HTTPS management listener и разрешенная административная сеть.'
    printf 'port=10000\nlisten=10000\nssl=1\nallow=127.0.0.1 %s\n' "$cidr"
} > "$out/miniserv.conf"
# Копия необходима для отката с сохранением исходных настроек конкретного пакета.
cp -a /etc/webmin/miniserv.conf "$out/miniserv.conf.before-lpic103"
echo "Создан полный $out/miniserv.conf; установка и проверка — README."
