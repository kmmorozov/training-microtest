# Лабораторная 19. OpenVPN: полный сервер, клиент и маршрутизация

Все 35 шагов, команды и вывод: [WALKTHROUGH.md](WALKTHROUGH.md).
[Общая подготовка](../../PREPARATION.md).
Сервер: LAN 192.168.10.10, внешняя учебная сеть 192.168.30.10;
клиент находится только в 192.168.30.0/24, VPN pool 192.168.20.0/24.
Внутренний узел проверки — 192.168.10.20. Сети не пересекаются.
```bash
# Rocky server/client: EPEL/CRB по общей подготовке.
sudo dnf install -y openvpn openssl firewalld
# Ubuntu/Debian:
sudo apt install -y openvpn openssl
openvpn --version
systemctl list-unit-files 'openvpn*'
```

Сценарий рассчитан на 2.6; при другой версии сверяйте parser/список ciphers.
Private keys не скачиваются. На CA-host запустите полный
`./scripts/generate-lab-pki.sh "$REPO/generated/vpn-pki"` (без --tls-only).
По PREPARATION передайте серверу ca.crt/server.crt/server.key/tls-crypt.key,
клиенту ca.crt/client.crt/client.key/tls-crypt.key. У каждого PKI — его каталог.

## 1. Полный конфиг сервера

**Зачем: Устанавливаем полный серверный профиль и необходимые сертификаты и ключи, чтобы VPN-сервер мог взаимно аутентифицироваться с клиентами.**

```bash
# Сервер:
sudo install -d -m 0750 /etc/openvpn/server/pki
sudo install -m 0644 "$PKI/ca.crt" "$PKI/server.crt" /etc/openvpn/server/pki/
sudo install -m 0600 "$PKI/server.key" "$PKI/tls-crypt.key" /etc/openvpn/server/pki/
openssl verify -purpose sslserver -CAfile "$PKI/ca.crt" "$PKI/server.crt"
openssl x509 -in "$PKI/server.crt" -noout -subject -ext extendedKeyUsage
install -d -m 0700 generated/lab19
sed -e 's/192.168.X/192.168.10/g' -e 's/192.168.Y/192.168.20/g' \
  labs/19-openvpn/server-lpic103.conf.template > generated/lab19/server.conf
sudo install -m 0644 generated/lab19/server.conf /etc/openvpn/server/lpic103.conf
sudo install -m 0644 labs/19-openvpn/60-lpic103-openvpn.conf /etc/sysctl.d/60-lpic103-openvpn.conf
sudo sysctl -p /etc/sysctl.d/60-lpic103-openvpn.conf
sysctl net.ipv4.ip_forward
```

Перед этим назначьте оба статических интерфейса через NetworkManager,
проверьте `ip -br address`. Не включайте redirect-gateway/compression:
в упражнении только маршрут к LAN.
Server profile и client profile в каталоге — полные конфиги OpenVPN.

## 2. Firewall и обратный маршрут

**Зачем: Настраиваем входящий VPN-трафик, пересылку и обратный маршрут, чтобы внутренние узлы могли обмениваться данными с клиентами туннеля.**

Полный firewalld.sh.template создает ingress UDP1194 только от сети Z,
VPN source zone и policy forwarding к LAN.
```bash
sudo firewall-cmd --get-active-zones
# Пример: внешний интерфейс уже в external, внутренний — internal.
sed -e 's/<external-zone>/external/g' -e 's/<lab-zone>/internal/g' \
  -e 's/192.168.Z/192.168.30/g' -e 's/192.168.Y/192.168.20/g' \
  labs/19-openvpn/firewalld.sh.template > generated/lab19/firewalld.sh
bash -n generated/lab19/firewalld.sh
bash generated/lab19/firewalld.sh
sudo firewall-cmd --info-policy=lpic103VpnToLab
# На LAN-маршрутизаторе, не на клиенте VPN:
sudo ip route add 192.168.20.0/24 via 192.168.10.10
```

Если отдельного LAN-маршрутизатора нет, добавьте этот обратный маршрут
непосредственно на тестовом узле .20. Ответы должны возвращаться к VPN pool
через .10. Firewalld stateful разрешает обратный ESTABLISHED/RELATED.
Не добавляйте masquerade только для обхода непонятной ошибки: он меняет
проверяемую схему. На .20 разрешите тестируемый сервис/ICMP от VPN subnet.
Вне firewalld используйте отдельную согласованную policy своего firewall,
не применяйте одновременно raw iptables из корня.

```bash
# Сервер:
sudo systemctl enable --now openvpn-server@lpic103
sudo journalctl -u openvpn-server@lpic103 --since '-3 min' --no-pager
sudo ss -lunp 'sport = :1194'
```

У OpenVPN нет универсального `-t` как nginx. Проверка parser происходит при
контролируемом старте отдельного lab-unit: ошибка должна остановить дальнейшие
шаги. `--test-crypto` не доказывает корректность всего TLS/server config.

## 3. Клиент, имя сервера и приемка

**Зачем: Запускаем клиент с проверкой роли и имени сервера, затем проверяем туннель, маршруты и доступ к LAN для сквозной приемки.**

Имя vpn.example.test должно разрешаться **до VPN** в 192.168.30.10:
добавьте его в hosts клиента или во внешний DNS. Внутренний DNS через еще
не поднятый tunnel не подходит.
```bash
sudo install -d -m 0750 /etc/openvpn/client/pki
sudo install -m 0644 "$PKI/ca.crt" "$PKI/client.crt" /etc/openvpn/client/pki/
sudo install -m 0600 "$PKI/client.key" "$PKI/tls-crypt.key" /etc/openvpn/client/pki/
openssl verify -purpose sslclient -CAfile "$PKI/ca.crt" "$PKI/client.crt"
sudo install -m 0644 labs/19-openvpn/client-lpic103.conf /etc/openvpn/client/lpic103.conf
getent ahostsv4 vpn.example.test
sudo systemctl enable --now openvpn-client@lpic103
sudo journalctl -u openvpn-client@lpic103 --since '-3 min' --no-pager
ip -br address show type tun
ip route get 192.168.10.20
ping -c 3 192.168.10.20
```

Нужны Initialization Sequence Completed, tun адрес из Y, маршрут к .20 через
tun и согласованный AEAD cipher в Data Channel. `remote-cert-tls server`
проверяет назначение, `verify-x509-name` — имя сертификата. Отключение этих
проверок не является исправлением mismatch.
Если tunnel поднят, но ping нет: сервер forwarding, policy, обратный маршрут,
firewall .20 и отсутствие пересечения локальной LAN клиента с сетью X.

Отрицательная проверка: остановить клиент и убедиться, что внутренний сервис
недоступен по прежнему пути. Откат: stop/disable двух lab-units, убрать только
созданную VPN policy/source-zone и точный обратный маршрут
`ip route del 192.168.20.0/24 via 192.168.10.10`. Верните прежнее значение
ip_forward, если оно было0 и другие сервисы не требуют маршрутизации.
