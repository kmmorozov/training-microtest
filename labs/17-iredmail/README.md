# Лабораторная 17. Подготовка и диагностика полного iRedMail

Все 32 шага с командами/выводом: [WALKTHROUGH.md](WALKTHROUGH.md).
[Общая подготовка](../../PREPARATION.md).
Учебная цель — готовый комплекс: Postfix → проверки → доставка Dovecot →
IMAP/webmail. Полные конфиги создает инсталлятор выбранного релиза и backend;
порядок получения всего дерева приведен ниже. Ручной минимальный Postfix
из лекции не заменяет iRedMail с его SQL maps и service users.

## 1. Откуда получить готовый сервер

**Зачем: Разворачиваем iRedMail на подготовленной чистой ВМ из указанного источника, чтобы получить согласованный набор почтовых компонентов.**

Вариант преподавателя: отдельная **чистая** Ubuntu Server 24.04 ВМ, 4–8 GiB RAM,
40 GiB диска, mail.example.test = 192.168.10.25. Не используйте ВМ WordPress:
инсталлятор управляет Nginx, SQL и почтой. Исходник фиксированного релиза 1.8.8:
[официальная страница](https://www.iredmail.org/download.html),
[руководство Ubuntu/Debian](https://docs.iredmail.org/install.iredmail.on.debian.ubuntu.html).
Для Rocky 10 релиз сверяется по матрице поддержки; SOGo может быть недоступен,
поэтому в учебном комплекте выберите Roundcube.

```bash
# Только на чистой mail-ВМ, не на клиенте:
sudo hostnamectl set-hostname mail.example.test
# В /etc/hosts сохраните localhost, добавьте 192.168.10.25 mail.example.test mail.
sudoedit /etc/hosts
hostname -f
sudo apt update
sudo apt install -y gzip dialog curl ca-certificates tar
install -d -m 0700 generated/iredmail-source
cd "$REPO/generated/iredmail-source"
curl --fail --location --proto '=https' \
  -o iRedMail-1.8.8.tar.gz https://github.com/iredmail/iRedMail/archive/refs/tags/1.8.8.tar.gz
sha256sum iRedMail-1.8.8.tar.gz > SHA256SUMS
sha256sum -c SHA256SUMS
tar -xzf iRedMail-1.8.8.tar.gz
cd iRedMail-1.8.8
sudo bash iRedMail.sh
```

Архив получен по HTTPS из официального проекта; локальный manifest фиксирует
выдаваемый комплект, не является подписью upstream. Выборы мастера:
mail storage /var/vmail, backend MariaDB, домен example.test, отдельный
пароль postmaster@example.test, Nginx/Roundcube/iRedAdmin. Сохраните summary,
после успеха выполните требуемую установщиком перезагрузку и snapshot.

Файл iRedMail.tips в каталоге установки содержит **реальные** пути, URL и
сгенерированные credentials. Преподаватель читает его локально через sudo less;
этот файл не прикладывается к публичному отчету. Слушателю передается ВМ/snapshot
и две отдельные тестовые учетные записи, а не пароль root SQL.

## 2. DNS, аккаунты и полный комплект конфигов

**Зачем: Согласуем DNS и учетные записи и сохраняем полные установленные конфиги, чтобы диагностика соответствовала реальной схеме iRedMail.**

A mail → .25, PTR .25 → mail.example.test, MX example.test → mail.example.test
уже предусмотрены lab14. Проверить на mail-ВМ и клиенте:
```bash
dig @192.168.10.53 mail.example.test A +short
dig @192.168.10.53 -x 192.168.10.25 +short
dig @192.168.10.53 example.test MX +short
```

В https://mail.example.test/iredadmin/ войдите как postmaster@example.test,
создайте sender@example.test и recipient@example.test с разными паролями,
включенным IMAP/SMTP и достаточной квотой. Войдите каждым в /mail/,
чтобы проверить учетные данные и создать mailbox, если это требуется backend.
Передайте пароли ученику защищенным каналом, не в репозитории.

```bash
# Полный конфигурационный комплект реально установленного релиза:
cd "$REPO"
sudo ./labs/17-iredmail/export-full-configs.sh /root/lpic103-mail-configs
sudo tar -tzf /root/lpic103-mail-configs/full-configs.tar.gz | head
sudo postconf -n
sudo postconf -M
sudo doveconf -n
sudo nginx -T
```

Архив содержит исходные файлы целиком, включая include/SQL maps, а effective
dump показывает результат их слияния. В архиве есть пароли и ключи:
он остается в закрытом преподавательском комплекте. Пути внешних symlink targets
проверьте по FILES.txt/tar -tvf и добавьте их, если установка нестандартная.
Mailboxes и дамп БД — отдельные данные snapshot/backup, не этот config archive.

## 3. Сертификат: создание и установка без неизвестных путей

**Зачем: Создаем и устанавливаем сертификат по фактическим путям компонентов, чтобы SMTP, IMAP и webmail предъявляли проверяемую идентичность.**

Сгенерируйте mail.crt/mail.key по PREPARATION; CA.crt передается клиенту.
Пути TLS определяются **полными конфигами установленной версии**:
```bash
sudo postconf smtpd_tls_cert_file smtpd_tls_key_file
sudo doveconf -n
sudo nginx -T
```

Для стандартной установки с общей парой /etc/ssl/certs/iRedMail.crt и
/etc/ssl/private/iRedMail.key проверьте, что **все три службы** ссылаются туда,
сохраните копии и замените содержимое, сохранив пакетные owner/mode:
```bash
sudo cp -a /etc/ssl/certs/iRedMail.crt /etc/ssl/certs/iRedMail.crt.before-lpic103
sudo cp -a /etc/ssl/private/iRedMail.key /etc/ssl/private/iRedMail.key.before-lpic103
sudo tee /etc/ssl/certs/iRedMail.crt < "$PKI/mail.crt" > /dev/null
sudo tee /etc/ssl/private/iRedMail.key < "$PKI/mail.key" > /dev/null
sudo postfix check
sudo doveconf -n > /dev/null
sudo nginx -t
sudo systemctl restart postfix dovecot nginx
```

Если paths отличаются, используйте значения из postconf/doveconf/nginx -T,
а не создавайте неиспользуемые файлы по примеру. PEM leaf подписан root напрямую,
поэтому intermediate chain в этой PKI не нужен. Приватный ключ CA не передается.
Для .test Let's Encrypt не используется.

## 4. Клиентские пакеты, письмо и вывод

**Зачем: Отправляем одно отслеживаемое письмо клиентскими инструментами, чтобы связать SMTP-ответ с очередью и доставкой в ящик.**

```bash
# Ubuntu клиент:
sudo apt install -y swaks openssl curl dnsutils
# Rocky клиент: EPEL по PREPARATION, затем:
sudo dnf install -y swaks openssl curl bind-utils
# На клиенте PKI содержит только ca.crt.
openssl s_client -starttls smtp -connect mail.example.test:587 \
  -servername mail.example.test -verify_hostname mail.example.test \
  -verify_return_error -CAfile "$PKI/ca.crt" </dev/null
TEST_ID="LPIC103-$(date +%s)"
swaks --server mail.example.test --port 587 --tls \
  --tls-verify --tls-ca-file "$PKI/ca.crt" \
  --auth-user sender@example.test --auth-password --protect-prompt \
  --auth-hide-password \
  --from sender@example.test --to recipient@example.test \
  --header "Subject: $TEST_ID" --body "LPIC103 delivery test" \
  | tee /tmp/lpic103-iredmail-swaks.txt
```

Пароль вводится в prompt. `--auth-hide-password` скрывает AUTH payload в трассе
(иначе Base64 обратим и способен раскрыть пароль).
Нужны 235 auth successful, 250 queued as QUEUE_ID. Скопируйте именно ID и TEST_ID
в серверный терминал и выполните проверки postqueue/journal/doveadm из
WALKTHROUGH. Recipient = recipient@example.test, webmail-path = mail,
CA-файл = "$PKI/ca.crt". Для конфигов шаблонов этого каталога подставьте те же
значения и сохраните адаптированные копии в generated/.

## 5. Диагностика, приемка и возврат

**Зачем: Подтверждаем доставку и запрет открытого relaying и сохраняем возможность восстановления исходной конфигурации.**

TLS на 25/587/993/443 проходит по имени, mailbox найден doveadm user,
письмо с TEST_ID находится в INBOX и через /mail/. Queued не означает delivered:
нужны status=sent/LMTP и нахождение сообщения. Если journal пуст, смотрите
/var/log/mail.log либо /var/log/maillog из iRedMail.tips.
На 25 внешний RCPT должен быть отклонен; при этом отключение TLS или
авторизации submission не является исправлением.

Приемка — весь маршрут одного письма и отрицательный relay test в WALKTHROUGH.
Откат конфигов возможен из закрытого полного архива **на той же версии** после
проверки путей; надежный возврат учебного комплекта — snapshot ВМ вместе с БД.
Инсталлятор на готовой системе повторно не запускайте.
