# Лабораторная 16. Полная установка WordPress, Nginx, PHP-FPM, MariaDB

[Все 50 шагов исходного задания и выводы](WALKTHROUGH.md).
[Общая подготовка и передача сертификатов](../../PREPARATION.md).
Одна выделенная web-ВМ .10, клиент .100. Здесь полный рабочий сценарий:
пакеты → архив → БД → HTTP → TLS → права/проверки. Другие приложения в эти
конфиги не включены, поэтому используйте отдельную ВМ.

## 1. Пакеты, пользователи и версии

**Зачем: Подготавливаем совместимые компоненты веб-стека и определяем реальные имена служб, пользователей и сокетов для выбранной ОС.**

```bash
# Rocky 9/10:
sudo dnf install -y nginx mariadb-server php-fpm php-mysqlnd php-gd php-xml \
  php-mbstring php-cli php-opcache php-common policycoreutils-python-utils curl
# php-curl может быть virtual provide пакета php-common: проверяйте php -m.
# Ubuntu 24.04/Debian:
sudo apt update
sudo apt install -y nginx mariadb-server php-fpm php-mysql php-gd php-xml \
  php-mbstring php-curl php-cli php-zip
php -v
php -m
systemctl list-unit-files 'php*fpm*' 'mariadb*'
getent passwd nginx
getent passwd www-data
```

Выберите web-user: Rocky nginx, Debian/Ubuntu www-data.
Нужны mysqli/pdo_mysql, curl, mbstring, xml, gd в `php -m`.
Полный Debian FPM-конфиг рассчитан на Ubuntu PHP 8.3: если `php -r
'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;'` дает 8.4, замените **все**
8.3 в FPM и Nginx конфигурациях/путях на 8.4.
Unit MariaDB: mariadb; FPM: php-fpm на Rocky, php8.3-fpm на Ubuntu 24.04.

## 2. Откуда взять WordPress и checksum

**Зачем: Получаем фиксированную версию WordPress и проверяем целостность архива перед размещением кода на сервере.**

