# Лабораторная 12. Полный Samba server и групповой доступ

Все 26 шагов с выводами: [WALKTHROUGH.md](WALKTHROUGH.md).
[Общая подготовка](../../PREPARATION.md).
Сервер files.example.test = 192.168.10.20, клиент .100.
Полный [smb.conf](smb.conf) включает global и share; устанавливается целиком.
```bash
# Rocky:
sudo dnf install -y samba samba-client policycoreutils-python-utils
# Debian/Ubuntu:
sudo apt install -y samba smbclient
# На сервере:
sudo ./labs/12-samba/setup-share.sh
# Если Alice уже создана в lab06, useradd не меняет ее группы:
sudo usermod -aG lpic103-smb lpic103-alice
id lpic103-alice
id lpic103-bob
sudo smbpasswd -a lpic103-alice
sudo smbpasswd -a lpic103-bob
sudo cp -a /etc/samba/smb.conf /etc/samba/smb.conf.before-lpic103
sudo install -m 0644 labs/12-samba/smb.conf /etc/samba/smb.conf
sudo testparm -s
# Rocky:
sudo systemctl enable --now smb
sudo systemctl restart smb
# Debian/Ubuntu — вместо smb:
sudo systemctl enable --now smbd
sudo systemctl restart smbd
```

Два Samba-пароля задаются интерактивно и сохраняются в локальной passdb.
Это не SSH-пароли, TLS/CA не требуется. Bob существует в Samba, но не входит
в lpic103-smb: отказ должен доказывать ACL share, а не отсутствие учетной записи.
Проверьте, что Bob не был добавлен туда ранее.

```bash
# Сервер, internal = зона lab NIC:
sudo firewall-cmd --permanent --zone=internal --add-port=445/tcp
sudo firewall-cmd --reload
# Клиент (files.example.test должен разрешаться через DNS/hosts):
printf 'samba test\n' > /tmp/lpic103-smb.txt
smbclient //files.example.test/team -U lpic103-alice \
  -c 'put /tmp/lpic103-smb.txt probe.txt; ls; get probe.txt /tmp/lpic103-smb-read.txt'
smbclient //files.example.test/team -U lpic103-bob -c ls
```

У Alice загрузка/скачивание проходят; Bob получает NT_STATUS_ACCESS_DENIED.
Полный конфиг использует только TCP445/SMB2+, поэтому отсутствие listener139
не ошибка. На сервере `stat` показывает group lpic103-smb, mode660.
При отказе Alice: id/getfacl/testparm и `ls -Zd /srv/samba/lpic103-team`;
при изменении SELinux policy используйте semanage/restorecon, а не chmod777.
Откат: восстановить smb.conf.before-lpic103, testparm, restart выбранного unit.
