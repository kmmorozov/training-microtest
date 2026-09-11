# Лабораторная 11. DHCP: Kea на Rocky Linux 10

Цель: динамический пул, reservation по MAC, DNS и classless route (option 121),
проверенные на клиенте и по обмену DORA. Для Rocky 10 используйте этот сценарий:
ISC DHCP заменён Kea. Готовый **полный** [kea-dhcp4.conf](kea-dhcp4.conf)
устанавливается целиком. Для Rocky 9 / Ubuntu 24.04 есть [ISC-DHCP.md](ISC-DHCP.md).
[WALKTHROUGH.md](WALKTHROUGH.md) сохраняет все 24 шага исходного задания;
на Rocky 10 серверные команды ISC заменяются командами этой страницы.

## 1. Материалы, пакеты и схема

**Зачем: Подготавливаем Kea и изолированный L2-сегмент, чтобы DHCP-эксперимент не затрагивал управляющую сеть и не конкурировал с DHCP гипервизора.**

Выполните [общую подготовку](../../PREPARATION.md). Команды сервера ниже
выполняются из корня репозитория. DHCP не требует сертификатов и закрытых ключей.
Подписи пакетов проверяет DNF ключом дистрибутива.

Сервер имеет management NIC для SSH/пакетов и отдельный `enp0s8` в isolated
virtual switch с адресом `192.168.10.1/24`. Два клиента — в том же switch.
Встроенный DHCP гипервизора на нем выключен. DNS `192.168.10.53` готовится
в lab 14, сеть option 121 — `192.168.20.0/24`. Имена NIC проверьте на ВМ.

```bash
cat /etc/os-release
sudo dnf repolist --enabled
sudo dnf makecache --refresh
dnf info kea
sudo dnf install -y kea tcpdump firewalld NetworkManager bind-utils
rpm -q kea
rpm -ql kea
kea-dhcp4 -V
systemctl cat kea-dhcp4.service
```

Kea находится в штатных репозиториях **Rocky 10**, EPEL ему не нужен.
В проверенном Rocky 10.2 пакет kea 3.0.3 пришел из BaseOS; в других минорных
срезах проверяйте фактический Repo командой dnf info kea. Нужны BaseOS/AppStream.
При `No match for argument: kea` проверьте `rpm -q rocky-release rocky-repos`,
`dnf repolist --all`, DNS и доступ к зеркалам. Если штатные repo отключены:
`sudo dnf --enablerepo=baseos,appstream install kea`.
Не подставляйте RPM от Rocky 9. Документация версии: `rpm -qd kea`,
`man kea-dhcp4`; дополнительные примеры — в `kea-doc`, если пакет доступен.

## 2. Статический адрес DHCP-сервера

**Зачем: Назначаем серверу постоянный адрес в обслуживаемой подсети, сохраняя управляющий маршрут и SSH-доступ.**

```bash
ip -br link
nmcli -f NAME,UUID,DEVICE,TYPE connection show
# Новый профиль создавайте только на отдельном NIC без действующего профиля.
sudo nmcli connection add type ethernet ifname enp0s8 con-name lpic103-dhcp-server \
  ipv4.method manual ipv4.addresses 192.168.10.1/24 \
  ipv4.never-default yes ipv6.method disabled
sudo nmcli connection up lpic103-dhcp-server
ip -br address show enp0s8
ip route show dev enp0s8
```

Ожидается .1/24 и connected route 192.168.10.0/24. При существующем профиле
измените его через `nmcli connection modify ИМЯ ...`, не создавайте второй.
Management default route должен сохраниться.

## 3. Полный конфиг, MAC и option 121

**Зачем: Настраиваем весь DHCP-сценарий — пул, резервирование, DNS и маршруты — и проверяем конфиг до запуска выдачи адресов.**

На втором клиенте выполните `cat /sys/class/net/enp0s8/address`.
Полученный MAC заменяет `02:00:00:00:00:60` в конфиге.
Адрес .60 вручную клиенту не назначайте — это результат DHCP reservation.

