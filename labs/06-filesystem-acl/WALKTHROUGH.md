# Лабораторная работа 06. Каталоги сервиса, UNIX-права, ACL и специальные атрибуты

[Подготовка, пакеты, полные конфиги и уточнения](README.md) · [Общие материалы и ключи](../../PREPARATION.md)

Ниже все шаги руководства лабораторных v4 от 10.08.2026 с сохраненными
командами и ожидаемыми результатами. Сначала выполните подготовку в README:
она определяет адреса, значения переменных и различия ОС. Команды выполняются
по одной, на указанной машине; альтернативные ветки ОС не выполняются вместе.
В командах по умолчанию X=10/Y=20/Z=30, lab NIC=enp0s8, зоны internal/external/public.
Их необходимо сопоставить с реальными NIC/zone по README. Имена unit и web-user
по умолчанию Rocky; для Debian/Ubuntu используйте соответствия из README.
Выводы — образцы, а не протокол запуска на вашей ВМ.

Цель лабораторной работы: спроектировать дерево данных одного сервиса и выдать ровно необходимые права процессу и операторам.

Стенд: одна Linux-ВМ с setfacl/getfacl/chattr; файловая система должна поддерживать POSIX ACL и inode flags.

Сценарий: приложению требуются отдельные каталоги кода, загрузок, журнала и обмена. Права настраиваются по принципу минимально необходимого доступа.

Планируемый результат: код, upload, cache, log и dropbox разнесены; default ACL наследуется, sticky bit защищает чужие файлы, а append-only запрещает перезапись журнала при разрешенном добавлении.

## Ограничения и безопасность

Важно: не выполняйте рекурсивный chmod/chown за пределами /srv/lpic103-app.

Важно: chattr +a/+i может мешать удалению и ротации. Не применяйте эти атрибуты вне указанного учебного файла.

## Ход выполнения

## Шаг 1. Создать группу

Отделите учетную запись процесса от группы операторов и двух тестовых людей. Измените одну учетную запись или группу; параметры UID/GID, shell и членство определяют будущую модель доступа.

```bash
sudo groupadd -f lpic103-ops
```

## Шаг 2. Создать учетную запись

Измените одну учетную запись или группу; параметры UID/GID, shell и членство определяют будущую модель доступа.

```bash
getent passwd lpic103-app >/dev/null || sudo useradd --system --home-dir /nonexistent --shell /usr/sbin/nologin lpic103-app
```

## Шаг 3. Создать учетную запись

```bash
getent passwd lpic103-alice >/dev/null || sudo useradd -m -G lpic103-ops lpic103-alice
```

## Шаг 4. Создать учетную запись

```bash
getent passwd lpic103-bob >/dev/null || sudo useradd -m -G lpic103-ops lpic103-bob
```

## Шаг 5. Проверить UID, GID и группы

Проверьте фактические UID, GID и дополнительные группы пользователя, от которых зависят разрешения сервиса.

```bash
id lpic103-app
```

Ожидаемый вывод и результат:

```text
uid=<UID>(<user>) gid=<GID>(<group>) groups=...
```

## Шаг 6. Проверить UID, GID и группы

```bash
id lpic103-alice
```

Ожидаемый вывод и результат:

```text
uid=<UID>(<user>) gid=<GID>(<group>) groups=...
```

## Шаг 7. Проверить UID, GID и группы

```bash
id lpic103-bob
```

Ожидаемый вывод и результат:

```text
uid=<UID>(<user>) gid=<GID>(<group>) groups=...
```

Оба оператора состоят в lpic103-ops, сервисный user — нет.

## Шаг 8. Создать каталог с заданными правами

install -d создает каталог сразу с явными owner, group и mode, не оставляя промежуточных root:root 0777. Команда install создает каталог или копирует файл сразу с заданными владельцем и mode: -d выбирает каталог, -m задает права, -o/-g — владельца и группу.

```bash
sudo install -d -o root -g root -m 0755 /srv/lpic103-app
```

## Шаг 9. Создать каталог с заданными правами

Команда install создает каталог или копирует файл сразу с заданными владельцем и mode: -d выбирает каталог, -m задает права, -o/-g — владельца и группу.

```bash
sudo install -d -o root -g lpic103-ops -m 2750 /srv/lpic103-app/code
```

## Шаг 10. Создать каталог с заданными правами

```bash
sudo install -d -o lpic103-app -g lpic103-ops -m 2770 /srv/lpic103-app/upload
```

## Шаг 11. Создать каталог с заданными правами

```bash
sudo install -d -o lpic103-app -g lpic103-ops -m 2750 /srv/lpic103-app/cache
```

## Шаг 12. Создать каталог с заданными правами

```bash
sudo install -d -o lpic103-app -g lpic103-ops -m 2750 /srv/lpic103-app/log
```

## Шаг 13. Создать каталог с заданными правами

```bash
sudo install -d -o root -g lpic103-ops -m 1770 /srv/lpic103-app/dropbox
```

## Шаг 14. Проверить права и атрибуты

Измените или прочитайте один слой прав. Проверяйте владельца, mode, ACL mask и права родительских каталогов отдельно.

