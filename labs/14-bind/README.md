# Лабораторная 14. Полный authoritative BIND

Все 22 исходных шага: [WALKTHROUGH.md](WALKTHROUGH.md).
[Общая подготовка](../../PREPARATION.md).
Отдельная DNS-ВМ с заранее назначенным 192.168.10.53/24.
[named-rhel.conf](named-rhel.conf) и [named-debian.conf](named-debian.conf) —
**полные** main config, включая options, controls и обе зоны.
```bash
# Rocky:
sudo dnf install -y bind bind-utils
# Debian/Ubuntu:
sudo apt install -y bind9 bind9-utils dnsutils
named -V
ip -br address
install -d -m 0700 generated/lab14
sed -e 's/192.168.X/192.168.10/g' -e 's/192.168.Z/192.168.30/g' \
  labs/14-bind/db.example.test.template > generated/lab14/db.example.test
cp labs/14-bind/db.192.168.X.template generated/lab14/db.192.168.10
```

Обратный файл содержит только host-октеты, origin приходит из zone declaration.
При изменении записей увеличьте serial в **обоих** файлах, например 2026091101.
DNSSEC/TSIG для dynamic update не нужны: зоны статические, transfer запрещен.
Но нужен **локальный секрет rndc**, создаваемый командой rndc-confgen.

```bash
# Rocky, эта ветка целиком:
sudo cp -a /etc/named.conf /etc/named.conf.before-lpic103
sudo rndc-confgen -a -c /etc/rndc.key
sudo chown root:named /etc/rndc.key
sudo chmod 0640 /etc/rndc.key
sudo install -o root -g named -m 0644 generated/lab14/db.example.test /var/named/db.example.test
sudo install -o root -g named -m 0644 generated/lab14/db.192.168.10 /var/named/db.192.168.10
sudo install -o root -g named -m 0640 labs/14-bind/named-rhel.conf /etc/named.conf
sudo restorecon -v /etc/named.conf /etc/rndc.key /var/named/db.example.test /var/named/db.192.168.10
sudo named-checkconf /etc/named.conf
sudo named-checkzone example.test /var/named/db.example.test
sudo named-checkzone 10.168.192.in-addr.arpa /var/named/db.192.168.10
sudo systemctl enable --now named
sudo systemctl restart named
sudo rndc -k /etc/rndc.key status
```

Если rndc.key уже используется, сохраните его перед генерацией или используйте
существующий с именем ключа rndc-key. Не выводите содержимое ключа в отчет.

```bash
# Debian/Ubuntu — альтернативная полная ветка:
sudo cp -a /etc/bind/named.conf /etc/bind/named.conf.before-lpic103
sudo rndc-confgen -a -c /etc/bind/rndc.key
sudo chown root:bind /etc/bind/rndc.key
sudo chmod 0640 /etc/bind/rndc.key
sudo install -o root -g bind -m 0644 generated/lab14/db.example.test /etc/bind/db.example.test
sudo install -o root -g bind -m 0644 generated/lab14/db.192.168.10 /etc/bind/db.192.168.10
sudo install -o root -g bind -m 0644 labs/14-bind/named-debian.conf /etc/bind/named.conf
sudo named-checkconf /etc/bind/named.conf
sudo named-checkzone example.test /etc/bind/db.example.test
sudo named-checkzone 10.168.192.in-addr.arpa /etc/bind/db.192.168.10
sudo systemctl enable --now named
sudo systemctl restart named
sudo rndc -k /etc/bind/rndc.key status
```

В Debian/Ubuntu unit может иметь alias bind9: проверьте
`systemctl list-unit-files 'named*' 'bind9*'`. `named.service` — основной
в современных пакетах; используйте фактически установленное имя.

```bash
# На сервере, internal замените своей zone:
sudo firewall-cmd --permanent --zone=internal --add-service=dns
sudo firewall-cmd --reload
# Клиент:
dig @192.168.10.53 example.test SOA +norecurse
dig @192.168.10.53 www.example.test A +norecurse
dig @192.168.10.53 example.test MX +norecurse
dig @192.168.10.53 -x 192.168.10.20 +norecurse
dig +tcp @192.168.10.53 example.test SOA +norecurse
```

Нужны status NOERROR, флаг aa, ожидаемые записи и одинаковый SOA serial.
Рекурсивные Internet-запросы не обслуживаются: REFUSED там — ожидаемо.
Ошибка загрузки зоны: journal, serial, полные FQDN с точкой, owner/SELinux.
Откат — восстановить main config и ключ из резервных копий, named-checkconf,
restart. Не оставляйте второй options{} от прежнего конфига.
