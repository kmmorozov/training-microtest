# Лабораторная работа 16. Nginx, PHP-FPM, MariaDB и WordPress

[Подготовка, пакеты, полные конфиги и уточнения](README.md) · [Общие материалы и ключи](../../PREPARATION.md)

Ниже все шаги руководства лабораторных v4 от 10.08.2026 с сохраненными
командами и ожидаемыми результатами. Сначала выполните подготовку в README:
она определяет адреса, значения переменных и различия ОС. Команды выполняются
по одной, на указанной машине; альтернативные ветки ОС не выполняются вместе.
В командах по умолчанию X=10/Y=20/Z=30, lab NIC=enp0s8, зоны internal/external/public.
Их необходимо сопоставить с реальными NIC/zone по README. Имена unit и web-user
по умолчанию Rocky; для Debian/Ubuntu используйте соответствия из README.
Выводы — образцы, а не протокол запуска на вашей ВМ.

Цель лабораторной работы: развернуть Nginx, PHP-FPM и MariaDB, подготовить WordPress из проверенного архива к безопасному завершению web-установки и включить TLS.

Стенд: одна изолированная ВМ; DNS wp.example.test указывает на нее; архив WordPress, checksum и учебный сертификат предоставляет преподаватель.

Сценарий: для внутреннего сайта требуется единый web-стек без второго HTTP-сервера: Nginx принимает HTTP/HTTPS, передает PHP-запросы в PHP-FPM, а WordPress использует отдельную базу MariaDB.

Планируемый результат: Nginx обслуживает страницу установки WordPress по HTTPS, PHP выполняется через FPM, пользователь БД ограничен одной базой, а web-user записывает только в uploads.

## Ограничения и безопасность

Важно: не загружайте плагины и темы из Интернета на учебном стенде.

Важно: не выдавайте web-user владение всем деревом WordPress и не используйте DB root в wp-config.php.

Важно: секреты не передаются в аргументах команд и не копируются за пределы стенда; закрытый ключ хранится с mode 0600.

## Ход выполнения

## Шаг 1. Установить требуемые пакеты

До приложения отдельно проверьте каждую службу, HTTP listener, FPM socket и модуль доступа PHP к MariaDB. Установите пакеты только для выбранного семейства ОС. Ключ -y подтверждает пакетную транзакцию без дополнительного запроса.

```bash
# RHEL-like
sudo dnf install -y nginx mariadb-server php-fpm php-mysqlnd php-gd php-xml php-mbstring php-curl policycoreutils-python-utils
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
sudo apt install -y nginx mariadb-server php-fpm php-mysql php-gd php-xml php-mbstring php-curl
```

## Шаг 4. Включить автозапуск службы

Команда обращается к systemd. enable управляет автозапуском, --now также меняет текущее состояние, status/show читают фактические свойства, reload применяет проверенную конфигурацию без полного restart.

```bash
sudo systemctl enable --now nginx mariadb php-fpm
```

Ожидаемый вывод и результат:

```text
Created symlink ... (при первом включении); exit status = 0
```

## Шаг 5. Проверить состояние службы

```bash
systemctl status nginx mariadb php-fpm --no-pager
```

Ожидаемый вывод и результат:

```text
Active: active (running) ...
Loaded: loaded (...)
```

## Шаг 6. Проверить конфигурацию Nginx

Проверьте синтаксис или effective-конфигурацию службы до ее reload; при ошибке текущая служба не изменяется.

```bash
sudo nginx -t
```

Ожидаемый вывод и результат:

```text
nginx: configuration file ... syntax is ok
nginx: configuration file ... test is successful
```

## Шаг 7. Проверить сетевой listener

Проверьте реальный socket, адрес, порт и процесс-владелец; состояние службы само по себе не доказывает наличие listener.

```bash
sudo ss -lntp 'sport = :80'
```

Ожидаемый вывод и результат:

```text
LISTEN ... <адрес>:<TCP-порт> ... users:(("<процесс>",pid=<PID>))
```

## Шаг 8. Проверить сетевой listener

```bash
sudo ss -lxnp | grep -E 'php|fpm'
```

Ожидаемый вывод и результат:

```text
LISTEN ... <адрес>:<TCP-порт> ... users:(("<процесс>",pid=<PID>))
```

