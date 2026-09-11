# Лабораторная 06. UNIX-права, ACL, sticky и append-only

Все 33 команды/шага и ожидаемые отказы: [WALKTHROUGH.md](WALKTHROUGH.md).
[Подготовка](../../PREPARATION.md). Одна ВМ, локальная ext4/XFS под /srv;
shared folder гипервизора может не поддерживать ACL/chattr.
```bash
# Rocky:
sudo dnf install -y acl attr e2fsprogs util-linux
# Debian/Ubuntu:
sudo apt install -y acl attr e2fsprogs util-linux
findmnt -T /srv
# Быстрое создание эталона; для ручного разбора выполните WALKTHROUGH вместо него.
sudo ./labs/06-filesystem-acl/setup.sh
namei -l /srv/lpic103-app/upload
getfacl -p /srv/lpic103-app/upload
lsattr /srv/lpic103-app/log/audit.log
```

Все identities и данные создаются локально, архивов/паролей/ключей нет.
Скрипт — полный с комментариями. Модель: сервис не пишет code, пишет upload,
операторы наследуют группу, sticky защищает чужое имя, append-only запрещает
перезапись audit.log. ACL mask ограничивает эффективные права даже при rwx entry.

Проверки allow/deny выполняйте **от имен учебных пользователей** через sudo -u.
Root может обойти обычные UNIX permissions и не заменяет negative test.
При отказе сначала namei/getfacl/findmnt, на SELinux — AVC, не chmod 777.
Для отката сначала `sudo chattr -a /srv/lpic103-app/log/audit.log`;
учебный каталог можно сохранить архивом с `tar --acls --xattrs`.
Не удаляйте пользователей, если они используются в следующих лабах.