[Официальный архив выпусков](https://wordpress.org/download/releases/).
Для воспроизводимого занятия фиксируем 6.9.7 (проверено 11.09.2026).
Источник — HTTPS wordpress.org; самостоятельно созданный SHA256 ниже
фиксирует полученный комплект для передачи слушателям, не является подписью автора.

```bash
install -d -m 0750 generated/downloads/wordpress
cd "$REPO/generated/downloads/wordpress"
curl --fail --location --proto '=https' --tlsv1.2 \
  -o wordpress-6.9.7.tar.gz https://wordpress.org/wordpress-6.9.7.tar.gz
tar -tzf wordpress-6.9.7.tar.gz | head
sha256sum wordpress-6.9.7.tar.gz > SHA256SUMS
sha256sum -c SHA256SUMS
cd "$REPO"
sudo install -d -m 0755 /var/www
# Rocky; на Debian/Ubuntu последний аргумент www-data.
./labs/16-wordpress/prepare-wordpress.sh \
  generated/downloads/wordpress/wordpress-6.9.7.tar.gz \
  generated/downloads/wordpress/SHA256SUMS nginx
```

Offline: преподаватель выдает этот архив и SHA256SUMS по доверенному каналу.
В tar должен быть один верхний каталог wordpress/. Скрипт откажется заменять
уже существующий /var/www/lpic103-wp. Код root:root, только uploads writable.

## 3. База, пароль и полная PHP-конфигурация

**Зачем: Создаем отдельную базу и случайные секреты, устанавливаем полные PHP-настройки и ограничиваем права приложения.**

Пароль и восемь salts создаются локальным CSPRNG без внешнего сервиса.
[scripts/prepare-wordpress-config.py](../../scripts/prepare-wordpress-config.py)
генерирует согласованные **полные** SQL и wp-config.php, каталог mode0700,
файлы mode0600. В Git они не попадут.

```bash
./scripts/prepare-wordpress-config.py generated/lab16-secrets
sudo systemctl enable --now mariadb
sudo mariadb < generated/lab16-secrets/create-database.sql
# Rocky:
sudo install -o root -g nginx -m 0640 generated/lab16-secrets/wp-config.php \
  /var/www/lpic103-wp/wp-config.php
# Debian/Ubuntu: та же команда с -g www-data.
```

SQL предназначен для новой БД; не повторяйте CREATE USER вслепую.
`SHOW GRANTS` должен разрешать только lpic103_wp.*, не *.*.
Пароль одинаков в двух generated-файлах, не нужен в командной строке.
Это замена шагам с `<случайный-пароль>` и «salts преподавателя».

```bash
# Rocky, полный FPM main:
sudo cp -a /etc/php-fpm.conf /etc/php-fpm.conf.before-lpic103
sudo install -m 0644 labs/16-wordpress/php-fpm-rhel.conf /etc/php-fpm.conf
sudo install -d -o nginx -g nginx /var/lib/php/session
sudo php-fpm -t
sudo systemctl enable --now php-fpm
sudo systemctl restart php-fpm
# Debian/Ubuntu — альтернативная ветка (для другой версии исправить 8.3):
sudo cp -a /etc/php/8.3/fpm/php-fpm.conf /etc/php/8.3/fpm/php-fpm.conf.before-lpic103
sudo install -m 0644 labs/16-wordpress/php-fpm-debian.conf /etc/php/8.3/fpm/php-fpm.conf
sudo php-fpm8.3 -t
sudo systemctl enable --now php8.3-fpm
sudo systemctl restart php8.3-fpm
```

Эти main configs уже содержат [global] и [www], не включают старый pool.d.
Нет listen.acl_users, перекрывающего owner/mode сокета. Проверка:
`sudo ss -lxnp | grep php`. Ожидается путь socket из Nginx.
MariaDB использует полный пакетный main; необязательная локальная политика
[mariadb-server.cnf](mariadb-server.cnf) — целый .cnf-файл включаемого каталога
(пути указаны в комментариях), не вместо основного /etc/my.cnf.

## 4. Полный Nginx: сначала HTTP

**Зачем: Проверяем связку Nginx → PHP-FPM → WordPress по HTTP, чтобы отделить ошибки приложения от последующей настройки TLS.**

```bash
sudo cp -a /etc/nginx/nginx.conf /etc/nginx/nginx.conf.before-lpic103
# Rocky; Debian/Ubuntu выбрать nginx-debian-http.conf.
sudo install -m 0644 labs/16-wordpress/nginx-rhel-http.conf /etc/nginx/nginx.conf
sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl restart nginx
curl --fail --location --resolve wp.example.test:80:127.0.0.1 \
  http://wp.example.test/ -o /tmp/lpic103-wp.html
grep -Ei 'WordPress|language|install' /tmp/lpic103-wp.html
```

Это полноценный main файл с events/http/server и всеми FastCGI params.
Если 502 — сверяйте сокет, owner/group, состояние FPM и SELinux AVC.
Если БД недоступна — mysqli, DB_HOST=localhost, сокет MariaDB и права БД.

## 5. TLS и завершение установки

**Зачем: Включаем HTTPS с проверяемым сертификатом и завершаем установку, чтобы логины и прикладные данные передавались по защищенному соединению.**

По PREPARATION CA-ВМ создает --tls-only комплект, сервер получает
wp.crt/wp.key/ca.crt в "$PKI", клиент — только ca.crt.
DNS/hosts клиента: `192.168.10.10 wp.example.test`.
```bash
sudo install -d -m 0750 /etc/nginx/lpic103-tls
sudo install -m 0644 "$PKI/wp.crt" /etc/nginx/lpic103-tls/wp.crt
sudo install -m 0600 "$PKI/wp.key" /etc/nginx/lpic103-tls/wp.key
# Rocky, Debian выбрать nginx-debian-tls.conf:
sudo install -m 0644 labs/16-wordpress/nginx-rhel-tls.conf /etc/nginx/nginx.conf
# В сгенерированном полном wp-config измените FORCE_SSL_ADMIN false → true:
nano generated/lab16-secrets/wp-config.php
sudo install -o root -g nginx -m 0640 generated/lab16-secrets/wp-config.php \
  /var/www/lpic103-wp/wp-config.php
# Debian/Ubuntu вновь -g www-data.
sudo nginx -t
sudo systemctl reload nginx
# Rocky, с реальной interface zone:
sudo firewall-cmd --permanent --zone=internal --add-service=http
sudo firewall-cmd --permanent --zone=internal --add-service=https
sudo firewall-cmd --reload
curl -I --resolve wp.example.test:80:127.0.0.1 http://wp.example.test/
curl --fail --location --cacert "$PKI/ca.crt" \
  --resolve wp.example.test:443:127.0.0.1 https://wp.example.test/
openssl s_client -connect 127.0.0.1:443 -servername wp.example.test \
  -verify_hostname wp.example.test -verify_return_error -CAfile "$PKI/ca.crt" </dev/null
```

Ожидаются 301 с HTTP, HTML установщика с HTTPS, Verify return code0.
Откройте https://wp.example.test в браузере клиента с доверенным учебным CA,
выберите язык, название сайта, **нового** администратора и уникальный пароль,
email; завершите установку и выполните вход. Не используйте DB-пароль
как пароль WordPress admin. Учетная запись хранится в БД.

## 6. Приемка и откат

**Зачем: Подтверждаем работоспособность сайта и ограничения записи веб-процесса, а также определяем безопасный способ восстановления.**

Создайте запись и загрузите изображение через Media. Проверьте:
```bash
# Rocky; Debian/Ubuntu заменить nginx на www-data.
sudo -u nginx test ! -w /var/www/lpic103-wp/index.php
sudo -u nginx test -r /var/www/lpic103-wp/wp-config.php
sudo -u nginx test ! -w /var/www/lpic103-wp/wp-config.php
sudo -u nginx test -w /var/www/lpic103-wp/wp-content/uploads
curl --cacert "$PKI/ca.crt" -o /dev/null -w '%{http_code}\n' https://wp.example.test/wp-config.php
```

Последний запрос должен быть 403. PHP в uploads также запрещен.
Тема/плагины не обновляются веб-процессом в root-owned модели: это ожидаемо,
обновление выполняет администратор с backup и проверенным архивом.
Откат: восстановить nginx.conf/FPM main из копий, синтаксические проверки,
restart. БД и uploaded media сохраните отдельным dump/archive до удаления;
изменение конфигурации само по себе не удаляет данные.
