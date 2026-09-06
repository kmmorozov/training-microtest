#!/usr/bin/env bash
# Создает изолированное дерево /srv/lpic103-app, users, modes, ACL и append-only log.
# Не используйте команды этого файла с более широким путем /srv или /.
set -euo pipefail

# Все операции с identities, owner и inode flags требуют root.
[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "Запустите через sudo" >&2; exit 1; }
# Группа операторов отделена от service user.
groupadd -f lpic103-ops
getent passwd lpic103-app >/dev/null || useradd --system --home-dir /nonexistent --shell /usr/sbin/nologin lpic103-app
getent passwd lpic103-alice >/dev/null || useradd -m -G lpic103-ops lpic103-alice
getent passwd lpic103-bob >/dev/null || useradd -m -G lpic103-ops lpic103-bob

# Корень доступен для traversal, но его содержимое получает разные модели прав.
install -d -o root -g root -m 0755 /srv/lpic103-app
# 2xxx включает setgid: новые объекты наследуют группу каталога.
install -d -o root -g lpic103-ops -m 2750 /srv/lpic103-app/code
install -d -o lpic103-app -g lpic103-ops -m 2770 /srv/lpic103-app/upload
install -d -o lpic103-app -g lpic103-ops -m 2750 /srv/lpic103-app/cache /srv/lpic103-app/log
# 1xxx — sticky bit: участники не удаляют чужие файлы общего dropbox.
install -d -o root -g lpic103-ops -m 1770 /srv/lpic103-app/dropbox
# Named ACL дает service user ровно rx к коду и rwx к upload.
setfacl -m u:lpic103-app:rx,m:rx /srv/lpic103-app/code
setfacl -m u:lpic103-app:rwx,m:rwx /srv/lpic103-app/upload
# Default ACL наследуется будущими объектами upload; mask сохраняет effective rwx.
setfacl -m d:u:lpic103-app:rwx,d:g:lpic103-ops:rwx,d:m:rwx /srv/lpic103-app/upload

# +a разрешает только добавление. Перед очисткой стенда сначала выполните chattr -a.
touch /srv/lpic103-app/log/audit.log
chown lpic103-app:lpic103-ops /srv/lpic103-app/log/audit.log
chattr +a /srv/lpic103-app/log/audit.log
# Финальный вывод показывает effective ACL/mask и inode flag a.
getfacl -p /srv/lpic103-app/upload
lsattr /srv/lpic103-app/log/audit.log
