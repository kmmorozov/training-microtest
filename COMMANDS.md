# Команды курса: разбор ключей и вывода

Этот файл сопровождает лекции MT_LPIC-103 v3. Вывод сокращен до значимых строк:
PID, версии, имена интерфейсов и адреса на реальном стенде будут другими.
Placeholder `<...>` нужно заменить целиком; `192.0.2.0/24` — документационная
сеть, а `192.168.X.0/24` — схема лабораторного руководства.

Успешные команды проверки (`sshd -t`, `nginx -t` в некоторых сборках,
`systemd-analyze verify`) часто ничего не выводят. Всегда учитывайте exit status:

```bash
command
printf 'exit=%s\n' "$?"
# exit=0
```

## 1. Загрузка и systemd

### Журнал загрузки

```bash
journalctl -b -p warning --no-pager
```

- `-b` — только текущая загрузка; `-b -1` — предыдущая.
- `-p warning` — warning и более важные приоритеты.
- `--no-pager` удобен для протокола и автоматической проверки.

Характерный вывод: `kernel: ...`, `systemd[1]: Failed to start ...`. Первая
ошибка не всегда первопричина: сопоставляйте время и зависимые units.

```bash
dmesg --level=err,warn
```

Показывает ring buffer ядра. Ищите ошибки устройств, файловой системы, драйверов,
OOM; сообщения прикладной службы обычно находятся в journal ее unit.

### Управление units

```bash
systemctl start demo.service
systemctl stop demo.service
systemctl restart demo.service
systemctl reload demo.service
systemctl enable --now demo.service
systemctl is-enabled demo.service
systemctl is-active demo.service
systemctl status demo.service --no-pager
```

`start/stop` меняют текущее состояние; `enable/disable` — связи автозапуска.
`--now` совмещает enable со start. `reload` допустим только если служба его
реализует. Вывод `enabled` и `active` проверяет два независимых свойства. В status
важны `Loaded`, `Active`, `Main PID` и последние сообщения, например:

```text
Loaded: loaded (.../demo.service; enabled)
Active: active (running)
Main PID: 1234 (demo)
```

```bash
systemctl cat demo.service
systemctl show demo.service -p MainPID -p User -p Restart
systemctl edit demo.service
systemctl daemon-reload
systemd-analyze verify /etc/systemd/system/demo.service
```

`cat` показывает основной unit и drop-ins; `show` — machine-readable effective
properties. `edit` создает локальный drop-in. После изменения unit нужен
`daemon-reload`; он не перезапускает процесс. `verify` разбирает unit до запуска.

```bash
systemctl --failed
systemctl list-units
systemctl get-default
systemctl set-default graphical.target
systemctl mask broken.service
systemctl unmask broken.service
```

`--failed` в исправной системе выводит `0 loaded units listed`. `mask` запрещает
любой запуск unit и используется как временная мера восстановления.

```bash
journalctl -u demo.service --since '-5 min' --no-pager
```

`-u` отбирает unit, `--since` ограничивает окно изменения. Ищите начало/конец,
exit code, signal и сообщения приложения.

### GRUB, initramfs и fstab

```bash
findmnt --verify
update-initramfs -u -k all        # Debian/Ubuntu
dracut -f --regenerate-all       # RHEL-like
lsinitramfs /boot/initrd.img-$(uname -r)
lsinitrd /boot/initramfs-$(uname -r).img
update-grub                       # Debian/Ubuntu
grub2-mkconfig -o <actual-grub.cfg>  # RHEL-like
```

`findmnt --verify` диагностирует fstab до reboot. `-u` обновляет initramfs,
`-k all` — для всех установленных ядер; `dracut -f` перезаписывает образ. Путь
RHEL `grub.cfg` зависит от BIOS/UEFI — не угадывайте его. В GRUB параметры
`systemd.unit=rescue.target` и `systemd.unit=emergency.target` выбирают режим
только для текущей загрузки; `systemctl default` возвращает default target.

## 2. Резервирование, сборка и ресурсы

```bash
tar --xattrs --acls -C / -czf service-config.tgz etc/<service>
tar -tzf service-config.tgz | sed -n '1,20p'
```

