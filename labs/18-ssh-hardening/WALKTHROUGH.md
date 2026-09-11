# Лабораторная работа 18. Защита SSH: сертификат, FIDO2 и TOTP

[Подготовка, пакеты, полные конфиги и уточнения](README.md) · [Общие материалы и ключи](../../PREPARATION.md)

Ниже все шаги руководства лабораторных v4 от 10.08.2026 с сохраненными
командами и ожидаемыми результатами. Сначала выполните подготовку в README:
она определяет адреса, значения переменных и различия ОС. Команды выполняются
по одной, на указанной машине; альтернативные ветки ОС не выполняются вместе.
В командах по умолчанию X=10/Y=20/Z=30, lab NIC=enp0s8, зоны internal/external/public.
Их необходимо сопоставить с реальными NIC/zone по README. Имена unit и web-user
по умолчанию Rocky; для Debian/Ubuntu используйте соответствия из README.
Выводы — образцы, а не протокол запуска на вашей ВМ.

Цель лабораторной работы: настроить три защищенных элемента входа: короткоживущий user certificate, FIDO2-ключ и TOTP через PAM, затем запретить password/root login.

Стенд: OpenSSH server со snapshot и консолью; offline user CA, FIDO2-token и PAM-модуль TOTP; не менее двух административных сеансов.

Сценарий: администратор переводит SSH с пароля на ключевую идентификацию и второй фактор. Каждый новый механизм проверяется до запрета старого доступа.

Планируемый результат: тестовый пользователь входит сертификатом или FIDO2-ключом и подтверждает TOTP; неверный TOTP, password и root login отклоняются, effective config это подтверждает.

## Ограничения и безопасность

Важно: до первого изменения откройте резервную консоль или второй SSH-сеанс и не закрывайте его до завершения всех проверок.

Важно: Private CA key не копируется на сервер; TOTP secret и recovery codes не покидают стенд, а экран терминала защищен от посторонних.

Важно: PAM-файл дистрибутива изменяется только после создания отдельной копии с mode 0600.

## Ход выполнения

## Шаг 1. Проверить SSH-вход

Докажите ключевой вход, определите unit SSH и сохраните основной sshd_config и PAM-файл до любых изменений. Откройте новый SSH-сеанс с явно выбранным способом аутентификации, чтобы исключить незаметный fallback на другой ключ или пароль.

```bash
ssh -o PreferredAuthentications=publickey labadmin@192.168.10.10 true
```

Ожидаемый вывод и результат:

```text
Удаленная команда завершена с exit status = 0
```

## Шаг 2. Скопировать объект с заданными правами

Команда install создает каталог или копирует файл сразу с заданными владельцем и mode: -d выбирает каталог, -m задает права, -o/-g — владельца и группу.

```bash
sudo install -m 0600 /etc/ssh/sshd_config /root/sshd_config.lpic103-secure.bak
```

## Шаг 3. Скопировать объект с заданными правами

```bash
sudo install -m 0600 /etc/pam.d/sshd /root/pam-sshd.lpic103-secure.bak
```

## Шаг 4. Проверить состояние службы

Команда обращается к systemd. enable управляет автозапуском, --now также меняет текущее состояние, status/show читают фактические свойства, reload применяет проверенную конфигурацию без полного restart.

```bash
systemctl status sshd --no-pager 2>/dev/null || systemctl status ssh --no-pager
```

Ожидаемый вывод и результат:

```text
Active: active (running) ...
Loaded: loaded (...)
```

## Шаг 5. Проверить синтаксис конфигурации SSH

Проверьте синтаксис или effective-конфигурацию службы до ее reload; при ошибке текущая служба не изменяется.

```bash
sudo sshd -t
```

Ожидаемый вывод и результат:

```text
Команда не сообщает синтаксических ошибок и завершается с exit status = 0.
```

Резервный сеанс открыт, обе копии существуют с mode 0600.

## Шаг 6. Создать или проверить SSH-ключ

