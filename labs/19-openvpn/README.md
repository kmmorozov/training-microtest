# Лабораторная 19: OpenVPN 2.6

## PKI

Запустите `scripts/generate-lab-pki.sh`. На сервер установите `ca.crt`,
`server.crt`, `server.key`, `tls-crypt.key`; на клиент — `ca.crt`, `client.crt`,
`client.key`, `tls-crypt.key`. Public certificates имеют mode 0644, private keys —
0600. Для реальной инфраструктуры используйте отдельный offline CA и процедуру
отзыва; этот генератор предназначен только для изолированного стенда.

## Сервер

Подставьте X/Y в `server-lpic103.conf.template`, установите как
`/etc/openvpn/server/lpic103.conf`, а PKI — в `/etc/openvpn/server/pki/`.
Установите sysctl-файл в `/etc/sysctl.d/`, выполните `sysctl --system`, затем
примените одну firewall-ветку. На LAN-маршрутизаторе нужен обратный маршрут к
`192.168.Y.0/24` через LAN-адрес VPN-сервера.

## Клиент и приемка

Установите профиль как `/etc/openvpn/client/lpic103.conf`. Проверьте имя template
unit через `systemctl list-unit-files 'openvpn*'`; типовой запуск —
`openvpn-server@lpic103` и `openvpn-client@lpic103`.

```bash
openvpn --version | head -3
sudo ss -lunp 'sport = :1194'
ip -br address show type tun
ip route get 192.168.X.20
journalctl -u openvpn-client@lpic103 --since '-5 min' | grep -E 'Initialization Sequence Completed|Data Channel'
```

Compression и redirect-gateway намеренно отсутствуют: клиент получает только
маршрут к лабораторной LAN.