`-C /` делает имена относительными, `-c` создает, `-z` сжимает gzip, `-f`
задает файл. `--xattrs --acls` сохраняют расширенные атрибуты и ACL. `-t` сначала
показывает содержимое; восстановление проверяйте в отдельном каталоге.

```bash
rsync -aHAXn --delete /etc/<service>/ backup:/srv/config/<host>/
```

`-a` — archive, `-H` — hard links, `-A` — ACL, `-X` — xattrs, `-n` — dry-run.
`--delete` удалит на приемнике то, чего нет в источнике: сначала проверяйте
`realpath` и dry-run. `Number of regular files transferred: 0` означает, что
дельты нет, но для строгой проверки полезен `--itemize-changes`.

```bash
rpm -qa | sort
dpkg-query -W
systemctl cat <service>
ss -lntup
```

Эти команды фиксируют пакетный состав, effective unit и исходные listeners перед
изменением.

### Доверенная сборка

```bash
sha256sum -c SHA256SUMS
tar tf project-X.Y.tar.gz | head
tar xf project-X.Y.tar.gz
./configure --prefix=/usr/local
make -j"$(nproc)"
make check
sudo make install
sudo ldconfig
ldd /usr/local/bin/<tool>
```

`sha256sum -c` должен вывести `<archive>: OK`. `tar tf` проверяет дерево до
распаковки. `configure` сохраняет диагностику в `config.log`; `/usr/local` не
пересекается с файлами package manager. `-j$(nproc)` использует logical CPUs.
`make check` должен завершиться без FAIL. В `ldd` недопустимы строки `not found`.

```bash
sudo systemd-run --unit=lpic103-iperf-server.service /usr/local/bin/iperf3 -s -1
/usr/local/bin/iperf3 -c 127.0.0.1 -t 3
```

`systemd-run` создает transient unit. `-s -1` обслуживает один тест, клиентский
`-t 3` — три секунды. В конце iperf3 выводит `sender/receiver` bitrate.

### cgroup v2

```bash
stat -fc %T /sys/fs/cgroup
cat /sys/fs/cgroup/cgroup.controllers
sudo systemd-run --unit=lpic103-load.service \
  -p CPUQuota=25% -p MemoryHigh=192M -p MemoryMax=256M -p TasksMax=32 \
  stress-ng --cpu 2 --vm 1 --vm-bytes 128M --timeout 90s
systemctl show lpic103-load.service -p ControlGroup -p CPUQuotaPerSecUSec \
  -p MemoryHigh -p MemoryMax -p TasksMax
systemd-cgls --unit lpic103-load.service
systemd-cgtop --iterations=3
```

`cgroup2fs` подтверждает v2. CPUQuota 25% — четверть одного logical CPU,
MemoryHigh — pressure threshold, MemoryMax — жесткий limit, TasksMax считает
процессы/потоки. После timeout проверяйте `Result`, `ExecMainCode`,
`ExecMainStatus`, `MemoryPeak`; `inactive (dead)` после штатного теста не ошибка.

### Cockpit и Webmin

```bash
systemctl enable --now cockpit.socket
systemctl status cockpit.socket --no-pager
ss -lntp 'sport = :9090'
curl -kI https://127.0.0.1:9090
```

Cockpit использует socket activation. `-I` запрашивает headers, `-k` только для
первичной проверки self-signed endpoint и **не доказывает доверие TLS**. Webmin
проверяется аналогично unit `webmin` и TCP/10000; его `miniserv.conf` находится в
`/etc/webmin/`. Оба административных endpoint ограничивайте management network.

## 3. Ядро, sysctl и netfilter

```bash
sysctl net.ipv4.ip_forward
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl --system
```

Первая команда читает effective value (`... = 0/1`), `-w` меняет текущую
загрузку, `--system` читает все sysctl-файлы. Постоянные локальные параметры
кладут в отдельный `/etc/sysctl.d/60-*.conf` и проверяют после reboot.

```bash
modinfo dummy
sudo modprobe dummy numdummies=1
lsmod | grep '^dummy'
modprobe --showconfig | grep dummy
journalctl -k -b
```