```bash
namei -l /srv/lpic103-app/upload
```

Ожидаемый вывод и результат:

```text
f: <путь>
<mode> <owner> <group> <компонент пути>
```

namei -l показывает execute на каждом родительском каталоге.

## Шаг 15. Настроить права и атрибуты

Выдайте сервису rx к коду, rwx к upload и default ACL для новых объектов. ACL mask должна оставить эти права effective. Измените или прочитайте один слой прав. Проверяйте владельца, mode, ACL mask и права родительских каталогов отдельно.

```bash
sudo setfacl -m u:lpic103-app:rx,m:rx /srv/lpic103-app/code
```

## Шаг 16. Настроить права и атрибуты

```bash
sudo setfacl -m u:lpic103-app:rwx,m:rwx /srv/lpic103-app/upload
```

## Шаг 17. Настроить права и атрибуты

```bash
sudo setfacl -m d:u:lpic103-app:rwx,d:g:lpic103-ops:rwx,d:m:rwx /srv/lpic103-app/upload
```

## Шаг 18. Создать контрольный файл

```bash
sudo -u lpic103-app touch /srv/lpic103-app/upload/from-service
```

## Шаг 19. Создать контрольный файл

```bash
sudo -u lpic103-alice touch /srv/lpic103-app/upload/from-alice
```

## Шаг 20. Проверить права и атрибуты

```bash
getfacl -p /srv/lpic103-app/upload /srv/lpic103-app/upload/from-service
```

Ожидаемый вывод и результат:

```text
# file: <путь>
# owner: <owner>
user::<права>
group::<права>
other::<права>
```

Новые файлы имеют группу lpic103-ops и effective ACL без записи для others.

## Шаг 21. Выполнить проверку от имени заданного пользователя

Sticky bit проверяется двумя разными users. Append-only показывает отличие inode attribute от mode bits/ACL. Запустите одну файловую операцию от имени указанного пользователя, чтобы проверить доступ с его реальными UID, GID и группами.

```bash
sudo -u lpic103-alice sh -c 'echo alice > /srv/lpic103-app/dropbox/alice.txt'
```

## Шаг 22. Удалить указанный учебный объект

```bash
sudo -u lpic103-bob rm /srv/lpic103-app/dropbox/alice.txt || echo 'Ожидаемый отказ sticky bit'
```

## Шаг 23. Создать контрольный файл

```bash
sudo touch /srv/lpic103-app/log/audit.log
```

## Шаг 24. Настроить права и атрибуты

```bash
sudo chown lpic103-app:lpic103-ops /srv/lpic103-app/log/audit.log
```

## Шаг 25. Настроить права и атрибуты

```bash
sudo chattr +a /srv/lpic103-app/log/audit.log
```

## Шаг 26. Выполнить проверку от имени заданного пользователя

Запустите одну файловую операцию от имени указанного пользователя, чтобы проверить доступ с его реальными UID, GID и группами.

```bash
sudo -u lpic103-app sh -c 'echo event >> /srv/lpic103-app/log/audit.log'
```

## Шаг 27. Выполнить проверку от имени заданного пользователя

```bash
sudo -u lpic103-app sh -c 'echo replace > /srv/lpic103-app/log/audit.log' || echo 'Ожидаемый отказ append-only'
```

Ожидаемый вывод и результат:

```text
<сообщение ожидаемого отказа, заданное после ||>
```

## Шаг 28. Проверить права и атрибуты

```bash
lsattr /srv/lpic103-app/log/audit.log
```

Ожидаемый вывод и результат:

```text
-----a----------- <путь> или набор атрибутов, соответствующий сценарию
```

Боб не удалил файл Alice.

В audit.log есть event, но нет replace.

## Шаг 29. Создать контрольный файл

Модель доступа принимается только после проверки запрещенных операций.

```bash
sudo -u lpic103-app touch /srv/lpic103-app/code/forbidden || echo 'Запись в code запрещена'
```

## Шаг 30. Проверить чтение файла оператором

```bash
sudo -u lpic103-bob test -r /srv/lpic103-app/upload/from-service && echo 'Чтение оператору разрешено'
```

Ожидаемый вывод и результат:

```text
Чтение оператору разрешено
```

## Шаг 31. Выполнить защитную проверку

Проверьте предусловие без изменения системы; успешный test обычно ничего не выводит и возвращает код 0.

```bash
sudo -u nobody test -r /srv/lpic103-app/upload/from-service || echo 'Посторонний не читает'
```

Ожидаемый вывод и результат:

```text
Посторонний не читает
```

## Шаг 32. Проверить слой хранения

Выполните одну операцию файловой системы или подтвердите источник, тип, размер и mountpoint.

```bash
findmnt -T /srv/lpic103-app
```

Ожидаемый вывод и результат:

```text
TARGET SOURCE FSTYPE OPTIONS
<mountpoint> <device> <fstype> ...
```

## Шаг 33. Проверить слой хранения

```bash
df -h /srv/lpic103-app
```

Ожидаемый вывод и результат:

```text
Filesystem Type Size Used Avail Use% Mounted on
...
```

Получены все ожидаемые allow/deny без chmod 777.
