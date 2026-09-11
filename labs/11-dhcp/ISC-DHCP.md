# ISC DHCP: отдельная ветка для Rocky 9 и Ubuntu 24.04

На Rocky 10 выполняйте [Kea README](README.md). Здесь сохранен сценарий
исходного руководства: [24 шага](WALKTHROUGH.md). Не запускать ISC и Kea
одновременно в одном L2. Схема и подготовка клиентов — как в Kea README.

```bash
# Rocky 9:
sudo dnf install -y dhcp-server tcpdump
# Ubuntu 24.04:
sudo apt update
sudo apt install -y isc-dhcp-server tcpdump
# Из корня репозитория, заменяем ВСЕ X/Y, в том числе десятичные байты option 121.
install -d -m 0700 generated/lab11
sed -e 's/X/10/g' -e 's/Y/20/g' \
  -e 's/<MAC-client-2>/02:00:00:00:00:60/g' \
  labs/11-dhcp/dhcpd.conf.template > generated/lab11/dhcpd.conf
# Подставьте реальный MAC второго клиента.
nano generated/lab11/dhcpd.conf
sudo install -m 0644 generated/lab11/dhcpd.conf /etc/dhcp/dhcpd.conf
sudo dhcpd -t -cf /etc/dhcp/dhcpd.conf
```

Rocky 9: сервер слушает подсети, соответствующие адресам NIC. Для явного
ограничения NIC используйте полный drop-in [dhcpd-interface.conf](dhcpd-interface.conf):
замените enp0s8, установите /etc/systemd/system/dhcpd.service.d/override.conf,
`systemctl daemon-reload`, `systemctl enable --now dhcpd`.
Не рассчитывайте на /etc/sysconfig/dhcpd, если unit не читает DHCPDARGS:
это проверяется `systemctl cat dhcpd`.

Ubuntu: установите полный isc-dhcp-server.default.template после подстановки
enp0s8 как /etc/default/isc-dhcp-server, затем
`systemctl enable --now isc-dhcp-server`. На обоих вариантах откройте
service dhcp именно в interface zone из Kea README.

Вывод: `systemctl is-active` active, `journalctl -u ИМЯ` без ошибок,
адрес обычного клиента .100–.150, reservation .60, маршруты default/Y и DNS .53.
Серверный lease file: Rocky /var/lib/dhcpd/dhcpd.leases,
Ubuntu /var/lib/dhcp/dhcpd.leases. Клиент Rocky 10 использует nmcli,
даже если сервер — старый ISC. `<lab-connection>` в исходных командах —
имя профиля `nmcli connection show`, а не имя NIC.

Откат: stop службы, восстановить сохраненный dhcpd.conf, syntax check.
Ключи для этого протокола не требуются; пароль/сертификат из другой лабы
не используется для выдачи IP.
