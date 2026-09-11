# Лабораторная 05. Dummy, conntrack и счетчик nftables

Все 18 шагов с разбором: [WALKTHROUGH.md](WALKTHROUGH.md).
[Подготовка](../../PREPARATION.md), отдельная ВМ с ядром дистрибутива.
```bash
# Rocky:
sudo dnf install -y kmod conntrack-tools nftables python3 curl
# Debian/Ubuntu:
sudo apt install -y kmod conntrack nftables python3 curl
modinfo dummy
sudo modprobe dummy numdummies=1
sudo install -m 0644 labs/05-kernel-netfilter/lpic103-dummy.modules-load.conf \
  /etc/modules-load.d/lpic103-dummy.conf
sudo install -m 0644 labs/05-kernel-netfilter/lpic103-dummy.modprobe.conf \
  /etc/modprobe.d/lpic103-dummy.conf
./labs/05-kernel-netfilter/check.sh
```

Это два **полных** файлов соответствующих .d-каталогов.
При `Module dummy not found` сравните `uname -r` и `ls /lib/modules`.
На Rocky найдите поставщика `dnf provides '*/dummy.ko*'`; установите пакет,
совпадающий с работающим ядром (может понадобиться загрузка в установленное ядро).
Не скачивайте чужой .ko и не отключайте Secure Boot ради примера.

```bash
sudo systemd-run --unit=lpic103-http.service \
  /usr/bin/python3 -m http.server 8080 --bind 127.0.0.1 --directory /tmp
sudo ss -lntp 'sport = :8080'
# Выберите загрузку целой таблицы вместо трех nft add из WALKTHROUGH.
sudo nft -c -f labs/05-kernel-netfilter/lpic103_lab.nft
sudo nft -f labs/05-kernel-netfilter/lpic103_lab.nft
curl --fail http://127.0.0.1:8080/ -o /dev/null
sudo nft list table inet lpic103_lab
sudo conntrack -L -p tcp
```

Counter растет, policy accept ничего не блокирует. Если нет записи conntrack,
создайте еще один запрос и проверьте сразу: записи истекают. Для remote-теста
выберите bind 0.0.0.0 и откройте 8080 только labnet.
Очистка: `sudo nft delete table inet lpic103_lab`,
`sudo systemctl stop lpic103-http`. Остальные таблицы не трогать.