```bash
# На сервере: рабочая копия не смешивается с эталоном Git.
install -d -m 0700 generated/lab11
cp labs/11-dhcp/kea-dhcp4.conf generated/lab11/kea-dhcp4.conf
nano generated/lab11/kea-dhcp4.conf
# В редакторе: два вхождения enp0s8 и hw-address клиента.
sudo cp -a /etc/kea/kea-dhcp4.conf /etc/kea/kea-dhcp4.conf.before-lpic103
# Сохраняем пакетные owner/mode файла, заменяем содержимое целиком.
sudo tee /etc/kea/kea-dhcp4.conf < generated/lab11/kea-dhcp4.conf > /dev/null
sudo restorecon -v /etc/kea/kea-dhcp4.conf /var/lib/kea
sudo kea-dhcp4 -t /etc/kea/kea-dhcp4.conf
```

Kea принимает JSON с комментариями: обычный `jq` не является его валидатором.
`-t` проверяет конфиг без выдачи аренды, включая существование NIC из subnet4.
Нужен exit status 0; успешный разбор еще не доказывает доступность порта
и реальную выдачу аренды.

Option 121 содержит default route и 192.168.20.0/24 через .1.
Клиент, поддерживающий 121, может игнорировать option 3, поэтому default
включен в оба варианта. Для другой схемы пересчитайте поле HEX:

```bash
python3 - <<'PY'
import ipaddress
# Каждая запись: длина маски, значимые байты сети, четыре байта шлюза.
routes = [("0.0.0.0/0", "192.168.10.1"), ("192.168.20.0/24", "192.168.10.1")]
result = b""
for prefix, gateway in routes:
    net = ipaddress.ip_network(prefix)
    result += bytes([net.prefixlen])
    result += net.network_address.packed[:(net.prefixlen + 7) // 8]
    result += ipaddress.ip_address(gateway).packed
print(result.hex())
PY
```

Вывод: `00c0a80a0118c0a814c0a80a01`.
Объявление маршрута не включает IP forwarding/NAT. Для реального ping в Y
нужны второй NIC маршрутизатора, forwarding firewall и обратный маршрут.
Установка маршрута на клиенте проверяется независимо от готовности сети Y.

## 4. Firewall и служба

**Зачем: Ограничиваем DHCP учебным интерфейсом и запускаем службу, чтобы клиенты могли получить аренду без открытия сервера в других сетях.**

```bash
# Локальная проверка конкурентов не обнаруживает DHCP другой ВМ.
systemctl list-units --type=service --state=running 'dhcp*' 'kea*' 'dnsmasq*'
sudo ss -lunp 'sport = :67'
sudo systemctl enable --now firewalld
# --new-zone выполняется один раз; при повторе zone уже существует.
sudo firewall-cmd --permanent --new-zone=lpic103-dhcp
sudo firewall-cmd --reload
sudo nmcli connection modify lpic103-dhcp-server connection.zone lpic103-dhcp
sudo firewall-cmd --permanent --zone=lpic103-dhcp --add-interface=enp0s8
sudo firewall-cmd --permanent --zone=lpic103-dhcp --add-service=dhcp
sudo firewall-cmd --reload
sudo firewall-cmd --zone=lpic103-dhcp --list-all
sudo systemctl enable --now kea-dhcp4.service
systemctl is-active kea-dhcp4.service
sudo journalctl -u kea-dhcp4 --since '-3 min' --no-pager
```

Зона привязана к NIC: первый DISCOVER имеет source 0.0.0.0, поэтому ACL только
по source subnet его не охватывает. Для raw sockets `ss -lunp` недостаточно:
фактическую выдачу доказывают журнал, tcpdump и клиент. Не выключайте dnsmasq
management NAT вслепую: учебный L2 должен быть отдельным.

## 5. Проверка клиента, вывода и продления

**Зачем: Проверяем выдачу и продление аренды, резервирование и применение опций на клиенте: успешного запуска службы для приемки недостаточно.**

На Rocky 10 DHCP-клиент встроен в NetworkManager, `dhclient` не нужен.
Переключение профиля выполняйте с консоли клиента, не через его lab-адрес.

