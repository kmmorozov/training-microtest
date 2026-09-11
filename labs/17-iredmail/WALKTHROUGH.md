# Лабораторная работа 17. Диагностика готового почтового комплекса iRedMail

[Подготовка, пакеты, полные конфиги и уточнения](README.md) · [Общие материалы и ключи](../../PREPARATION.md)

Ниже все шаги руководства лабораторных v4 от 10.08.2026 с сохраненными
командами и ожидаемыми результатами. Сначала выполните подготовку в README:
она определяет адреса, значения переменных и различия ОС. Команды выполняются
по одной, на указанной машине; альтернативные ветки ОС не выполняются вместе.
В командах по умолчанию X=10/Y=20/Z=30, lab NIC=enp0s8, зоны internal/external/public.
Их необходимо сопоставить с реальными NIC/zone по README. Имена unit и web-user
по умолчанию Rocky; для Debian/Ubuntu используйте соответствия из README.
Выводы — образцы, а не протокол запуска на вашей ВМ.

Цель лабораторной работы: разобрать состав готового iRedMail и проследить одно письмо через DNS, TLS, SMTP submission, очередь, доставку, IMAP и webmail.

Стенд: Snapshot-ВМ с установленным преподавателем iRedMail, доменом example.test, двумя mailbox accounts, тестовым CA и клиентской ВМ. X заменяется фактическим номером подсети почтового сервера.

Сценарий: пользователь сообщает, что письмо между двумя учебными ящиками не видно в webmail. Администратор проверяет зависимости и последовательно локализует прохождение сообщения.

Планируемый результат: DNS и сертификаты согласованы, listeners принадлежат ожидаемым процессам, письмо имеет queue ID и найдено в INBOX через Dovecot, webmail отвечает по HTTPS, а попытка внешнего relay отклонена.

## Ограничения и безопасность

Важно: не запускайте установщик iRedMail повторно и не изменяйте его внутреннюю БД без отдельной инструкции.

Важно: не отправляйте сообщения во внешние домены и не передавайте пароли в аргументах команд.

Важно: пути журналов, имена unit и webmail-path определяются на конкретной версии стенда.

## Ход выполнения

## Шаг 1. Проверить полное имя сервера

До проверки приложений согласуйте FQDN, время и записи A, PTR и MX: ошибки этих зависимостей проявляются сразу в нескольких почтовых компонентах. Получите полное имя сервера, которое используется DNS, TLS и почтовыми протоколами.

```bash
hostname -f
```

Ожидаемый вывод и результат:

```text
<полное доменное имя сервера>
```

## Шаг 2. Проверить синхронизацию времени

Проверьте часовой пояс и синхронизацию системных часов; это необходимо для сертификатов, TOTP и сопоставления журналов.

```bash
timedatectl
```

Ожидаемый вывод и результат:

```text
System clock synchronized: yes
Time zone: <зона>
```

## Шаг 3. Проверить DNS-запись

Запросите одну конкретную DNS-запись; сервер, имя и тип ответа должны соответствовать текущему сетевому сценарию.

```bash
dig +short mail.example.test A
```

Ожидаемый вывод и результат:

```text
<ожидаемое значение записи>
```

## Шаг 4. Проверить DNS-запись

```bash
# 192.168.10.25 — адрес почтового сервера
dig +short -x 192.168.10.25
```

Ожидаемый вывод и результат:

```text
<ожидаемое значение записи>
```

## Шаг 5. Проверить DNS-запись

```bash
dig +short example.test MX
```

Ожидаемый вывод и результат:

```text
<ожидаемое значение записи>
```

## Шаг 6. Проверить разрешение имени через NSS

Разрешите имя через системный NSS, то есть тем же путем, которым пользуются прикладные программы, а не только утилита dig.

```bash
getent ahostsv4 mail.example.test
```

Ожидаемый вывод и результат:

```text
<адрес> STREAM <имя>
...; exit status = 0
```

FQDN, A, PTR и MX описывают один учебный сервер; часы синхронизированы.

## Шаг 7. Проверить сетевой listener

Свяжите порты SMTP, submission, IMAPS и HTTPS с процессами, затем убедитесь, что systemd не сообщает о failed units. Проверьте реальный socket, адрес, порт и процесс-владелец; состояние службы само по себе не доказывает наличие listener.

