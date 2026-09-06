#!/usr/bin/env bash
# Проверяет архив WordPress и создает least-privilege файловое дерево.
# Не создает DB/wp-config/TLS и отказывается перезаписывать существующий site root.
set -euo pipefail

# Аргументы: архив, checksum manifest и фактический PHP-FPM user.
[ "$#" -eq 3 ] || {
    echo "Использование: $0 wordpress-X.Y.Z.tar.gz SHA256SUMS web-user" >&2; exit 2;
}
archive=$(realpath "$1")
sums=$(realpath "$2")
web_user=$3
# Все предусловия проверяются до распаковки в /var/www.
getent passwd "$web_user" >/dev/null || { echo "Нет пользователя $web_user" >&2; exit 1; }
[ ! -e /var/www/lpic103-wp ] || { echo "/var/www/lpic103-wp уже существует" >&2; exit 1; }

# Manifest проверяется из каталога архива, чтобы относительное имя совпало.
(cd "$(dirname "$archive")" && sha256sum -c "$sums")
# Просмотр первых путей помогает убедиться в ожидаемом корне wordpress/.
tar tf "$archive" | sed -n '1,20p'
sudo tar -xf "$archive" -C /var/www
sudo mv /var/www/wordpress /var/www/lpic103-wp
# Код принадлежит root и не должен изменяться скомпрометированным web worker.
sudo chown -R root:root /var/www/lpic103-wp
sudo find /var/www/lpic103-wp -type d -exec chmod 0755 {} +
sudo find /var/www/lpic103-wp -type f -exec chmod 0644 {} +
web_group=$(id -gn "$web_user")
# Единственная штатно writable область — media uploads.
sudo install -d -o "$web_user" -g "$web_group" -m 0750 /var/www/lpic103-wp/wp-content/uploads

# SELinux rule сохраняется через relabel; chcon намеренно не используется.
if command -v getenforce >/dev/null && [ "$(getenforce)" = Enforcing ]; then
    sudo semanage fcontext -a -t httpd_sys_rw_content_t \
        '/var/www/lpic103-wp/wp-content/uploads(/.*)?' 2>/dev/null ||
        sudo semanage fcontext -m -t httpd_sys_rw_content_t \
        '/var/www/lpic103-wp/wp-content/uploads(/.*)?'
    sudo restorecon -Rv /var/www/lpic103-wp
fi

# Два противоположных test доказывают модель: code deny, uploads allow.
sudo -u "$web_user" test ! -w /var/www/lpic103-wp/index.php
sudo -u "$web_user" test -w /var/www/lpic103-wp/wp-content/uploads
echo "Файлы подготовлены; установите wp-config.php с root:$web_group 0640."