`modinfo` показывает filename, license, description, depends и parm. `modprobe`
учитывает зависимости, в отличие от raw `insmod`. `lsmod` выводит name/size/used
by. Автозагрузку задает `modules-load.d`, параметры — отдельно `modprobe.d`.

```bash
sysctl net.netfilter.nf_conntrack_count net.netfilter.nf_conntrack_max
sudo conntrack -L -p tcp | head
sudo conntrack -E
sudo nft -c -f rules.nft
sudo nft -f rules.nft
sudo nft list ruleset
sudo nft list table inet lpic103_lab
```

`count` должен оставаться ниже `max`. `conntrack -L` — snapshot, `-E` — поток
событий. `nft -c` проверяет транзакцию без применения. В counter rule значения
`packets N bytes N` должны вырасти после тестового запроса.

## 4. Файлы, права, ACL и атрибуты

```bash
install -d -o user -g group -m 2770 /srv/app/upload
stat -c '%U:%G %a %n' /srv/app/upload
namei -l /srv/app/upload/file
id user
umask
```

`install -d` атомарно задает owner/group/mode. Первая цифра `2` — setgid:
новые объекты наследуют группу каталога. `namei -l` показывает каждый компонент
пути; отсутствие execute на родителе блокирует доступ независимо от mode файла.

```bash
setfacl -m u:service:rwx,m:rwx /srv/app/upload
setfacl -m d:u:service:rwx,d:g:ops:rwx,d:m:rwx /srv/app/upload
getfacl -p /srv/app/upload
```

`-m` изменяет ACL, `d:` — default ACL для новых объектов, `m:` — mask
максимальных effective прав named users/groups. В `getfacl` пометка
`#effective:r-x` объясняет урезание mask.

```bash
chmod 1770 /srv/app/dropbox
chattr +a /srv/app/log/audit.log
lsattr /srv/app/log/audit.log
```

Sticky bit `1` запрещает пользователю удалять чужой объект в общем каталоге.
`+a` разрешает только append; `lsattr` показывает `a`. Перед удалением/ротацией
нужно осознанно снять атрибут `chattr -a`.

```bash
findmnt -T /srv/app
df -hT /srv/app
du -sh /srv/app
find /srv/app -xdev -type f -printf '%s %p\n' | sort -n
```

`findmnt` связывает путь с source/fstype/options, `df` — емкость файловой
системы, `du` — занятые файлами blocks. `-xdev` не пересекает другие mounts.

## 5. RAID, LVM и миграция

```bash
lsblk -o NAME,MODEL,SERIAL,TYPE,SIZE,FSTYPE,MOUNTPOINTS /dev/sdb
sudo wipefs -n /dev/sdb
sudo mdadm --create /dev/md/lpic103 --metadata=1.2 --level=1 \
  --raid-devices=2 /dev/sdb /dev/sdc
sudo mdadm /dev/md/lpic103 --add /dev/sdd
cat /proc/mdstat
sudo mdadm --detail /dev/md/lpic103
sudo mdadm /dev/md/lpic103 --fail /dev/sdb --remove /dev/sdb
sudo mdadm --wait /dev/md/lpic103
```

Первые две команды — read-only preflight. `--create` уничтожает прежние
метаданные. В исправном RAID1 `/proc/mdstat` содержит `[UU]`; detail после rebuild:
`State : clean`, `Active Devices : 2`, `Failed Devices : 0`.

```bash
sudo pvcreate /dev/sde /dev/sdf /dev/sdg
sudo vgcreate vg_lpic103 /dev/sde /dev/sdf /dev/sdg
sudo lvcreate -L 1G -n lv_data vg_lpic103
sudo lvextend -L +512M /dev/vg_lpic103/lv_data
sudo resize2fs /dev/vg_lpic103/lv_data
sudo lvcreate -s -n lv_before -L 512M /dev/vg_lpic103/lv_data
sudo lvcreate --type thin-pool -L 1500M -n pool0 vg_lpic103
sudo lvcreate --type thin -V 3G -n thin_web vg_lpic103/pool0
pvs; vgs; lvs -a -o lv_name,lv_size,origin,pool_lv,data_percent,metadata_percent
```

