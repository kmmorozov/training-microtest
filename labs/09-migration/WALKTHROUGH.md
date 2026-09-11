# Лабораторная работа 09. Миграция сервисных данных с коротким окном остановки

[Подготовка, пакеты, полные конфиги и уточнения](README.md) · [Общие материалы и ключи](../../PREPARATION.md)

Ниже все шаги руководства лабораторных v4 от 10.08.2026 с сохраненными
командами и ожидаемыми результатами. Сначала выполните подготовку в README:
она определяет адреса, значения переменных и различия ОС. Команды выполняются
по одной, на указанной машине; альтернативные ветки ОС не выполняются вместе.
В командах по умолчанию X=10/Y=20/Z=30, lab NIC=enp0s8, зоны internal/external/public.
Их необходимо сопоставить с реальными NIC/zone по README. Имена unit и web-user
по умолчанию Rocky; для Debian/Ubuntu используйте соответствия из README.
Выводы — образцы, а не протокол запуска на вашей ВМ.

Цель лабораторной работы: выполнить двухпроходную rsync-миграцию, остановить writer только для финальной дельты и доказать совпадение данных и метаданных.

Стенд: одна Linux-ВМ с rsync, acl, systemd и каталогами /srv/lpic103-migrate-{src,dst}.

Сценарий: данные работающего сервиса переносятся в новый каталог: основная масса копируется заранее, а финальная синхронизация выполняется в короткое окно остановки.

Планируемый результат: приемник совпадает с источником по файлам, checksum и ACL; границы окна остановки зафиксированы, а переключение выполнено временным bind mount без изменения /etc/fstab.

## Ограничения и безопасность

Важно: Нне используйте --delete, пока source и destination не проверены через realpath.

Важно: Bind mount в этой работе временный; рабочий /etc/fstab не изменяется.

## Ход выполнения

## Шаг 1. Создать каталог с заданными правами

Writer имитирует сервис, который продолжает создавать данные во время первого прохода. Команда install создает каталог или копирует файл сразу с заданными владельцем и mode: -d выбирает каталог, -m задает права, -o/-g — владельца и группу.

```bash
sudo install -d -m 0750 /srv/lpic103-migrate-src /srv/lpic103-migrate-dst
```

## Шаг 2. Настроить права и атрибуты

Измените или прочитайте один слой прав. Проверяйте владельца, mode, ACL mask и права родительских каталогов отдельно.

```bash
sudo setfacl -m u:nobody:rx /srv/lpic103-migrate-src
```

## Шаг 3. Создать контрольный набор данных

Создайте контрольный файл заданного размера; if, of, bs и count однозначно определяют источник, назначение и объем.

```bash
sudo dd if=/dev/urandom of=/srv/lpic103-migrate-src/base.bin bs=1M count=32 status=none
```

Ожидаемый вывод и результат:

```text
<N> bytes copied ... или пустой вывод при status=none
```

## Шаг 4. Запустить временный unit

Команда обращается к systemd. enable управляет автозапуском, --now также меняет текущее состояние, status/show читают фактические свойства, reload применяет проверенную конфигурацию без полного restart.

```bash
sudo systemd-run --unit=lpic103-writer.service /bin/bash -c 'while :; do date --iso-8601=ns >> /srv/lpic103-migrate-src/events.log; sleep 1; done'
```

Ожидаемый вывод и результат:

```text
Running as unit: <имя>.service
```

## Шаг 5. Проверить текущее состояние unit

```bash
systemctl is-active lpic103-writer.service
```

Ожидаемый вывод и результат:

```text
active
```

events.log растет между двумя проверками.

## Шаг 6. Проверить канонические пути

Первый rsync переносит основную массу без остановки. -A и -X сохраняют ACL/xattrs, -H — hard links. Выполните одну файловую операцию только для явно указанного учебного пути и проверьте существование или свойства результата следующим шагом.

```bash
realpath /srv/lpic103-migrate-src /srv/lpic103-migrate-dst
```

Ожидаемый вывод и результат:

```text
<абсолютный канонический путь>
```

## Шаг 7. Синхронизировать данные

Выполните одну операцию с данными и метаданными; checksum/diff подтверждают результат, а dry-run не изменяет приемник.

```bash
sudo rsync -aHAXn --delete --info=stats2 /srv/lpic103-migrate-src/ /srv/lpic103-migrate-dst/
```

