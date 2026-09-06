#!/usr/bin/env bash
# Устанавливает преподавательский TLS endpoint и сертификат app.example.test.
# Аргумент — каталог, ранее созданный scripts/generate-lab-pki.sh.
set -euo pipefail

# Установка меняет identities, /etc, /srv, /usr/local и systemd.
[ "$#" -eq 1 ] || { echo "Использование: $0 /path/generated/pki" >&2; exit 2; }
[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "Запустите через sudo" >&2; exit 1; }
pki=$(realpath "$1")
src=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# Проверяем полный комплект до первой модификации системы.
for file in ca.crt app.crt app.key; do
    [ -f "$pki/$file" ] || { echo "Нет $pki/$file" >&2; exit 1; }
done

# Закрытый system user не имеет shell/home.
getent passwd lpic103-tls >/dev/null || \
    useradd --system --home-dir /nonexistent --shell /usr/sbin/nologin lpic103-tls
install -d -o root -g lpic103-tls -m 0750 /etc/lpic103-tls
install -d -o root -g lpic103-tls -m 0750 /srv/lpic103-tls
# CA/leaf cert публичны, private key читают только root и service group.
install -m 0644 "$pki/ca.crt" /etc/lpic103-tls/ca.crt
install -m 0644 "$pki/app.crt" /etc/lpic103-tls/server.crt
install -o root -g lpic103-tls -m 0640 "$pki/app.key" /etc/lpic103-tls/server.key
# Приложение и статический ответ не должны быть изменяемы service user.
install -o root -g lpic103-tls -m 0644 "$src/index.html" /srv/lpic103-tls/index.html
install -m 0755 "$src/https-server.py" /usr/local/libexec/lpic103-https-server
install -m 0644 "$src/lpic103-tls.service" /etc/systemd/system/lpic103-tls.service
# Сначала verify, затем daemon-reload/start и фактический socket check.
systemd-analyze verify /etc/systemd/system/lpic103-tls.service
systemctl daemon-reload
systemctl enable --now lpic103-tls.service
systemctl --no-pager status lpic103-tls.service
ss -lntp 'sport = :8443'