## Шаг 9. Проверить версию PHP

Проверьте один компонент прикладного стека: версию, загруженный модуль или подключение к выделенной базе.

```bash
php -v
```

Ожидаемый вывод и результат:

```text
PHP <версия> (cli) ...
```

## Шаг 10. Проверить модуль PHP

```bash
php -m | grep -Ei 'mysqli|pdo_mysql'
```

Ожидаемый вывод и результат:

```text
mysqli или pdo_mysql
```

Nginx слушает TCP/80, FPM socket существует, PHP видит драйвер MariaDB.

## Шаг 11. Открыть административный клиент MariaDB

Создайте отдельную базу UTF-8 и учетную запись, действующую только с localhost и только для этой базы. Откройте локальный административный клиент MariaDB; последующие SQL-шаги выполняются в его приглашении.

```bash
sudo mariadb
```

Ожидаемый вывод и результат:

```text
Welcome to the MariaDB monitor.
MariaDB [(none)]>
```

## Шаг 12. Создать базу данных

Выполните SQL-оператор внутри уже открытого клиента MariaDB. Точка с запятой завершает один самостоятельный запрос.

```sql
# Выполните в открытом клиенте MariaDB
CREATE DATABASE lpic103_wp CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

Ожидаемый вывод и результат:

```text
Query OK, 1 row affected
```

## Шаг 13. Создать пользователя базы данных

```sql
# Выполните в открытом клиенте MariaDB
CREATE USER 'lpic103_wp'@'localhost' IDENTIFIED BY '<случайный-пароль>';
```

Ожидаемый вывод и результат:

```text
Query OK, 0 rows affected
```

## Шаг 14. Назначить права пользователю базы данных

```sql
# Выполните в открытом клиенте MariaDB
GRANT ALL PRIVILEGES ON lpic103_wp.* TO 'lpic103_wp'@'localhost';
```

Ожидаемый вывод и результат:

```text
Query OK, 0 rows affected
```

## Шаг 15. Проверить выданные привилегии

```sql
# Выполните в открытом клиенте MariaDB
SHOW GRANTS FOR 'lpic103_wp'@'localhost';
```

Ожидаемый вывод и результат:

```text
GRANT ... ON `lpic103_wp`.* TO `lpic103_wp`@`localhost`
```

## Шаг 16. Завершить интерактивный клиент

```bash
# Завершите интерактивный клиент MariaDB
exit
```

## Шаг 17. Проверить подключение к MariaDB

```bash
mariadb -u lpic103_wp -p -e 'SELECT DATABASE();' lpic103_wp
```

Ожидаемый вывод и результат:

```text
DATABASE()
<имя базы> или результат указанного SQL-запроса
```

Пользователь подключается к lpic103_wp; в истории shell нет пароля.

## Шаг 18. Проверить контрольную сумму

Сначала проверьте checksum, затем распакуйте код с владельцем root. Запись web-user разрешается только каталогу uploads. Выполните одну операцию с данными и метаданными; checksum/diff подтверждают результат, а dry-run не изменяет приемник.

```bash
sha256sum -c "$REPO/generated/downloads/wordpress/SHA256SUMS"
```

Ожидаемый вывод и результат:

```text
<файл>: OK
```

## Шаг 19. Обработать архив

Выполните одну операцию с данными и метаданными; checksum/diff подтверждают результат, а dry-run не изменяет приемник.

```bash
sudo tar -xf "$REPO/generated/downloads/wordpress/wordpress-6.9.7.tar.gz" -C /var/www
```

## Шаг 20. Переместить или переименовать объект

```bash
sudo mv /var/www/wordpress /var/www/lpic103-wp
```

## Шаг 21. Настроить права и атрибуты

```bash
sudo chown -R root:root /var/www/lpic103-wp
```

## Шаг 22. Настроить права и атрибуты

Измените или прочитайте один слой прав. Проверяйте владельца, mode, ACL mask и права родительских каталогов отдельно.

```bash
sudo find /var/www/lpic103-wp -type d -exec chmod 0755 {} +
```

## Шаг 23. Настроить права и атрибуты

```bash
sudo find /var/www/lpic103-wp -type f -exec chmod 0644 {} +
```

## Шаг 24. Создать каталог с заданными правами

Команда install создает каталог или копирует файл сразу с заданными владельцем и mode: -d выбирает каталог, -m задает права, -o/-g — владельца и группу.

```bash
sudo install -d -o nginx -g nginx -m 0750 /var/www/lpic103-wp/wp-content/uploads
```

## Шаг 25. Зарегистрировать SELinux-контекст каталога uploads

На RHEL-like с enforcing SELinux каталог для загрузок должен иметь записываемый web-контекст. Остальное дерево остается только для чтения.

```bash
if command -v getenforce >/dev/null && [ "$(getenforce)" = Enforcing ]; then
  sudo semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/lpic103-wp/wp-content/uploads(/.*)?'