```bash
sudo ss -lntp | grep -E ':(25|587|993|443) '
```

Ожидаемый вывод и результат:

```text
LISTEN ... <адрес>:<TCP-порт> ... users:(("<процесс>",pid=<PID>))
```

## Шаг 8. Проверить аварийные unit

Команда обращается к systemd. enable управляет автозапуском, --now также меняет текущее состояние, status/show читают фактические свойства, reload применяет проверенную конфигурацию без полного restart.

```bash
sudo systemctl --failed
```

Ожидаемый вывод и результат:

```text
0 loaded units listed.
```

## Шаг 9. Проверить эффективную конфигурацию

Выполните одну проверку почтового тракта: SMTP-ответ, queue ID, effective config или содержимое mailbox.

```bash
sudo postconf -n | sed -n '1,100p'
```

Ожидаемый вывод и результат:

```text
<effective parameter> = <value>
```

## Шаг 10. Проверить эффективную конфигурацию

```bash
sudo doveconf -n | sed -n '1,120p'
```

Ожидаемый вывод и результат:

```text
<effective parameter> = <value>
```

## Шаг 11. Проверить состояние службы

```bash
sudo systemctl status postfix dovecot --no-pager
```

Ожидаемый вывод и результат:

```text
Active: active (running) ...
Loaded: loaded (...)
```

Четыре endpoint присутствуют, Postfix и Dovecot active, failed units отсутствуют.

## Шаг 12. Проверить TLS-соединение

Один сертификат может обслуживать несколько протоколов, но каждый endpoint проверяется своим способом запуска TLS и с SNI/именем сервера. Установите TLS-сеанс с SNI и проверкой имени; для SMTP STARTTLS явно указывается прикладной протокол.

```bash
echo | openssl s_client -starttls smtp -connect mail.example.test:25 -servername mail.example.test -CAfile "$PKI/ca.crt" -verify_hostname mail.example.test 2>/dev/null | grep 'Verify return code'
```

## Шаг 13. Проверить TLS-соединение

Установите TLS-сеанс с SNI и проверкой имени; для SMTP STARTTLS явно указывается прикладной протокол.

```bash
echo | openssl s_client -starttls smtp -connect mail.example.test:587 -servername mail.example.test -CAfile "$PKI/ca.crt" -verify_hostname mail.example.test 2>/dev/null | grep 'Verify return code'
```

## Шаг 14. Проверить TLS-соединение

```bash
echo | openssl s_client -connect mail.example.test:993 -servername mail.example.test -CAfile "$PKI/ca.crt" -verify_hostname mail.example.test 2>/dev/null | grep 'Verify return code'
```

## Шаг 15. Проверить TLS-соединение

```bash
echo | openssl s_client -connect mail.example.test:443 -servername mail.example.test -CAfile "$PKI/ca.crt" -verify_hostname mail.example.test 2>/dev/null | grep 'Verify return code'
```

Все четыре проверки доверяют цепочке и подтверждают имя mail.example.test.

## Шаг 16. Проверить эффективную конфигурацию

До отправки подтвердите, что Postfix считает домен локальным/виртуальным, а Dovecot находит получателя и его INBOX. Выполните одну проверку почтового тракта: SMTP-ответ, queue ID, effective config или содержимое mailbox.

```bash
sudo postconf -h virtual_mailbox_domains
```

Ожидаемый вывод и результат:

```text
<значение virtual_mailbox_domains>
```

## Шаг 17. Проверить эффективную конфигурацию

```bash
sudo postconf -h virtual_mailbox_maps
```

Ожидаемый вывод и результат:

```text
<значение virtual_mailbox_maps>
```

## Шаг 18. Проверить данные Dovecot

```bash
sudo doveadm user recipient@example.test
```

Ожидаемый вывод и результат:

```text
field uid=<UID>
field home=<mailbox-path>
```

## Шаг 19. Проверить данные Dovecot

```bash
sudo doveadm mailbox list -u recipient@example.test
```

Ожидаемый вывод и результат:

```text
INBOX
Drafts
Sent
Trash
```

Домен обрабатывается локально, recipient разрешается в mailbox и имеет INBOX.

## Шаг 20. Задать переменную текущего сеанса

Отправьте одно письмо через submission с уникальным Subject и сохраните SMTP-транскрипт, чтобы получить queue ID.

```bash
TEST_ID="LPIC103-$(date +%s)"
```

