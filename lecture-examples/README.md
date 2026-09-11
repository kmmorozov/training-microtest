# Полные конфиги для лекционных демонстраций

[Общая подготовка, пакеты и ключи](../PREPARATION.md) ·
[Разбор лекционных команд и вывода](../COMMANDS.md).

Все примеры ниже устанавливаются целыми файлами на отдельную учебную ВМ.
Nginx содержит main/events/http/server, Apache — основной конфиг и VirtualHost,
Postfix — main.cf/master.cf/aliases, Dovecot — auth/userdb/mail/TLS/listeners.
Не соединяйте два полных main config в один. Малые sysctl.d/systemd/automount
файлы являются самостоятельными единицами настройки и приведены целиком.

## Nginx: static, reverse proxy, TLS

Rocky: `sudo dnf install -y nginx`; Debian/Ubuntu:
`sudo apt install -y nginx`. В Debian замените user nginx на www-data.
Все три файла в nginx/ — **альтернативные полные /etc/nginx/nginx.conf**.

```bash
sudo install -d -m 0755 /srv/www/app
printf 'LPIC103 app OK\n' | sudo tee /srv/www/app/index.html
sudo cp -a /etc/nginx/nginx.conf /etc/nginx/nginx.conf.before-lpic103
sudo install -m 0644 lecture-examples/nginx/app-vhost.conf /etc/nginx/nginx.conf
sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl restart nginx
curl --resolve app.example.test:80:127.0.0.1 http://app.example.test/
```

Reverse-proxy: предварительно запустите backend на адресе/порту из
[reverse-proxy.conf](nginx/reverse-proxy.conf); для локального 127.0.0.1:8080:
`sudo systemd-run --unit=lpic103-backend /usr/bin/python3 -m http.server 8080
--bind 127.0.0.1 --directory /srv/www/app`.
На Rocky SELinux для проксирования может потребоваться
`sudo setsebool -P httpd_can_network_connect on`; проверьте AVC и назначение
этого boolean перед изменением. Установите reverse-proxy.conf как main,
nginx -t, reload, curl. Backend не должен слушать весь внешний интерфейс.

TLS: по PREPARATION создайте app.crt/app.key/ca.crt и установите:
```bash
sudo install -d -m 0750 /etc/nginx/tls
sudo install -m 0644 "$PKI/app.crt" /etc/nginx/tls/fullchain.pem
sudo install -m 0600 "$PKI/app.key" /etc/nginx/tls/server.key
sudo install -m 0644 lecture-examples/nginx/tls-vhost.conf /etc/nginx/nginx.conf
sudo nginx -t
sudo systemctl reload nginx
curl --resolve app.example.test:443:127.0.0.1 --cacert "$PKI/ca.crt" https://app.example.test/
```

Имя fullchain здесь содержит leaf, поскольку лабораторный root подписывает
leaf напрямую. В иной PKI добавьте intermediate chain. Открытие http/https
в реальной lab zone делается по PREPARATION; local curl firewall не проверяет.

## Apache: полный platform-specific main config

Rocky: `sudo dnf install -y httpd`, файл apache/app-rhel.conf →
/etc/httpd/conf/httpd.conf, unit httpd, validator httpd -t.
Ubuntu/Debian: `sudo apt install -y apache2`, apache/app-debian.conf →
/etc/apache2/apache2.conf, unit apache2, validator apache2ctl configtest.
Файл modules-enabled/conf.modules.d из **пакета** нужен для загрузки модулей,
дописывать конфигурацию VirtualHost не требуется.

```bash
sudo install -d -m 0755 /srv/www/app
printf 'Apache LPIC103\n' | sudo tee /srv/www/app/index.html
# Rocky:
sudo cp -a /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.before-lpic103
sudo install -m 0644 lecture-examples/apache/app-rhel.conf /etc/httpd/conf/httpd.conf
sudo httpd -t
sudo systemctl enable --now httpd
sudo systemctl restart httpd
# Debian/Ubuntu: аналогичные cp/install по путям выше, затем:
# sudo apache2ctl configtest
# sudo systemctl restart apache2
curl --resolve app.example.test:80:127.0.0.1 http://app.example.test/
```

Сначала освободите TCP80 от другой демонстрации Nginx. На Rocky для /srv/www
задайте постоянный SELinux context httpd_sys_content_t через semanage fcontext
и restorecon. Ожидаются Syntax OK и HTTP200.

## Postfix + Dovecot: локальная почта без iRedMail

Этот комплект для отдельного Ubuntu 24.04 сервера с UNIX user labmail.
Он показывает local Maildir delivery и IMAPS; полноценный SMTP AUTH submission
и webmail изучаются в [lab17](../labs/17-iredmail/README.md).

