# Лабораторная 04. Cockpit и административная сеть

Все 25 шагов, обе firewall-ветки и ожидаемые allow/deny:
[WALKTHROUGH.md](WALKTHROUGH.md). [Подготовка](../../PREPARATION.md).
Сервер .10, management client 192.168.10.100, посторонний клиент в Y.
```bash
# Rocky:
sudo dnf install -y cockpit firewalld
# Ubuntu/Debian:
sudo apt install -y cockpit
sudo systemctl enable --now cockpit.socket
systemctl status cockpit.socket --no-pager
sudo ss -lntp 'sport = :9090'
curl -kI https://127.0.0.1:9090
```

`cockpit.socket` активирует веб-процесс по запросу. Вход: учетная запись ОС
с заданным через `sudo passwd labadmin` паролем; sudo-права дает wheel (Rocky)
или sudo (Debian). Пароль не хранится в конфиге.

Полный [cockpit.conf](../../lecture-examples/cockpit/cockpit.conf)
устанавливается как /etc/cockpit/cockpit.conf. Варианты настройки firewall
в этом каталоге — законченные комментированные скрипты: скопируйте выбранный
в generated/lab04, замените X/Y/zone/ssh-port и выполните после `bash -n`.
Firewalld и UFW — альтернативы. Полный итоговый конфиг firewalld состоит из
созданной zone и ее привязки, он выводится `firewall-cmd --list-all-zones`.

Cockpit автоматически создает self-signed сертификат при отсутствии своего.
Для доверенного TLS возьмите app.crt/app.key по PREPARATION, используйте DNS
app.example.test и установите:
```bash
sudo install -d -m 0755 /etc/cockpit/ws-certs.d
sudo install -m 0644 "$PKI/app.crt" /etc/cockpit/ws-certs.d/50-lpic103.cert
sudo install -m 0600 "$PKI/app.key" /etc/cockpit/ws-certs.d/50-lpic103.key
sudo systemctl try-restart cockpit.service
curl --cacert "$PKI/ca.crt" -I https://app.example.test:9090
```

`-k` допустим только в первой проверке self-signed, не в приемке доверия CA.
Если приходит 403 Origin — проверьте имя/порт в cockpit.conf. Если timeout —
проверьте zone/source и маршрут. Откат: восстановить cockpit.conf и убрать
только правила lab04, сохранив SSH-доступ; сверить два клиента повторно.