Цепочка: devices → PV → VG → LV → filesystem. `lvextend` не увеличивает саму
ext4, поэтому нужен `resize2fs` (для XFS — `xfs_growfs <mountpoint>`). Snapshot
зависит от origin; `Data%` 100 означает потерю snapshot. Для thin pool отдельно
контролируйте Data% и Metadata%.

```bash
realpath /srv/lpic103-migrate-src /srv/lpic103-migrate-dst
rsync -aHAXn --delete --itemize-changes SRC/ DST/
rsync -aHAX --delete SRC/ DST/
mount --bind DST SRC
findmnt -T SRC
```

Trailing slash у `SRC/` означает «содержимое каталога». Двухпроходная схема:
первый проход при работающем writer, остановка, короткий финальный проход,
нулевой dry-run, checksum/ACL diff, только затем switch. Bind mount временный,
если его нет в fstab.

## 6. Сетевая диагностика

```bash
ip -br link
ip -br address
ip route
ip route get 192.0.2.10
ping -c 2 192.0.2.10
```

`-br` дает компактное состояние. `ip route get` показывает фактически выбранные
destination, gateway, device и source. Потеря ICMP не доказывает недоступность TCP.

```bash
getent ahostsv4 app.example.test
dig @192.0.2.53 app.example.test A +noall +answer
dig @192.0.2.53 example.test SOA +norecurse
dig -x 192.0.2.10 +short
```

`getent` использует NSS как приложения; `dig @server` опрашивает конкретный DNS.
В authoritative ответе ищите flag `aa`, ожидаемые owner/type/value и serial SOA.
`NXDOMAIN` — имени нет, `SERVFAIL` — сервер не смог ответить, timeout — ответа нет.

```bash
ss -lntp 'sport = :8443'
ss -lunp 'sport = :53'
nc -vz -w 3 app.example.test 8443
curl -v --connect-timeout 4 https://app.example.test:8443/ -o /dev/null
```

`l/n/t/u/p`: listening, numeric, TCP, UDP, process. `nc` доказывает только
TCP-connect. Curl различает resolve failure, no route, timeout, refused, TLS error
и HTTP status; `--fail` делает HTTP 4xx/5xx ненулевым exit.

```bash
openssl s_client -connect app.example.test:8443 \
  -servername app.example.test -verify_hostname app.example.test \
  -CAfile ca.crt </dev/null
```

`-servername` задает SNI, `-verify_hostname` проверяет SAN/name, `-CAfile` — trust
anchor. Успех: `Verification: OK` и `Verify return code: 0 (ok)`.

```bash
sudo timeout 15 tcpdump -l -ni any -c 20 'host 192.0.2.100 and tcp port 8443'
```

`-n` не резолвит, `-i any` слушает интерфейсы, `-c` ограничивает packets, `-l`
буферизует построчно. SYN без SYN-ACK указывает, что запрос дошел, но ответ не
вернулся; SYN/RST обычно означает отсутствие listener/reject.

## 7. DHCP, NetworkManager и PAM

```bash
sudo dhcpd -t -cf /etc/dhcp/dhcpd.conf
sudo ss -lunp 'sport = :67'
nmcli connection show
sudo nmcli connection down <lab-connection>
sudo nmcli connection up <lab-connection>
resolvectl status <lab-iface>
nmcli device show <lab-iface>
```

`dhcpd -t` разбирает config без запуска listener. После renew адрес должен попасть
в pool/reservation; `ip route` показывает option 121, `resolvectl`/`nmcli` — DNS.
DHCP запускайте только в изолированном L2-сегменте и привязывайте к lab interface.

PAM-конфиги находятся в `/etc/pam.d/`. `auth`, `account`, `password`, `session` —
разные стадии; флаги `required`, `requisite`, `sufficient`, `optional` меняют
управление stack. Для SSH effective цепочку всегда сопоставляйте с `UsePAM` и
`AuthenticationMethods`, сохраняя резервный сеанс.

## 8. Samba, NFS, BIND и Squid