CA подписывает только public key, ограничивая principal и срок. Сервер получает только public key CA. Создайте или исследуйте ключевой материал с явно заданными именем, сроком и алгоритмом; закрытый ключ не выводится.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_lpic103_cert -C lpic103-cert
```

Ожидаемый вывод и результат:

```text
Your identification has been saved in ...
Your public key has been saved in ...
```

## Шаг 7. Создать или проверить SSH-ключ

Передайте на offline CA-host только public key клиента. CA подписывает его с principal и коротким сроком; полученный файл *-cert.pub верните клиенту. Закрытый ключ CA и закрытый ключ пользователя не переносятся.

```bash
# На offline CA-host
ssh-keygen -s "$REPO/generated/ssh-ca/lpic103_user_ca.key" -I lpic103-labadmin-$(date +%Y%m%d) -n labadmin -V -5m:+60m ~/.ssh/id_lpic103_cert.pub
```

Ожидаемый вывод и результат:

```text
Signed user key ...: id "lpic103-<user>-<YYYYMMDD>" serial 0 for <user> valid from ...
```

## Шаг 8. Создать или проверить SSH-ключ

```bash
ssh-keygen -L -f ~/.ssh/id_lpic103_cert-cert.pub
```

Ожидаемый вывод и результат:

```text
Type: ssh-ed25519-cert-v01@openssh.com
Valid: ...
Principals: ...
```

## Шаг 9. Скопировать объект с заданными правами

```bash
# На сервер копируется только CA public key
sudo install -m 0644 "$HOME/lpic103_user_ca.pub" /etc/ssh/lpic103_user_ca.pub
```

## Шаг 10. Сформировать или вывести контрольные данные

```bash
echo 'TrustedUserCAKeys /etc/ssh/lpic103_user_ca.pub' | sudo tee /etc/ssh/sshd_config.d/60-lpic103-ca.conf
```

## Шаг 11. Проверить синтаксис конфигурации SSH

```bash
sudo sshd -t
```

Ожидаемый вывод и результат:

```text
Команда не сообщает синтаксических ошибок и завершается с exit status = 0.
```

## Шаг 12. Перечитать конфигурацию службы

```bash
sudo systemctl reload sshd
```

## Шаг 13. Проверить SSH-вход

Откройте новый SSH-сеанс с явно выбранным способом аутентификации, чтобы исключить незаметный fallback на другой ключ или пароль.

```bash
ssh -i ~/.ssh/id_lpic103_cert -o CertificateFile=~/.ssh/id_lpic103_cert-cert.pub labadmin@192.168.10.10 id
```

Ожидаемый вывод и результат:

```text
Удаленная команда завершена с exit status = 0
```

Principal совпадает с user, сертификат действует и вход успешен.

## Шаг 14. Создать или проверить SSH-ключ

Resident credential хранится на token, а verify-required требует PIN или биометрию при каждой подписи. Создайте или исследуйте ключевой материал с явно заданными именем, сроком и алгоритмом; закрытый ключ не выводится.

```bash
ssh-keygen -t ed25519-sk -O resident -O verify-required -f ~/.ssh/id_lpic103_sk -C lpic103-fido2
```

Ожидаемый вывод и результат:

```text
Your identification has been saved in ...
Your public key has been saved in ...
```

## Шаг 15. Установить открытый SSH-ключ

Добавьте только открытый ключ в authorized_keys целевого пользователя и затем проверяйте вход отдельной командой.

```bash
ssh-copy-id -i ~/.ssh/id_lpic103_sk.pub labadmin@192.168.10.10
```

Ожидаемый вывод и результат:

```text
Number of key(s) added: 1
```

## Шаг 16. Проверить SSH-вход

```bash
ssh -i ~/.ssh/id_lpic103_sk -o IdentitiesOnly=yes labadmin@192.168.10.10 id
```

Ожидаемый вывод и результат:

```text
Удаленная команда завершена с exit status = 0
```

Token требует PIN/verification и touch; вход выбранным FIDO2-ключом успешен.

## Шаг 17. Установить требуемые пакеты

Установите PAM-модуль для своей ОС и создайте секрет от имени тестового пользователя. Recovery codes сохраняются только пользователем. Установите пакеты только для выбранного семейства ОС. Ключ -y подтверждает пакетную транзакцию без дополнительного запроса.

```bash
# RHEL-like
sudo dnf install -y google-authenticator
```

## Шаг 18. Обновить метаданные пакетов

Обновите локальные метаданные репозиториев до установки пакетов; это действие не устанавливает и не обновляет сами пакеты.

```bash
# Debian/Ubuntu — альтернатива
sudo apt update
```

## Шаг 19. Установить требуемые пакеты

Установите пакеты только для выбранного семейства ОС. Ключ -y подтверждает пакетную транзакцию без дополнительного запроса.

```bash
# Debian/Ubuntu — альтернатива
sudo apt install -y libpam-google-authenticator
```

## Шаг 20. Создать TOTP-секрет

Создайте TOTP-секрет для указанной учетной записи; ключи задают time-based режим, защиту от повторов и ограничение частоты попыток.

```bash
sudo -u labadmin google-authenticator -t -d -f -r 3 -R 30 -w 3
```

Ожидаемый вывод и результат:

```text
Your new secret key is: <секрет>
Your emergency scratch codes are: <коды>
```

## Шаг 21. Проверить права и атрибуты

Измените или прочитайте один слой прав. Проверяйте владельца, mode, ACL mask и права родительских каталогов отдельно.

```bash
sudo -u labadmin stat -c '%U:%G %a %n' ~labadmin/.google_authenticator
```

Ожидаемый вывод и результат:

```text
<владелец>:<группа> <mode> <путь>
```

Файл секрета принадлежит user и имеет mode 0600.

## Шаг 22. Изменить конфигурацию <pam-файл-sshd>

PAM запрашивает TOTP, а AuthenticationMethods требует сначала publickey, затем keyboard-interactive:pam. Vendor password-auth/common-auth в auth-секции заменяется, чтобы не появлялся лишний запрос системного пароля.

Установите полный файл для этого этапа по [инструкции подготовки](README.md).
Она заменяет редактирование неполного блока из исходного пособия.

```bash
# Полные файлы pam-sshd-rhel/pam-sshd-debian и sshd_config-*.conf — в README.
# Выберите этап CA или MFA; перед reload обязательно:
sudo sshd -t
```

## Шаг 23. Изменить конфигурацию /etc/ssh/sshd_config.d/65-lpic103-mfa.conf

Установите полный файл для этого этапа по [инструкции подготовки](README.md).
Она заменяет редактирование неполного блока из исходного пособия.

```bash
# Полные файлы pam-sshd-rhel/pam-sshd-debian и sshd_config-*.conf — в README.
# Выберите этап CA или MFA; перед reload обязательно:
sudo sshd -t
```

## Шаг 24. Проверить синтаксис конфигурации SSH

```bash
sudo sshd -t
```

Ожидаемый вывод и результат:

```text
Команда не сообщает синтаксических ошибок и завершается с exit status = 0.
```

## Шаг 25. Проверить effective-конфигурацию SSH

```bash
sudo sshd -T | grep -E 'usepam|pubkeyauthentication|kbdinteractiveauthentication|authenticationmethods'
```

Ожидаемый вывод и результат:

```text
<effective-option> <value>
...; exit status = 0
```

## Шаг 26. Перечитать конфигурацию службы

```bash
sudo systemctl reload sshd
```

Effective config содержит оба обязательных этапа и reload не разорвал резервный сеанс.

## Шаг 27. Проверить SSH-вход

В новых сеансах проверьте certificate + TOTP и FIDO2 + TOTP, затем введите заведомо неверный TOTP и сопоставьте результат с журналом. Откройте новый SSH-сеанс с явно выбранным способом аутентификации, чтобы исключить незаметный fallback на другой ключ или пароль.

```bash
# Введите заведомо неверный TOTP при запросе
ssh -i ~/.ssh/id_lpic103_cert -o CertificateFile=~/.ssh/id_lpic103_cert-cert.pub -o PreferredAuthentications=publickey,keyboard-interactive labadmin@192.168.10.10 true || echo 'Неверный TOTP отклонен'
```

Ожидаемый вывод и результат:

```text
Permission denied ...
<сообщение ожидаемого отказа>
```

## Шаг 28. Проверить SSH-вход

```bash
ssh -i ~/.ssh/id_lpic103_cert -o CertificateFile=~/.ssh/id_lpic103_cert-cert.pub -o PreferredAuthentications=publickey,keyboard-interactive labadmin@192.168.10.10 id
```

Ожидаемый вывод и результат:

```text
Удаленная команда завершена с exit status = 0
```

## Шаг 29. Проверить SSH-вход

```bash
ssh -i ~/.ssh/id_lpic103_sk -o IdentitiesOnly=yes -o PreferredAuthentications=publickey,keyboard-interactive labadmin@192.168.10.10 id
```

Ожидаемый вывод и результат:

```text
Удаленная команда завершена с exit status = 0
```

## Шаг 30. Просмотреть журнал службы

Выберите журнал нужного unit и ограничьте временной диапазон, чтобы связать сообщение с только что выполненным действием.

```bash
sudo journalctl -u sshd --since '-10 min' --no-pager
```

Ожидаемый вывод и результат:

```text
... <unit>[PID]: <сообщение, относящееся к текущему действию> ...
```

Оба ключевых механизма работают с TOTP; неверный код отклоняется.

## Шаг 31. Создать группу

Только после успешных MFA-сеансов запретите пароль и root, ограничьте группу, проверьте effective config и повторите положительные тесты. Измените одну учетную запись или группу; параметры UID/GID, shell и членство определяют будущую модель доступа.

```bash
sudo groupadd -f ssh-users
```

## Шаг 32. Изменить членство пользователя

Измените одну учетную запись или группу; параметры UID/GID, shell и членство определяют будущую модель доступа.

```bash
sudo usermod -aG ssh-users labadmin
```

## Шаг 33. Изменить конфигурацию /etc/ssh/sshd_config.d/70-lpic103-hardening.conf

Установите полный файл для этого этапа по [инструкции подготовки](README.md).
Она заменяет редактирование неполного блока из исходного пособия.

```bash
# Полные файлы pam-sshd-rhel/pam-sshd-debian и sshd_config-*.conf — в README.
# Выберите этап CA или MFA; перед reload обязательно:
sudo sshd -t
```

## Шаг 34. Проверить синтаксис конфигурации SSH

```bash
sudo sshd -t
```

Ожидаемый вывод и результат:

```text
Команда не сообщает синтаксических ошибок и завершается с exit status = 0.
```

## Шаг 35. Проверить effective-конфигурацию SSH

```bash
sudo sshd -T | grep -E 'permitrootlogin|passwordauthentication|pubkeyauthentication|kbdinteractiveauthentication|allowgroups|authenticationmethods|trustedusercakeys'
```

Ожидаемый вывод и результат:

```text
<effective-option> <value>
...; exit status = 0
```

## Шаг 36. Перечитать конфигурацию службы

```bash
sudo systemctl reload sshd
```

## Шаг 37. Проверить SSH-вход

```bash
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no labadmin@192.168.10.10 true || echo 'Password отклонен'
```

Ожидаемый вывод и результат:

```text
Permission denied ...
<сообщение ожидаемого отказа>
```

## Шаг 38. Проверить SSH-вход

```bash
ssh -o BatchMode=yes root@192.168.10.10 true || echo 'Root отклонен'
```

Ожидаемый вывод и результат:

```text
Permission denied ...
<сообщение ожидаемого отказа>
```

## Шаг 39. Проверить SSH-вход

```bash
ssh -i ~/.ssh/id_lpic103_cert -o CertificateFile=~/.ssh/id_lpic103_cert-cert.pub labadmin@192.168.10.10 id
```

Ожидаемый вывод и результат:

```text
Удаленная команда завершена с exit status = 0
```

## Шаг 40. Проверить SSH-вход

```bash
ssh -i ~/.ssh/id_lpic103_sk -o IdentitiesOnly=yes labadmin@192.168.10.10 id
```

Ожидаемый вывод и результат:

```text
Удаленная команда завершена с exit status = 0
```

Certificate/FIDO2 + TOTP продолжают работать; password и root login не работают.
