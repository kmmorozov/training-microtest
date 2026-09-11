# Лабораторная работа 19. OpenVPN 2.6: защищенный маршрут к лабораторной сети

[Подготовка, пакеты, полные конфиги и уточнения](README.md) · [Общие материалы и ключи](../../PREPARATION.md)

Ниже все шаги руководства лабораторных v4 от 10.08.2026 с сохраненными
командами и ожидаемыми результатами. Сначала выполните подготовку в README:
она определяет адреса, значения переменных и различия ОС. Команды выполняются
по одной, на указанной машине; альтернативные ветки ОС не выполняются вместе.
В командах по умолчанию X=10/Y=20/Z=30, lab NIC=enp0s8, зоны internal/external/public.
Их необходимо сопоставить с реальными NIC/zone по README. Имена unit и web-user
по умолчанию Rocky; для Debian/Ubuntu используйте соответствия из README.
Выводы — образцы, а не протокол запуска на вашей ВМ.

Цель лабораторной работы: запустить route-based VPN с современными AEAD ciphers, проверить подлинность сервера, адрес туннеля и маршрут к одной лабораторной сети.

Стенд: двухинтерфейсный VPN-сервер vpn.example.test: внешний адрес 192.168.30.10, LAN-адрес 192.168.10.10; клиент 192.168.30.100, внутренняя сеть 192.168.10.0/24, VPN-пул 192.168.20.0/24. X, Y и Z заменяются фактическими различными номерами подсетей; CA/cert/key/tls-crypt key предоставляет преподаватель.

Сценарий: удаленный администратор подключается к учебной сети через OpenVPN 2.6. Сервер выдает адрес из отдельного пула и только маршрут к лабораторной LAN; обратный маршрут на LAN указывает на VPN-сервер.

Планируемый результат: клиент получает tun-адрес из 192.168.20.0/24 и маршрут к 192.168.10.0/24; имя VPN-сервера проверено, data cipher согласован, UDP/1194 и forwarding ограничены учебными сетями.

## Ограничения и безопасность

Важно: не используйте compression: она отключена из-за атак на confidentiality.

Важно: Private keys и tls-crypt key не выводятся на экран и не копируются за пределы стенда; конфигурация использует только учебную сеть.

## Ход выполнения

## Шаг 1. Установить требуемые пакеты

Установите OpenVPN из package repository, затем уточните версию и шаблон unit: используются openvpn-server@.service или openvpn@.service. Установите пакеты только для выбранного семейства ОС. Ключ -y подтверждает пакетную транзакцию без дополнительного запроса.

```bash
# RHEL-like
sudo dnf install -y openvpn
```

## Шаг 2. Обновить метаданные пакетов

Обновите локальные метаданные репозиториев до установки пакетов; это действие не устанавливает и не обновляет сами пакеты.

```bash
# Debian/Ubuntu — альтернатива
sudo apt update
```

## Шаг 3. Установить требуемые пакеты

Установите пакеты только для выбранного семейства ОС. Ключ -y подтверждает пакетную транзакцию без дополнительного запроса.

```bash
# Debian/Ubuntu — альтернатива
sudo apt install -y openvpn
```

## Шаг 4. Проверить OpenVPN

Проверьте установленную ветку OpenVPN до применения конфигурации: работа рассчитана на синтаксис и поведение версии 2.6.

```bash
openvpn --version | head -3
```

Ожидаемый вывод и результат:

```text
OpenVPN 2.6.<версия> ...
```

## Шаг 5. Найти доступные unit-файлы

Команда обращается к systemd. enable управляет автозапуском, --now также меняет текущее состояние, status/show читают фактические свойства, reload применяет проверенную конфигурацию без полного restart.

```bash
systemctl list-unit-files 'openvpn*'
```

Ожидаемый вывод и результат:

```text
<unit>.service enabled/disabled/static
```

## Шаг 6. Создать каталог с заданными правами

Команда install создает каталог или копирует файл сразу с заданными владельцем и mode: -d выбирает каталог, -m задает права, -o/-g — владельца и группу.

```bash
sudo install -d -m 0750 /etc/openvpn/server/pki
```

## Шаг 7. Скопировать объект с заданными правами

```bash
sudo install -m 0644 "$PKI/ca.crt" "$PKI/server.crt" /etc/openvpn/server/pki/
```

## Шаг 8. Скопировать объект с заданными правами

```bash
sudo install -m 0600 "$PKI/server.key" "$PKI/tls-crypt.key" /etc/openvpn/server/pki/
```

OpenVPN 2.6.x и фактический template unit зафиксированы.