## Шаг 21. Выполнить SMTP-транзакцию

Отправьте одно аутентифицированное тестовое письмо и сохраните SMTP-диалог: по нему далее извлекается queue ID и прослеживается доставка.

```bash
swaks --server mail.example.test --port 587 --tls \
  --auth-user sender@example.test --auth-password --protect-prompt --auth-hide-password \
  --from sender@example.test --to recipient@example.test \
  --header "Subject: $TEST_ID" --body "iRedMail delivery path test" \
  | tee /tmp/lpic103-iredmail-swaks.txt
```

Ожидаемый вывод и результат:

```text
235 Authentication successful
250 2.0.0 Ok: queued as <QUEUE_ID>
```

## Шаг 22. Отфильтровать диагностический вывод

```bash
grep -E 'Authentication successful|queued as|250 2\.0\.0' /tmp/lpic103-iredmail-swaks.txt
```

## Шаг 23. Задать переменную текущего сеанса

```bash
QUEUE_ID=$(sed -nE 's/.*queued as ([[:alnum:]]+).*/\1/p' /tmp/lpic103-iredmail-swaks.txt | tail -1)
```

## Шаг 24. Выполнить защитную проверку

Проверьте предусловие без изменения системы; успешный test обычно ничего не выводит и возвращает код 0.

```bash
test -n "$QUEUE_ID" || { echo 'Queue ID не найден'; exit 1; }
```

Ожидаемый вывод и результат:

```text
Команда не сообщает синтаксических ошибок и завершается с exit status = 0.
```

## Шаг 25. Сформировать или вывести контрольные данные

```bash
printf 'TEST_ID=%s QUEUE_ID=%s\n' "$TEST_ID" "$QUEUE_ID"
```

## Шаг 26. Проверить почтовую очередь

```bash
postqueue -p
```

Ожидаемый вывод и результат:

```text
Mail queue is empty или <QUEUE_ID> с причиной ожидания
```

Получены уникальный TEST_ID и непустой QUEUE_ID; SMTP AUTH и постановка в очередь успешны.

## Шаг 27. Отфильтровать диагностический вывод

Используйте queue ID как корреляционный ключ: в журнале должны последовательно появиться прием сообщения и локальная доставка, после чего Dovecot найдет Subject в INBOX.

```bash
sudo journalctl --since '-10 min' --no-pager | grep "$QUEUE_ID"
```

## Шаг 28. Проверить данные Dovecot

```bash
sudo doveadm search -u recipient@example.test mailbox INBOX subject "$TEST_ID"
```

Ожидаемый вывод и результат:

```text
<mailbox-guid> <uid>
```

## Шаг 29. Проверить почтовую очередь

```bash
postqueue -p
```

Ожидаемый вывод и результат:

```text
Mail queue is empty или <QUEUE_ID> с причиной ожидания
```

Журнал содержит status=sent, doveadm возвращает UID сообщения, постоянной очереди нет.

## Шаг 30. Выполнить прикладной HTTP-запрос

Проверьте по HTTPS доступность страницы входа webmail. Факт доставки конкретного сообщения уже подтвержден предыдущим doveadm search; curl не выполняет пользовательский вход в mailbox.

```bash
curl --fail --cacert "$PKI/ca.crt" https://mail.example.test/mail/ -o /tmp/lpic103-webmail.html
```

Ожидаемый вывод и результат:

```text
curl завершается с exit status = 0; тело ответа перенаправлено в указанный файл или /dev/null.
```

## Шаг 31. Отфильтровать диагностический вывод

```bash
grep -Ei 'login|roundcube|sogo' /tmp/lpic103-webmail.html
```

## Шаг 32. Проверить запрет открытого relaying

Попытайтесь передать письмо между двумя внешними доменами без аутентификации и остановите SMTP-сеанс после RCPT. Исправный сервер обязан отклонить relaying.

```bash
swaks --server mail.example.test --port 25 \
  --from outsider@external.test --to user@outside.test \
  --quit-after RCPT || echo 'Relay отклонен ожидаемо'
```

Ожидаемый вывод и результат:

```text
<** 454/550/554 Relay access denied
Отрицательный тест завершен ожидаемым отказом
```

Dovecot находит TEST_ID в INBOX, страница входа webmail доступна по HTTPS, неаутентифицированный внешний relay отклонен.