Ожидаемый вывод и результат:

```text
Number of files: <N>
Number of regular files transferred: <N>
exit status = 0
```

## Шаг 8. Синхронизировать данные

```bash
sudo rsync -aHAX --delete --info=stats2 /srv/lpic103-migrate-src/ /srv/lpic103-migrate-dst/
```

Ожидаемый вывод и результат:

```text
Number of files: <N>
Number of regular files transferred: <N>
exit status = 0
```

Первый проход завершился с exit code 0.

## Шаг 9. Зафиксировать время операции

Остановите writer, зафиксируйте начало и конец окна, затем перенесите только изменения, появившиеся после первого прохода.

```bash
date --iso-8601=ns | sudo tee /srv/lpic103-migrate-stop.begin
```

## Шаг 10. Остановить службу

```bash
sudo systemctl stop lpic103-writer.service
```

## Шаг 11. Синхронизировать данные

```bash
sudo rsync -aHAX --delete --info=stats2 /srv/lpic103-migrate-src/ /srv/lpic103-migrate-dst/
```

Ожидаемый вывод и результат:

```text
Number of files: <N>
Number of regular files transferred: <N>
exit status = 0
```

## Шаг 12. Зафиксировать время операции

```bash
date --iso-8601=ns | sudo tee /srv/lpic103-migrate-stop.end
```

## Шаг 13. Синхронизировать данные

```bash
sudo rsync -aHAXn --delete --itemize-changes /srv/lpic103-migrate-src/ /srv/lpic103-migrate-dst/
```

Ожидаемый вывод и результат:

```text
Dry-run не выводит изменений; exit status = 0.
```

Финальный dry-run не выводит изменений.

## Шаг 14. Найти объекты по заданному условию

Сверьте содержимое и ACL, затем временно подмените логический путь bind mount. Это репетирует switch без перезагрузки. Выполните одну операцию с данными и метаданными; checksum/diff подтверждают результат, а dry-run не изменяет приемник.

```bash
sudo find /srv/lpic103-migrate-src -type f -printf '%P\0' | sort -z | sudo xargs -0 -I{} sha256sum '/srv/lpic103-migrate-src/{}' | sudo tee /tmp/lpic103-src.sha
```

Ожидаемый вывод и результат:

```text
<найденные пути или сформированный список>; exit status = 0
```

## Шаг 15. Найти объекты по заданному условию

```bash
sudo find /srv/lpic103-migrate-dst -type f -printf '%P\0' | sort -z | sudo xargs -0 -I{} sha256sum '/srv/lpic103-migrate-dst/{}' | sed 's#migrate-dst#migrate-src#' | sudo tee /tmp/lpic103-dst.sha
```

Ожидаемый вывод и результат:

```text
<найденные пути или сформированный список>; exit status = 0
```

## Шаг 16. Сравнить контрольные данные

```bash
sudo diff -u /tmp/lpic103-src.sha /tmp/lpic103-dst.sha
```

Ожидаемый вывод и результат:

```text
<пустой вывод>; exit status = 0 — различий нет
```

## Шаг 17. Сравнить ACL источника и приемника

Нормализуйте корневые пути в выводе getfacl и сравните результирующие ACL. Пустой diff подтверждает совпадение владельцев, mode и ACL.

```bash
diff -u   <(sudo getfacl -R -p /srv/lpic103-migrate-src | sed 's#/srv/lpic103-migrate-src#TREE#g')   <(sudo getfacl -R -p /srv/lpic103-migrate-dst | sed 's#/srv/lpic103-migrate-dst#TREE#g')
```

Ожидаемый вывод и результат:

```text
Пустой вывод; exit status = 0 — ACL совпадают.
```

## Шаг 18. Подключить файловую систему

Выполните одну операцию файловой системы или подтвердите источник, тип, размер и mountpoint.

```bash
sudo mount --bind /srv/lpic103-migrate-dst /srv/lpic103-migrate-src
```

## Шаг 19. Проверить слой хранения

```bash
findmnt -T /srv/lpic103-migrate-src
```

Ожидаемый вывод и результат:

```text
TARGET SOURCE FSTYPE OPTIONS
<mountpoint> <device> <fstype> ...
```

diff пуст; findmnt показывает bind source migrate-dst.
