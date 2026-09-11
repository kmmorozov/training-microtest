# Лабораторная 13. NFSv4 и root_squash

Все 24 шага: [WALKTHROUGH.md](WALKTHROUGH.md).
[Общая подготовка](../../PREPARATION.md).
Сервер 192.168.10.20; клиент .100. В данном сценарии AUTH_SYS, не Kerberos:
сертификаты и keytab не нужны, доверяется числовому UID клиента в labnet.
```bash
# Rocky на сервере и клиенте:
sudo dnf install -y nfs-utils
# Debian/Ubuntu сервер:
sudo apt install -y nfs-kernel-server
# Debian/Ubuntu клиент:
sudo apt install -y nfs-common
# На ОБЕИХ машинах; сначала убедиться, что UID/GID 2103 не занят другим:
getent passwd 2103
getent group 2103
sudo ./labs/13-nfs/setup-identity.sh
id lpic103-nfs
```

Ожидается uid=2103 gid=2103 на обеих ВМ; одно совпадение имени недостаточно.
В этом каталоге [nfs.conf](nfs.conf) — полный основной серверный файл,
а lpic103.exports.template — полный файл exports.d, не кусок /etc/exports.

```bash
# Только сервер:
sudo install -d -o lpic103-nfs -g lpic103-nfs -m 2770 /srv/nfs/lpic103-data
sudo cp -a /etc/nfs.conf /etc/nfs.conf.before-lpic103
sudo install -m 0644 labs/13-nfs/nfs.conf /etc/nfs.conf
install -d -m 0700 generated/lab13
sed 's/192.168.X/192.168.10/g' labs/13-nfs/lpic103.exports.template > generated/lab13/lpic103.exports
sudo install -d /etc/exports.d
sudo install -m 0644 generated/lab13/lpic103.exports /etc/exports.d/lpic103.exports
# Rocky:
sudo systemctl enable --now nfs-server
sudo systemctl restart nfs-server
# Debian/Ubuntu вместо этого:
sudo systemctl enable --now nfs-kernel-server
sudo systemctl restart nfs-kernel-server
sudo exportfs -rav
sudo exportfs -v
sudo firewall-cmd --permanent --zone=internal --add-service=nfs
sudo firewall-cmd --reload
```

Выберите только одну ОС-ветку и свою interface zone. Конфиг отключает NFSv3,
поэтому для NFSv4 достаточно TCP2049; showmount (v3/mountd) не является приемкой.
На enforcing SELinux при AVC проверьте разрешение экспорта своей policy
(`getsebool nfs_export_all_rw`); не отключайте SELinux глобально.

```bash
# Клиент:
sudo install -d /mnt/lpic103-nfs
sudo mount -t nfs4 -o vers=4.2 192.168.10.20:/srv/nfs/lpic103-data /mnt/lpic103-nfs
sudo -u lpic103-nfs sh -c 'echo user-data > /mnt/lpic103-nfs/user.txt'
stat -c '%u:%g %a %n' /mnt/lpic103-nfs/user.txt
sudo sh -c 'echo root-data > /mnt/lpic103-nfs/root.txt'
```

Последняя команда должна отказать: root_squash отображает UID0 в anonymous,
который не владеет каталогом. Не заменяйте это no_root_squash для «исправления».
При Protocol not supported сравните версии в `cat /proc/fs/nfsd/versions`.
Откат: umount на клиенте, убрать только учебный export, exportfs -rav,
восстановить nfs.conf и restart.