```bash
sudo apt install -y postfix dovecot-imapd openssl
sudo useradd -m labmail
sudo passwd labmail
sudo -u labmail install -d -m 0700 /home/labmail/Maildir/{cur,new,tmp}
# CA-ВМ создает mail.crt/mail.key; получатель получает их в $PKI.
sudo install -d -m 0750 /etc/postfix/lpic103-tls /etc/dovecot/private
sudo install -m 0644 "$PKI/mail.crt" /etc/postfix/lpic103-tls/mail.crt
sudo install -m 0600 "$PKI/mail.key" /etc/postfix/lpic103-tls/mail.key
sudo install -m 0644 "$PKI/mail.crt" /etc/dovecot/private/mail.crt
sudo install -m 0600 "$PKI/mail.key" /etc/dovecot/private/mail.key
sudo cp -a /etc/postfix/main.cf /etc/postfix/main.cf.before-lpic103
sudo cp -a /etc/postfix/master.cf /etc/postfix/master.cf.before-lpic103
sudo cp -a /etc/dovecot/dovecot.conf /etc/dovecot/dovecot.conf.before-lpic103
sudo cp -a /etc/aliases /etc/aliases.before-lpic103
sudo install -m 0644 lecture-examples/postfix/main.cf /etc/postfix/main.cf
sudo install -m 0644 lecture-examples/postfix/master.cf /etc/postfix/master.cf
sudo install -m 0644 lecture-examples/postfix/aliases /etc/aliases
sudo newaliases
dovecot --version
# Выберите 2.3 на Ubuntu24.04; для 2.4 полный файл dovecot-2.4.conf.
sudo install -m 0644 lecture-examples/dovecot/dovecot-2.3.conf /etc/dovecot/dovecot.conf
sudo install -m 0644 lecture-examples/dovecot/pam-dovecot /etc/pam.d/dovecot
sudo postfix check
sudo doveconf -n
sudo systemctl restart postfix dovecot
printf 'To: labmail@example.test\nSubject: LPIC103\n\nLocal mail test\n' | /usr/sbin/sendmail labmail@example.test
sudo doveadm search -u labmail mailbox INBOX subject LPIC103
openssl s_client -connect mail.example.test:993 -servername mail.example.test \
  -verify_hostname mail.example.test -verify_return_error -CAfile "$PKI/ca.crt" </dev/null
```

Dovecot 2.4 имеет обязательные version-поля и другой TLS/auth синтаксис.
Файл 2.3 нельзя использовать на 2.4. PAM использует пароль UNIX labmail;
Postfix доставляет в Maildir, а не в mbox.
Источник синтаксиса: [Dovecot quick config](https://doc.dovecot.org/2.4.5/core/config/quick.html).
Postfix aliases hash поддерживается указанным Ubuntu-пакетом; на других ОС
проверьте `postconf -m` и установленные backend packages перед переносом.

## Webmin: полный конфиг установленной версии

[Официальная установка Webmin](https://webmin.com/download/) содержит
актуальный repo setup script и ключ подписи. На отдельной ВМ:
```bash
curl --fail --location -o generated/webmin-setup-repo.sh \
  https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh
less generated/webmin-setup-repo.sh
sudo sh generated/webmin-setup-repo.sh
# Rocky:
sudo dnf install -y webmin
# Debian/Ubuntu — вместо dnf:
# sudo apt update
# sudo apt install -y webmin
sudo ./lecture-examples/webmin/prepare-full-config.sh /root/lpic103-webmin 192.168.10.0/24
sudo less /root/lpic103-webmin/miniserv.conf
sudo install -m 0600 /root/lpic103-webmin/miniserv.conf /etc/webmin/miniserv.conf
sudo systemctl restart webmin
sudo journalctl -u webmin --since '-3 min' --no-pager
sudo ss -lntp 'sport = :10000'
```

Generator сохраняет **весь** package config с верными root/mimetypes/userfile
и меняет только listener/TLS/allow; результат — полный файл, а не fragment.
Закрытые miniserv.users и TLS PEM создает пакет; их нельзя публиковать.
Для доверенного сертификата в Webmin Webmin Configuration → SSL Encryption
выберите app.crt/app.key из учебной PKI и проверяйте имя app.example.test.
Ограничьте firewall порт10000 management subnet; учетная запись/пароль
настраиваются штатным Webmin installer, данные ищите в выводе установки.

## Cockpit, NFS automount и sysctl

Cockpit: полный cockpit/cockpit.conf и [lab04](../labs/04-cockpit/README.md).
Sysctl: полный system/sysctl-service.conf → /etc/sysctl.d/60-lpic103-service.conf,
применить `sudo sysctl -p /etc/sysctl.d/60-lpic103-service.conf`.

NFS automount: используйте **полные** [mnt-data.mount](nfs/mnt-data.mount) и
[mnt-data.automount](nfs/mnt-data.automount), не заменяйте host-specific fstab.
Серверный export готовится по lab13. На клиенте:
```bash
sudo install -d /mnt/data
sudo install -m 0644 lecture-examples/nfs/mnt-data.mount lecture-examples/nfs/mnt-data.automount /etc/systemd/system/
sudo systemd-analyze verify /etc/systemd/system/mnt-data.mount /etc/systemd/system/mnt-data.automount
sudo systemctl daemon-reload
sudo systemctl enable --now mnt-data.automount
ls /mnt/data
findmnt /mnt/data
```

Откат каждой демонстрации: восстановить именно сделанные main/config backup,
валидатор → restart. Для automount: stop automount, umount /mnt/data,
отключить только созданный unit. Ожидаемые выводы команд — COMMANDS.md.
