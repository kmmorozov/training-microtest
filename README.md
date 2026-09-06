# Дополнительные материалы MT_LPIC-103

Репозиторий сопровождает курс «Linux уровень 3. Администрирование сервисов
датацентра Linux». Материалы сверены с презентацией тренера v3 от 10.08.2026 и
руководством лабораторных работ v4 от 10.08.2026.

## Как пользоваться

1. Найдите лабораторную работу в таблице ниже.
2. Скопируйте нужный файл на стенд и замените значения вида `192.168.X`,
   `<lab-iface>`, `<lab-zone>`, `<user>` на параметры своей схемы.
3. Сначала выполните штатную проверку синтаксиса, указанную в столбце
   «Проверка», и только затем reload/restart.
4. Не коммитьте ключи, пароли, TOTP-секреты, recovery codes и рабочие
   сертификаты. Каталоги `generated/` и закрытые ключи исключены через
   `.gitignore`.

Каждый готовый скрипт и конфигурационный пример содержит комментарии о его
назначении, устанавливаемом пути, заменяемых значениях, существенных параметрах
и безопасной проверке. Комментарии являются частью учебного материала: перед
копированием файла на стенд прочитайте их целиком.

Команды лекций, ключи и характерный вывод собраны отдельно в [COMMANDS.md](COMMANDS.md).
Обозначения стенда и карта адресов находятся в [STAND.md](STAND.md).
Точные назначения файлов и порядок применения приведены в [labs/README.md](labs/README.md).

## Покрытие лабораторных

| № | Тема | Готовые материалы | Проверка |
|---:|---|---|---|
| 01 | systemd unit и drop-in | `labs/01-systemd/` | `systemd-analyze verify` |
| 02 | сборка iperf3 | `labs/02-source-build/` | SHA-256, `make check`, local test |
| 03 | systemd/cgroup v2 | `labs/03-cgroups/` | `systemctl show`, `systemd-cgls` |
| 04 | Cockpit и management zone | `labs/04-cockpit/` | `firewall-cmd`, позитивный/негативный curl |
| 05 | dummy, conntrack, nftables | `labs/05-kernel-netfilter/` | `nft -c`, counter, conntrack |
| 06 | UNIX mode, ACL, inode flags | `labs/06-filesystem-acl/` | allow/deny tests |
| 07 | RAID1 и hot spare | `labs/07-raid/` | read-only preflight, `mdadm --detail` |
| 08 | LVM, snapshot, thin pool | `labs/08-lvm/` | read-only preflight, `pvs/vgs/lvs` |
| 09 | двухпроходная миграция | `labs/09-migration/` | dry-run, checksums, ACL diff |
| 10 | послойная диагностика TLS | `labs/10-network-diagnostics/` | `check-endpoint.sh` |
| 11 | ISC DHCP | `labs/11-dhcp/` | `dhcpd -t` |
| 12 | Samba | `labs/12-samba/` | `testparm -s`, `smbclient` |
| 13 | NFSv4 | `labs/13-nfs/` | `exportfs -rav`, mount tests |
| 14 | BIND authoritative DNS | `labs/14-bind/` | `named-checkconf/checkzone` |
| 15 | Squid forward proxy | `labs/15-squid/` | `squid -k parse` |
| 16 | Nginx, PHP-FPM, MariaDB, WordPress | `labs/16-wordpress/` | `nginx -t`, TLS и permission tests |
| 17 | диагностика iRedMail | `labs/17-iredmail/` | DNS/TLS/SMTP/queue/IMAP/webmail |
| 18 | SSH CA, FIDO2, TOTP | `labs/18-ssh-hardening/` | `sshd -t`, `sshd -T`, отдельный вход |
| 19 | OpenVPN 2.6 | `labs/19-openvpn/` | version, listener, route, negotiated cipher |

`lecture-examples/` содержит исправленные самостоятельные примеры Apache,
Nginx, firewall и TLS, которые упоминаются в лекции, но не образуют отдельной
лабораторной работы. Старые файлы в корне сохранены для совместимости; новые
лабораторные файлы являются каноническими.

## Важные ограничения

- `labs/07-raid/` и `labs/08-lvm/` работают с блочными устройствами. Репозиторий
  намеренно не содержит скрипта, который автоматически форматирует диски.
- Примеры firewall — альтернативы. Не применяйте одновременно raw iptables,
  nftables, UFW и firewalld к одному сопровождаемому ruleset.
- `.test` зарезервирован для тестирования. Все адреса `192.168.*` в шаблонах —
  лабораторные примеры и требуют адаптации.
- Конфиги с placeholder имеют расширение `.template`; после подстановки снимите
  это расширение и выполните проверку синтаксиса.

## Проверка репозитория

Запустите без root:

```bash
./scripts/validate-materials.sh
```

Проверка анализирует shell/Python-синтаксис, наличие поясняющих комментариев,
обязательные файлы и отсутствие секретов в Git. Если профильная программа
установлена, используйте также ее штатную проверку, указанную в таблице.

В `scripts/` также находятся: учебный PKI generator, генератор WordPress salts и
backup/restore-test конфигурации сервиса. Все результаты с секретами храните вне Git.