## Шаг 9. Настроить /etc/openvpn/server/lpic103.conf

topology subnet упрощает маршруты, tls-crypt защищает control channel, data-ciphers разрешает только AEAD. verify-client-cert требует client certificate.

```bash
sudoedit /etc/openvpn/server/lpic103.conf
```

Содержимое редактируемого файла (полный комментированный вариант находится рядом):

```text
# 192.168.20.0/24 — VPN-пул; 192.168.10.0/24 — серверная LAN.
port 1194
proto udp
dev tun
topology subnet
server 192.168.20.0 255.255.255.0
ca /etc/openvpn/server/pki/ca.crt
cert /etc/openvpn/server/pki/server.crt
key /etc/openvpn/server/pki/server.key
dh none
tls-crypt /etc/openvpn/server/pki/tls-crypt.key
verify-client-cert require
data-ciphers AES-256-GCM:AES-128-GCM:?CHACHA20-POLY1305
push "route 192.168.10.0 255.255.255.0"
keepalive 10 60
persist-key
persist-tun
explicit-exit-notify 1
verb 3
```

## Шаг 10. Включить автозапуск службы

```bash
sudo systemctl enable --now openvpn-server@lpic103.service
```

Ожидаемый вывод и результат:

```text
Created symlink ... (при первом включении); exit status = 0
```

## Шаг 11. Проверить состояние службы

```bash
systemctl status openvpn-server@lpic103.service --no-pager
```

Ожидаемый вывод и результат:

```text
Active: active (running) ...
Loaded: loaded (...)
```

## Шаг 12. Проверить сетевой listener

Проверьте реальный socket, адрес, порт и процесс-владелец; состояние службы само по себе не доказывает наличие listener.

```bash
sudo ss -lunp 'sport = :1194'
```

Ожидаемый вывод и результат:

```text
UNCONN ... <адрес>:<UDP-порт> ... users:(("<процесс>",pid=<PID>))
```

## Шаг 13. Просмотреть журнал службы

Выберите журнал нужного unit и ограничьте временной диапазон, чтобы связать сообщение с только что выполненным действием.

```bash
sudo journalctl -u openvpn-server@lpic103.service --since '-5 min' --no-pager
```

Ожидаемый вывод и результат:

```text
... <unit>[PID]: <сообщение, относящееся к текущему действию> ...
```

UDP/1194 слушается; journal содержит Initialization Sequence Completed.

## Шаг 14. Сформировать или вывести контрольные данные

VPN требует не только listener: включите IPv4 forwarding, разрешите UDP/1194 только клиентской подсети и forwarding из VPN в лабораторную LAN. На LAN должен существовать обратный route 192.168.20.0/24 через VPN-сервер. Получите одно наблюдение ядра или примените один параметр; вывод нужен для связи пакета, модуля и состояния системы.

```bash
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/60-lpic103-openvpn.conf
```

## Шаг 15. Применить или проверить параметр ядра

Получите одно наблюдение ядра или примените один параметр; вывод нужен для связи пакета, модуля и состояния системы.

```bash
sudo sysctl --system
```

Ожидаемый вывод и результат:

```text
<параметр> = <значение>
```

## Шаг 16. Применить или проверить параметр ядра

```bash
sysctl net.ipv4.ip_forward
```

Ожидаемый вывод и результат:

```text
<параметр> = <значение>
```

## Шаг 17. Изменить или проверить правило firewall

Создайте permanent firewalld-правила только для учебных сетей, затем примените их одним reload после настройки zone и policy. Для UFW используйте отдельную альтернативную ветку ниже.

```bash
# 192.168.30.0/24 — внешняя подсеть VPN-клиентов
sudo firewall-cmd --permanent --zone=external --add-rich-rule='rule family=ipv4 source address=192.168.30.0/24 port port=1194 protocol=udp accept'
```

## Шаг 18. Изменить или проверить правило firewall

```bash
sudo firewall-cmd --permanent --get-zones | tr ' ' '\n' | grep -qx lpic103-vpn || sudo firewall-cmd --permanent --new-zone=lpic103-vpn
```

## Шаг 19. Изменить или проверить правило firewall

```bash
# 192.168.20.0/24 — адресный пул VPN-клиентов
sudo firewall-cmd --permanent --zone=lpic103-vpn --add-source=192.168.20.0/24
```

## Шаг 20. Изменить или проверить правило firewall

```bash
sudo firewall-cmd --permanent --get-policies | tr ' ' '\n' | grep -qx lpic103VpnToLab || sudo firewall-cmd --permanent --new-policy=lpic103VpnToLab
```