else
  echo 'SELinux не находится в enforcing mode; шаг не требуется'
fi
```

## Шаг 26. Применить SELinux-контексты WordPress

restorecon назначает стандартный read-only web-контекст коду и httpd_sys_rw_content_t только каталогу uploads согласно fcontext.

```bash
if command -v getenforce >/dev/null && [ "$(getenforce)" = Enforcing ]; then
  sudo restorecon -Rv /var/www/lpic103-wp
else
  echo 'SELinux не находится в enforcing mode; шаг не требуется'
fi
```

## Шаг 27. Выполнить защитную проверку

Проверьте предусловие без изменения системы; успешный test обычно ничего не выводит и возвращает код 0.

```bash
sudo -u nginx test ! -w /var/www/lpic103-wp/index.php
```

Ожидаемый вывод и результат:

```text
Команда не сообщает синтаксических ошибок и завершается с exit status = 0.
```

## Шаг 28. Выполнить защитную проверку

```bash
sudo -u nginx test -w /var/www/lpic103-wp/wp-content/uploads
```

Ожидаемый вывод и результат:

```text
Команда не сообщает синтаксических ошибок и завершается с exit status = 0.
```

Web-user не изменяет index.php, но создает файлы в uploads.

## Шаг 29. Скопировать файл или каталог

Создайте wp-config.php из sample, внесите отдельные DB credentials и подготовленные salts, затем ограничьте чтение web-группой.

```bash
sudo cp /var/www/lpic103-wp/wp-config-sample.php /var/www/lpic103-wp/wp-config.php
```

## Шаг 30. Изменить конфигурацию /var/www/lpic103-wp/wp-config.php

Установите полный файл для этого этапа по [инструкции подготовки](README.md).
Она заменяет редактирование неполного блока из исходного пособия.

```bash
# Установка полного wp-config.php, php-fpm.conf и nginx.conf разобрана в README.
# Используйте соответствующий полный файл и этап HTTP/TLS, затем:
sudo nginx -t
```

## Шаг 31. Настроить права и атрибуты

```bash
sudo chown root:nginx /var/www/lpic103-wp/wp-config.php
```

## Шаг 32. Настроить права и атрибуты

```bash
sudo chmod 0640 /var/www/lpic103-wp/wp-config.php
```

## Шаг 33. Выполнить защитную проверку

```bash
sudo -u nginx test -r /var/www/lpic103-wp/wp-config.php
```

Ожидаемый вывод и результат:

```text
Команда не сообщает синтаксических ошибок и завершается с exit status = 0.
```

## Шаг 34. Выполнить защитную проверку

```bash
sudo -u nginx test ! -w /var/www/lpic103-wp/wp-config.php
```

Ожидаемый вывод и результат:

```text
Команда не сообщает синтаксических ошибок и завершается с exit status = 0.
```

PHP-пользователь читает wp-config.php, но не может его изменить.

## Шаг 35. Изменить конфигурацию <nginx-wordpress-server-file>

Nginx сначала ищет статический файл, а PHP URI передает в локальный FPM socket вместе с полным SCRIPT_FILENAME.

Установите полный файл для этого этапа по [инструкции подготовки](README.md).
Она заменяет редактирование неполного блока из исходного пособия.

```bash
# Установка полного wp-config.php, php-fpm.conf и nginx.conf разобрана в README.
# Используйте соответствующий полный файл и этап HTTP/TLS, затем:
sudo nginx -t
```

## Шаг 36. Проверить конфигурацию Nginx

```bash
sudo nginx -t
```

Ожидаемый вывод и результат:

```text
nginx: configuration file ... syntax is ok
nginx: configuration file ... test is successful
```

## Шаг 37. Перечитать конфигурацию службы

```bash
sudo systemctl reload nginx
```

## Шаг 38. Выполнить прикладной HTTP-запрос

Отправьте прикладной HTTP/HTTPS-запрос. Параметры --resolve/--cacert проверяют нужный адрес, имя и доверие без отключения TLS-проверок.

```bash
curl --fail --location --resolve wp.example.test:80:127.0.0.1 http://wp.example.test/ -o /tmp/lpic103-wp.html
```

Ожидаемый вывод и результат:

```text
curl завершается с exit status = 0; тело ответа перенаправлено в указанный файл или /dev/null.
```

## Шаг 39. Отфильтровать диагностический вывод

```bash
grep -Ei 'WordPress|language' /tmp/lpic103-wp.html
```

Страница установки WordPress формируется PHP-FPM, а не отдается как исходный PHP-текст.

## Шаг 40. Создать каталог с заданными правами

Добавьте отдельный redirect с HTTP на HTTPS и TLS server block с тем же обработчиком PHP, затем проверьте имя сертификата без -k. Команда install создает каталог или копирует файл сразу с заданными владельцем и mode: -d выбирает каталог, -m задает права, -o/-g — владельца и группу.

```bash
sudo install -d -m 0750 /etc/nginx/lpic103-tls
```

## Шаг 41. Скопировать объект с заданными правами

```bash
sudo install -m 0644 "$PKI/wp.crt" /etc/nginx/lpic103-tls/wp.crt
```

## Шаг 42. Скопировать объект с заданными правами

```bash
sudo install -m 0600 "$PKI/wp.key" /etc/nginx/lpic103-tls/wp.key
```

## Шаг 43. Изменить конфигурацию <nginx-wordpress-server-file>

Установите полный файл для этого этапа по [инструкции подготовки](README.md).
Она заменяет редактирование неполного блока из исходного пособия.

```bash
# Установка полного wp-config.php, php-fpm.conf и nginx.conf разобрана в README.
# Используйте соответствующий полный файл и этап HTTP/TLS, затем:
sudo nginx -t
```

## Шаг 44. Проверить конфигурацию Nginx

```bash
sudo nginx -t
```

Ожидаемый вывод и результат:

```text
nginx: configuration file ... syntax is ok
nginx: configuration file ... test is successful
```

## Шаг 45. Перечитать конфигурацию службы

```bash
sudo systemctl reload nginx
```

## Шаг 46. Выполнить прикладной HTTP-запрос

```bash
curl -I --resolve wp.example.test:80:127.0.0.1 http://wp.example.test/
```

Ожидаемый вывод и результат:

```text
HTTP/1.1 200 OK или ожидаемый 301 redirect
```

## Шаг 47. Проверить TLS-соединение

Установите TLS-сеанс с SNI и проверкой имени; для SMTP STARTTLS явно указывается прикладной протокол.

```bash
echo | openssl s_client -connect 127.0.0.1:443 -servername wp.example.test -CAfile "$PKI/ca.crt" -verify_hostname wp.example.test 2>/dev/null | grep 'Verify return code'
```

Ожидаемый вывод и результат:

```text
Verify return code: 0 (ok)
```

## Шаг 48. Выполнить прикладной HTTP-запрос

```bash
curl --fail --location --resolve wp.example.test:443:127.0.0.1 --cacert "$PKI/ca.crt" https://wp.example.test/ -o /tmp/lpic103-wp-tls.html
```

Ожидаемый вывод и результат:

```text
curl завершается с exit status = 0; тело ответа перенаправлено в указанный файл или /dev/null.
```

## Шаг 49. Выполнить защитную проверку

```bash
sudo -u nginx test ! -w /var/www/lpic103-wp/index.php
```

Ожидаемый вывод и результат:

```text
Команда не сообщает синтаксических ошибок и завершается с exit status = 0.
```

## Шаг 50. Выполнить защитную проверку

```bash
sudo -u nginx test -w /var/www/lpic103-wp/wp-content/uploads
```

Ожидаемый вывод и результат:

```text
Команда не сообщает синтаксических ошибок и завершается с exit status = 0.
```

HTTPS показывает WordPress, имя сертификата совпадает, права записи не расширились.