```bash
testparm -s
smbpasswd -a user1
smbclient -L //files.example.test -U user1
smbclient //files.example.test/team -U user1 -c 'put probe.txt; ls; get probe.txt read.txt'
```

`testparm -s` должен вывести `Loaded services file OK` и effective share.
Samba credentials не заменяют UNIX account. `NT_STATUS_ACCESS_DENIED` в
негативном тесте подтверждает `valid users`, если аутентификация прошла.

```bash
exportfs -rav
exportfs -v
mount -t nfs4 -o vers=4.2,hard server:/srv/nfs/data /mnt/data
findmnt -T /mnt/data
```

`-r` перечитывает exports, `-a` — все, `-v` — verbose. AUTH_SYS передает числовые
UID/GID; `root_squash` должен приводить к отказу client root в каталоге 2770.
В fstab для сети применяют `_netdev,x-systemd.automount`; `soft` может нарушить
целостность I/O и в лекционном примере не используется.

```bash
named-checkconf
named-checkzone example.test /var/named/db.example.test
named-checkzone 2.0.192.in-addr.arpa /var/named/db.192.0.2
rndc reload example.test
dig @127.0.0.1 app.example.test A +norecurse
```

`checkzone` должен завершиться `loaded serial ...` и `OK`. Увеличивайте SOA serial
при каждом изменении. `rndc reload zone` перечитывает одну зону без restart.

```bash
squid -k parse
squid -k reconfigure
curl -x http://proxy:3128 http://allowed.example.test/
tail -n 20 /var/log/squid/access.log
```

`parse` проверяет config, `reconfigure` перечитывает. В access.log `TCP_DENIED/403`
ожидается для blocked domain; разрешенный запрос дает `TCP_MISS/200` или иной
2xx/3xx. ACL читаются сверху вниз до первого совпадения.

## 9. Web, PHP, MariaDB и почта

```bash
nginx -t
apachectl configtest
apachectl -S
curl -H 'Host: app.example.test' http://127.0.0.1/
```

Nginx успех: `syntax is ok` и `test is successful`. Apache: `Syntax OK`;
`-S` показывает mapping vhosts. Header Host проверяет выбор сайта до DNS.

```bash
php -v
php -m | grep -Ei 'mysqli|pdo_mysql'
ss -lxnp | grep -E 'php|fpm'
sudo mariadb
SHOW GRANTS FOR 'lpic103_wp'@'localhost';
```

CLI PHP и FPM могут иметь разные конфиги, поэтому проверяйте FPM socket и реальный
PHP endpoint. `SHOW GRANTS` должен ограничивать пользователя одной schema; пароль
не передавайте аргументом процесса или в history.

```bash
postfix check
postconf -n
postqueue -p
dovecot --version
doveconf -n
doveadm user recipient@example.test
doveadm mailbox list -u recipient@example.test
doveadm search -u recipient@example.test mailbox INBOX subject TEST_ID
```

`postconf -n` и `doveconf -n` показывают non-default/effective настройки.
`postqueue -p`: `Mail queue is empty` либо queue ID и причина задержки.
`doveadm user` должен вернуть uid/home, mailbox list — `INBOX`, search — mailbox
GUID/UID найденного письма.

```bash
openssl s_client -starttls smtp -connect mail.example.test:587 \
  -servername mail.example.test -CAfile ca.crt -verify_hostname mail.example.test
swaks --server mail.example.test --port 587 --tls \
  --auth-user sender@example.test --auth-password --protect-prompt \
  --from sender@example.test --to recipient@example.test
```

`-starttls smtp` сначала говорит SMTP, затем включает TLS. В swaks ожидаются
`235 Authentication successful` и `250 ... queued as <QUEUE_ID>`. Негативный
relay-тест без auth к внешнему recipient должен получить 454/550/554.

