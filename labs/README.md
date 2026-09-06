# Карта материалов лабораторных работ

Здесь указано, куда устанавливать файлы и чем проверять их до применения.
Команды package manager выполняйте только для семейства своей ОС.

## 01 — systemd

- `lpic103-demo` → `/usr/local/libexec/lpic103-demo`, mode 0755.
- service → `/etc/systemd/system/lpic103-demo.service`, mode 0644.
- override → `/etc/systemd/system/lpic103-demo.service.d/override.conf`.
- `install.sh` создает user, копирует файлы, выполняет verify и запускает unit.

## 02 — iperf3 из исходников

`build-iperf3.sh ARCHIVE SHA256SUMS` проверяет checksum, показывает содержимое,
собирает и запускает tests без root. `make install` оставлен отдельным осознанным
шагом после просмотра `config.log`.

## 03 — cgroup v2

`run-limited-load.sh` проверяет cgroup2 и запускает только transient unit
`lpic103-load.service` с CPUQuota/MemoryHigh/MemoryMax/TasksMax.

## 04 — Cockpit

После запуска `cockpit.socket` выберите **один** шаблон: firewalld или UFW.
Подставьте management CIDR и не закрывайте резервную административную сессию.

## 05 — модуль и netfilter

- modules-load файл → `/etc/modules-load.d/lpic103-dummy.conf`;
- modprobe файл → `/etc/modprobe.d/lpic103-dummy.conf`;
- `nft -c -f lpic103_lab.nft` — dry validation;
- `nft -f ...` создает отдельную policy-accept таблицу только со счетчиком 8080.

## 06 — права и ACL

`sudo setup.sh` создает только `/srv/lpic103-app` и учебные identities. Для очистки
сначала снимите append-only атрибут с `audit.log`; не применяйте рекурсивные
команды к `/srv` целиком.

## 07 и 08 — storage

Запускаются только read-only `preflight.sh` с тремя явными devices. Разрушительные
`mdadm --create`, `mkfs`, `pvcreate` и `lvcreate` оставлены в `COMMANDS.md` внутри
соответствующего каталога и выполняются вручную после сверки MODEL/SERIAL.

## 09 — миграция

Writer устанавливается в `/usr/local/libexec/`, service — в `/etc/systemd/system/`.
`migrate.sh` принимает только учебную пару каталогов, сначала показывает dry-run
и требует `YES`. Финальная delta, checksum/ACL diff и bind switch выполняются в
окне остановки по руководству.

## 10 — диагностический TLS endpoint

Сначала `scripts/generate-lab-pki.sh`, затем преподаватель выполняет
`sudo setup-server.sh ../../generated/pki`. Клиент адаптирует
`check-endpoint.sh.template`. Упражнение содержит ровно один документированный
дефект.

## 11 — DHCP

После замены X/Y/MAC скопируйте конфиг в `/etc/dhcp/dhcpd.conf` и проверьте
`dhcpd -t -cf ...`. Выберите platform-файл `/etc/sysconfig/dhcpd` или
`/etc/default/isc-dhcp-server`. До start UDP/67 должен быть свободен.

## 12 — Samba

`setup-share.sh` создает UNIX identities/каталог/SELinux context. Добавьте fragment
в `/etc/samba/smb.conf`, выполните `testparm -s`, отдельно задайте Samba passwords
для Alice и Bob. Проверяются allow Alice и deny Bob.

## 13 — NFS

`setup-identity.sh` выполняется на сервере и клиенте; UID/GID обязаны совпасть.
Exports template → `/etc/exports.d/lpic103.exports`; после замены X выполните
`exportfs -rav`. Клиент монтирует NFSv4 и проверяет user write/root_squash deny.

## 14 — BIND

- options fragment вставляется в существующий `options {}`;
- zones fragment выбирается по ОС;
- zone files устанавливаются в package directory с корректным owner/SELinux;
- перед `rndc reload`: `named-checkconf` и два `named-checkzone`.

Не забудьте заменить X/Z и увеличить serial после изменения.

## 15 — Squid

После подстановки X установите template как `/etc/squid/squid.conf`. Выполните
`squid -k parse`, затем reconfigure. `check-proxy.sh` ожидает 2xx/3xx для allowed и
403 для blocked; listener не должен быть доступен вне labnet.

## 16 — WordPress

Следуйте локальному README: verified archive → root-owned code → writable uploads
→ отдельная DB/user → защищенный wp-config → platform Nginx/FPM → TLS. Пароли и
salts в Git не сохраняются.

## 17 — iRedMail

Адаптируйте два шаблона. Первый не изменяет систему и проверяет зависимости,
listeners, effective Postfix/Dovecot и TLS. Второй отправляет одно письмо, извлекает
queue ID и ищет Subject в INBOX. Инсталлятор iRedMail повторно не запускается.

## 18 — SSH

CA создается на offline host; на сервер передается только `.pub`. Применение:
CA drop-in → отдельный вход → FIDO2 → отдельный вход → PAM/TOTP → два входа →
hardening. Перед каждым reload: резервная сессия, `sshd -t`, `sshd -T`.

## 19 — OpenVPN

Следуйте локальному README. Сервер/client profiles, sysctl и firewalld template
соответствуют OpenVPN 2.6, не включают compression/default route и выдают только
маршрут к LAN. Проверяются EKU/name, negotiated AEAD cipher, tun address и route.
