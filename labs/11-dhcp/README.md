# Лабораторная 11: ISC DHCP

Подставьте X, Y, MAC и интерфейс. До запуска убедитесь, что сегмент изолирован и
в нем нет другого UDP/67 listener.

```bash
sudo install -m 0644 dhcpd.conf /etc/dhcp/dhcpd.conf
sudo dhcpd -t -cf /etc/dhcp/dhcpd.conf
sudo ss -lunp 'sport = :67'
```

Выберите только один platform-файл привязки интерфейса. После запуска проверьте
lease на обычном и зарезервированном клиентах, а затем `ip route` и DNS через
`resolvectl status <lab-iface>` или `nmcli device show <lab-iface>`.