## 10. Firewall, SSH, OpenVPN и PKI

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow from 192.0.2.0/24 to any port 22 proto tcp
ufw allow 443/tcp
ufw status verbose
```

Сначала сохраните текущий административный доступ, затем включайте UFW. Output
`Status: active` и таблица правил не заменяют тест с разрешенного/запрещенного host.

```bash
iptables -S
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp -s 192.0.2.0/24 --dport 22 -j ACCEPT
iptables -P INPUT DROP
nft list ruleset
```

Порядок критичен; DROP policy ставьте только сохранив management path. На системах
с iptables-nft проверяйте итоговый nft ruleset. Для атомарности предпочтительнее
проверенный `iptables-restore` файл, как в `iptables.sh`.

```bash
firewall-cmd --state
firewall-cmd --get-active-zones
firewall-cmd --zone=public --add-service=https
firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --reload
firewall-cmd --zone=public --list-all
```

`running` подтверждает daemon. Изменение без `--permanent` — runtime. После
reload runtime-only правило исчезнет; permanent загрузится. Не смешивайте зоны
интерфейса и source-zone без проверки precedence.

### SSH, сертификаты и FIDO2

```bash
sshd -t
sshd -T | grep -E 'permitrootlogin|passwordauthentication|authenticationmethods'
ssh-keygen -t ed25519 -f ~/.ssh/id_lpic103_cert
ssh-keygen -s user_ca -I lpic103-user -n user -V -5m:+60m id_lpic103_cert.pub
ssh-keygen -L -f id_lpic103_cert-cert.pub
ssh-keygen -t ed25519-sk -O resident -O verify-required -f ~/.ssh/id_lpic103_sk
ssh-copy-id -i ~/.ssh/id_lpic103_sk.pub user@server
ssh -vv -o IdentitiesOnly=yes -i ~/.ssh/id_lpic103_sk user@server
```

`sshd -t` — syntax, `-T` — effective values. `-s` подписывает public key,
`-I` задает identity, `-n` principal, `-V` validity. `-L` показывает Type,
Valid и Principals. Суффикс `-sk` требует security key; `resident` хранит
credential на токене, `verify-required` требует PIN/биометрию. Приватный CA не
копируется на SSH-сервер.

### OpenVPN 2.6

```bash
openvpn --version | head -3
test -c /dev/net/tun || sudo modprobe tun
systemctl list-unit-files 'openvpn*'
ss -lunp 'sport = :1194'
ip -br address show type tun
ip route get 192.0.2.20
journalctl -u openvpn-client@lpic103 --since '-5 min' | \
  grep -E 'Initialization Sequence Completed|Data Channel'
```

Версия должна быть 2.6.x для профилей курса. Проверяйте фактические template units.
Журнал сообщает negotiated data cipher; он должен входить в `data-ciphers`.
TUN address и route доказывают сетевой результат, listener — только UDP endpoint.

### OpenSSL: CA, CSR и сертификат

```bash
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out server.key
chmod 0600 server.key
openssl req -new -key server.key -out server.csr -config req.cnf
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 397 -extfile req.cnf -extensions req_ext
openssl x509 -in server.crt -noout -subject -issuer -dates -ext subjectAltName
openssl verify -CAfile ca.crt server.crt
```

`genpkey` создает EC P-256 private key. CSR содержит subject/public key и запрос
SAN; подпись CA должна перенести SAN и правильный EKU. Verify успех:
`server.crt: OK`. `-CAcreateserial` годится для одиночного учебного выпуска;
промышленный CA ведет serial/audit централизованно.

```bash
openssl pkey -in server.key -pubout | openssl sha256
openssl x509 -in server.crt -pubkey -noout | openssl sha256
```

Одинаковые SHA-256 значения подтверждают, что сертификат соответствует ключу,
не раскрывая private key.

## Итоговая приемка endpoint

```bash
dig app.example.test A +short
dig -x 192.0.2.10 +short
ss -lntup
firewall-cmd --zone=<zone> --list-all
openssl s_client -connect app.example.test:443 -servername app.example.test </dev/null
curl --fail --cacert root-ca.pem https://app.example.test/health
nc -vz app.example.test 443
journalctl -u <unit> --since '-5 min'
```

Команды проверяют разные слои: DNS → socket → firewall → TLS → HTTP → журнал.
Приемка содержит положительный тест из разрешенной сети и отрицательный из
запрещенной; один `active (running)` результатом end-to-end теста не является.
