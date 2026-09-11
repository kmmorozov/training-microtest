# Параметры лабораторного стенда

Перед работой выберите три **различных** номера подсетей и замените placeholders.

| Обозначение | Назначение | Пример |
|---|---|---|
| `X` | внутренняя/LAN сеть | `10` → `192.168.10.0/24` |
| `Y` | пользовательская сеть или VPN pool | `20` → `192.168.20.0/24` |
| `Z` | внешняя сеть VPN | `30` → `192.168.30.0/24` |

Основные имена: `ns1.example.test` (`.53`), `files.example.test` (`.20`),
`mail.example.test` (`.25`), `wp.example.test`, `app.example.test`,
`vpn.example.test`. Используйте фактические адреса своего изолированного стенда.

## Полная карта примера X=10, Y=20, Z=30

| Роль | Адрес | Где нужна |
|---|---|---|
| DHCP server / учебный router | 192.168.10.1 | 11 |
| app / WordPress / Cockpit | 192.168.10.10 | 04, 10, 16 |
| Samba / NFS | 192.168.10.20 | 12, 13 |
| Почта | 192.168.10.25 | 17 |
| Squid | 192.168.10.40 | 15 |
| Authoritative BIND | 192.168.10.53 | 14 |
| Reservation client | 192.168.10.60 | 11 |
| Обычный клиент | 192.168.10.100 | сетевые лабы |
| Динамический DHCP pool | 192.168.10.100–150 | 11 |
| VPN server LAN / outside | 192.168.10.10 / 192.168.30.10 | 19 |
| VPN client outside | 192.168.30.100 | 19 |
| VPN pool | 192.168.20.0/24 | 19 |
| SSH CA-host | 192.168.10.200 либо offline | 18 |

Адрес .10 повторяется в независимых лабораторных: используйте одну ВМ по
этапам/snapshots либо разные адреса и согласованно исправленные DNS/конфиги.
Нельзя включать две ВМ с одним IP одновременно. В lab11 не назначайте клиенту
.100 статически: этот адрес приходит из DHCP; исключите другие статические
клиенты из пула либо выполняйте эту лабораторную на отдельном switch.

До lab14 разрешено дополнить /etc/hosts нужной машины строками:

```text
192.168.10.10 app.example.test wp.example.test allowed.example.test blocked.example.test
192.168.10.20 files.example.test www.example.test
192.168.10.25 mail.example.test
192.168.10.53 ns1.example.test
192.168.30.10 vpn.example.test
```

Сохраните все исходные строки localhost. Hosts не создает MX/PTR и не заменяет
задание BIND. Forward proxy разрешает имя origin сам — hosts клиента недостаточно.
Authoritative DNS не выполняет Internet recursion: для скачивания пакетов
сохраните management resolver либо настройте split DNS осознанно.

enp0s8 — пример lab NIC; имена и NetworkManager profile определяются
`ip -br link` и `nmcli connection show`. Для отдельного static lab NIC:

```bash
sudo nmcli connection add type ethernet ifname enp0s8 con-name lpic103-lan \
  ipv4.method manual ipv4.addresses 192.168.10.10/24 \
  ipv4.never-default yes ipv6.method disabled connection.zone internal
sudo nmcli connection up lpic103-lan
```

Для другой роли замените адрес из таблицы; если профиль уже есть, используйте
connection modify его имени, а не создавайте конкурирующий профиль.
Ubuntu Server без NetworkManager использует Netplan: полный пример
[netplan-server.yaml](lecture-examples/network/netplan-server.yaml) использует
networkd, management DHCP и отдельный статический lab NIC. Выполняйте из консоли:

```bash
ip -br link
ls /etc/netplan
# Укажите фактически существующий основной YAML вашей чистой ВМ.
NETPLAN_FILE=/etc/netplan/50-cloud-init.yaml
sudo cp -a "$NETPLAN_FILE" "$NETPLAN_FILE.before-lpic103"
sudo install -m 0600 lecture-examples/network/netplan-server.yaml "$NETPLAN_FILE"
sudoedit "$NETPLAN_FILE"
# В редакторе сверить оба NIC и адрес роли, затем проверить и применить с откатом.
sudo netplan generate
sudo netplan try --timeout 60
ip -br address
ip route
```

Если в /etc/netplan несколько YAML, они сливаются: этот полный пример не должен
конфликтовать с другим определением тех же NIC. На чистой учебной ВМ сохраните
конкурирующий YAML с расширением .before-lpic103 перед применением.
Cloud-init может пересоздать свой файл: учитывайте его сетевую настройку.
При networkd используйте ip/resolvectl вместо nmcli; nmcli-DHCP ветка lab11
описана для Rocky10. Не назначайте один NIC одновременно Netplan/networkd
и NetworkManager.

Перед заменой конфигурации полезно найти незаполненные значения:

```bash
rg -n '192\.168\.[XYZ]|<[^>]+>' labs
```

Никогда не запускайте DHCP в сети с существующим DHCP-сервером. Диски для
лабораторных 07 и 08 должны быть отдельными пустыми учебными устройствами.