```bash
# Сервер, отдельный терминал до активации клиента:
sudo tcpdump -ni enp0s8 -vvv 'udp port 67 or udp port 68'

# Клиент, отдельный новый NIC:
sudo nmcli connection add type ethernet ifname enp0s8 con-name lpic103-dhcp-client \
  ipv4.method auto ipv4.ignore-auto-dns no ipv4.ignore-auto-routes no \
  ipv4.route-metric 600 ipv6.method disabled
sudo nmcli connection up lpic103-dhcp-client
ip -4 address show dev enp0s8
nmcli -f GENERAL,IP4,DHCP4 device show enp0s8
ip -4 route show
ip route get 192.168.20.10
dig @192.168.10.53 example.test SOA
```

Первый клиент получает .100–.150, клиент с зарезервированным MAC — .60.
Метрика 600 сохраняет приоритет management default при меньшей его метрике.
Ожидаемый характерный вывод (конкретный адрес/индекс опции меняется):

```text
inet 192.168.10.100/24 ... dynamic ...
192.168.20.0/24 via 192.168.10.1 dev enp0s8 proto dhcp metric 600
default via 192.168.10.1 dev enp0s8 proto dhcp metric 600
DHCP4.OPTION[...] domain_name_servers = 192.168.10.53
DHCP4.OPTION[...] dhcp_lease_time = 600
```

В tcpdump: Discover → Offer → Request → ACK; Server Identifier только .1.
Проверьте DNS, lease 600 s и option 121 в ACK.
`resolvectl` нужен только системам с systemd-resolved; здесь достаточно nmcli.

```bash
# На клиенте, чтобы повторить REQUEST/ACK:
sudo nmcli connection down lpic103-dhcp-client
sudo nmcli connection up lpic103-dhcp-client
# На сервере:
sudo head -n 1 /var/lib/kea/kea-leases4.csv
sudo tail -n 10 /var/lib/kea/kea-leases4.csv
sudo journalctl -u kea-dhcp4 --since '-5 min' --no-pager
```

Memfile хранит историю обновлений: повторяющийся IP не обязательно означает
несколько активных клиентов. Не редактируйте CSV работающего daemon.

## 6. Ошибки, приемка и откат

**Зачем: Сопоставляем ошибки с интерфейсом, конфигом и журналом и готовим возврат исходных настроек, чтобы безопасно завершить эксперимент.**

| Симптом | Проверка |
|---|---|
| `dhcp-server` не найден | На Rocky 10 нужен `kea` |
| `kea` не найден | BaseOS/AppStream, релиз/архитектура, DNS, метаданные |
| `-t` не проходит | Скобки, запятые, тип значения и путь ошибки |
| Нет DISCOVER | NIC клиента, virtual switch, активный профиль NM |
| DISCOVER есть, OFFER нет | NIC/адрес сервера, subnet4, journal, доступный пул |
| Два OFFER | Второй DHCP, в том числе встроенный в гипервизор |
| Reservation не совпала | MAC в пакете, а не предполагаемый MAC ВМ |
| Нет route 121 | HEX, ACK, ignore-auto-routes и never-default |
| DNS .53 выдан, lookup не работает | Lab 14 и firewall TCP/UDP 53 |
| CSV Permission denied | owner пакетного каталога, unit User, SELinux AVC |

Приемка: правильные адреса двух клиентов, DNS/lease options, маршрут Y,
один сервер в DORA, отсутствие ошибок journal.

```bash
# Откат к резервной копии конфигурации; запуск только после успешного -t.
sudo systemctl stop kea-dhcp4
sudo cp -a /etc/kea/kea-dhcp4.conf.before-lpic103 /etc/kea/kea-dhcp4.conf
sudo restorecon -v /etc/kea/kea-dhcp4.conf
sudo kea-dhcp4 -t /etc/kea/kea-dhcp4.conf
# Учебные NM-профили удаляются с консоли соответствующей ВМ:
# sudo nmcli connection delete lpic103-dhcp-client
# sudo nmcli connection delete lpic103-dhcp-server
```

Источники: [Rocky 10 release notes](https://docs.rockylinux.org/latest/releases/release_notes/10_0/),
[DHCP в RHEL 10](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/managing_networking_infrastructure_services/providing-dhcp-services),
[ISC Kea 2.6 ARM](https://kea.readthedocs.io/en/kea-2.6.1/arm/dhcp4-srv.html).
Сверено 11.09.2026; фактическую версию фиксируйте через `rpm -q kea`.