## Шаг 21. Изменить или проверить правило firewall

```bash
sudo firewall-cmd --permanent --policy=lpic103VpnToLab --add-ingress-zone=lpic103-vpn
```

## Шаг 22. Изменить или проверить правило firewall

```bash
sudo firewall-cmd --permanent --policy=lpic103VpnToLab --add-egress-zone=internal
```

## Шаг 23. Изменить или проверить правило firewall

```bash
sudo firewall-cmd --permanent --policy=lpic103VpnToLab --set-target=ACCEPT
```

## Шаг 24. Изменить или проверить правило firewall

```bash
sudo firewall-cmd --reload
```

## Шаг 25. Изменить или проверить правило firewall

```bash
# 192.168.30.0/24 — внешняя подсеть VPN-клиентов
# UFW — альтернатива firewalld
sudo ufw allow from 192.168.30.0/24 to any port 1194 proto udp
```

## Шаг 26. Изменить или проверить правило firewall

```bash
# 192.168.20.0/24 — VPN-клиенты; 192.168.10.0/24 — серверная LAN
sudo ufw route allow in on tun0 out on enp0s8 from 192.168.20.0/24 to 192.168.10.0/24
```

## Шаг 27. Проверить сетевую конфигурацию

Проверьте один уровень сетевой конфигурации: интерфейс, адрес, маршрут, DNS или профиль соединения.

```bash
# 192.168.10.10 — LAN-адрес VPN-сервера; маршрут ведет к VPN-клиентам
# На маршрутизаторе лабораторной LAN, не на произвольном production-router
sudo ip route add 192.168.20.0/24 via 192.168.10.10
```

Ожидаемый вывод и результат:

```text
<сеть> via <gateway> dev <интерфейс>
```

ip_forward=1; UDP/1194 закрыт другим источникам; return route указывает на VPN-сервер.

## Шаг 28. Создать каталог PKI на OpenVPN-клиенте

На клиенте создайте отдельный закрытый каталог для доверенного CA, клиентского сертификата, закрытого ключа и общей копии tls-crypt key.

```bash
sudo install -d -m 0750 /etc/openvpn/client/pki
```

## Шаг 29. Установить открытые сертификаты на OpenVPN-клиенте

```bash
sudo install -m 0644 "$PKI/ca.crt" "$PKI/client.crt" /etc/openvpn/client/pki/
```

## Шаг 30. Установить закрытые ключи на OpenVPN-клиенте

Закрытый ключ клиента и tls-crypt key доступны только root; их содержимое не выводится в терминал.

```bash
sudo install -m 0600 "$PKI/client.key" "$PKI/tls-crypt.key" /etc/openvpn/client/pki/
```

## Шаг 31. Настроить /etc/openvpn/client/lpic103.conf

remote-cert-tls и verify-x509-name не дают принять client certificate или сервер с другим именем. auth-nocache уменьшает время хранения credentials.

```bash
sudoedit /etc/openvpn/client/lpic103.conf
```

Содержимое редактируемого файла (полный комментированный вариант находится рядом):

```text
client
dev tun
proto udp
remote vpn.example.test 1194
nobind
ca /etc/openvpn/client/pki/ca.crt
cert /etc/openvpn/client/pki/client.crt
key /etc/openvpn/client/pki/client.key
tls-crypt /etc/openvpn/client/pki/tls-crypt.key
remote-cert-tls server
verify-x509-name vpn.example.test name
data-ciphers AES-256-GCM:AES-128-GCM:?CHACHA20-POLY1305
auth-nocache
persist-key
persist-tun
verb 3
```

## Шаг 32. Запустить или перезапустить службу

```bash
sudo systemctl start openvpn-client@lpic103.service
```

## Шаг 33. Проверить сетевую конфигурацию

```bash
ip -br address show type tun
```

Ожидаемый вывод и результат:

```text
<интерфейс> UP <адрес>/<prefix>
```

## Шаг 34. Проверить сетевую конфигурацию

```bash
# 192.168.10.20 — внутренний сервер, доступный через VPN
ip route get 192.168.10.20
```

Ожидаемый вывод и результат:

```text
<сеть> via <gateway> dev <интерфейс>
```

## Шаг 35. Просмотреть журнал службы

```bash
sudo journalctl -u openvpn-client@lpic103.service --since '-5 min' --no-pager | grep -E 'Initialization Sequence Completed|Data Channel'
```

Ожидаемый вывод и результат:

```text
... <unit>[PID]: <сообщение, относящееся к текущему действию> ...
```

tun address из 192.168.20.0/24; route идет через tun; negotiated cipher входит в data-ciphers.
