# Лабораторная работа 07. RAID1 с hot spare, отказ диска и rebuild

[Подготовка, пакеты, полные конфиги и уточнения](README.md) · [Общие материалы и ключи](../../PREPARATION.md)

Ниже все шаги руководства лабораторных v4 от 10.08.2026 с сохраненными
командами и ожидаемыми результатами. Сначала выполните подготовку в README:
она определяет адреса, значения переменных и различия ОС. Команды выполняются
по одной, на указанной машине; альтернативные ветки ОС не выполняются вместе.
В командах по умолчанию X=10/Y=20/Z=30, lab NIC=enp0s8, зоны internal/external/public.
Их необходимо сопоставить с реальными NIC/zone по README. Имена unit и web-user
по умолчанию Rocky; для Debian/Ubuntu используйте соответствия из README.
Выводы — образцы, а не протокол запуска на вашей ВМ.

Цель лабораторной работы: создать RAID1 на /dev/sdb и /dev/sdc, добавить /dev/sdd как hot spare, сымитировать отказ и дождаться восстановления без потери контрольного файла.

Стенд: одна изолированная Linux-ВМ с mdadm и тремя отдельными пустыми дисками /dev/sdb, /dev/sdc и /dev/sdd.

Сценарий: учебный RAID1 должен пережить отказ /dev/sdb. /dev/sdd используется как hot spare и автоматически включается в rebuild.

Планируемый результат: /dev/md/lpic103 после rebuild имеет clean state и два active devices; checksum файла совпадает.

## Ограничения и безопасность

Важно: /dev/sdb, /dev/sdc и /dev/sdd должны быть выделенными пустыми учебными дисками. mdadm --create перезапишет их метаданные.

Важно: не подставляйте системный диск. Перед mdadm --create сверяйте TYPE, MODEL, SERIAL, FSTYPE и MOUNTPOINTS.

## Ход выполнения

## Шаг 1. Проверить назначенные диски

Все три устройства должны быть отдельными учебными дисками без разделов, файловых систем и точек монтирования. Если хотя бы один диск используется системой, работу продолжать нельзя.

```bash
lsblk -o NAME,MODEL,SERIAL,TYPE,SIZE,FSTYPE,MOUNTPOINTS /dev/sdb /dev/sdc /dev/sdd
```

Ожидаемый вывод и результат:

```text
sdb, sdc и sdd имеют TYPE=disk; FSTYPE и MOUNTPOINTS пусты; дочерних разделов нет.
```

## Шаг 2. Проверить отсутствие сигнатур

Ключ -n выполняет только чтение. Обнаруженная сигнатура означает, что диск не подготовлен как пустой учебный носитель и mdadm --create запускать нельзя.

```bash
sudo wipefs -n /dev/sdb /dev/sdc /dev/sdd
```

Ожидаемый вывод и результат:

```text
Для /dev/sdb, /dev/sdc и /dev/sdd список сигнатур пуст.
```

## Шаг 3. Проверить свободное имя массива

Проверка защищает от повторного использования имени уже существующего массива.

```bash
sudo test ! -e /dev/md/lpic103
```

Ожидаемый вывод и результат:

```text
exit status = 0: устройство /dev/md/lpic103 отсутствует.
```

## Шаг 4. Создать RAID1

/dev/sdb и /dev/sdc становятся двумя active-компонентами RAID1. Метаданные массива записываются непосредственно на выделенные диски.

```bash
sudo mdadm --create /dev/md/lpic103 --metadata=1.2 --level=1 --raid-devices=2 /dev/sdb /dev/sdc
```

Ожидаемый вывод и результат:

```text
Массив /dev/md/lpic103 запущен как RAID1; в /proc/mdstat отображается [UU].
```

## Шаг 5. Добавить hot spare

/dev/sdd добавляется как резервный компонент и не несет рабочую копию данных до отказа одного из active-дисков.

```bash
sudo mdadm /dev/md/lpic103 --add /dev/sdd
```

Ожидаемый вывод и результат:

```text
/dev/sdd добавлен в /dev/md/lpic103 как spare.
```

## Шаг 6. Дождаться первичной синхронизации

Наблюдайте за recovery/resync и завершите watch сочетанием Ctrl+C только после исчезновения индикатора прогресса.

```bash
watch -n 2 cat /proc/mdstat
```

Ожидаемый вывод и результат:

```text
/dev/md/lpic103 имеет состояние active raid1 и индикатор [UU]; строки recovery/resync больше нет.
```

## Шаг 7. Проверить состав массива

```bash
sudo mdadm --detail /dev/md/lpic103
```

Ожидаемый вывод и результат:

```text
State: clean; Active Devices: 2; Working Devices: 3; Spare Devices: 1; /dev/sdb и /dev/sdc active sync, /dev/sdd spare.
```

## Шаг 8. Создать файловую систему на массиве

Файловая система создается на устройстве массива, а не на его отдельных компонентах.

```bash
sudo mkfs.ext4 -L LPIC103_RAID /dev/md/lpic103
```

Ожидаемый вывод и результат:

```text
ext4 с меткой LPIC103_RAID создана на /dev/md/lpic103.
```

## Шаг 9. Создать точку монтирования

```bash
sudo install -d /mnt/lpic103-raid
```

## Шаг 10. Подключить файловую систему

```bash
sudo mount /dev/md/lpic103 /mnt/lpic103-raid
```

## Шаг 11. Создать контрольный файл

Контрольные данные записываются до имитации отказа, чтобы после rebuild проверить не только состояние md, но и целостность содержимого.

```bash
sudo dd if=/dev/urandom of=/mnt/lpic103-raid/probe.bin bs=1M count=8 status=none
```

## Шаг 12. Сохранить контрольную сумму

```bash
sudo sha256sum /mnt/lpic103-raid/probe.bin | sudo tee /mnt/lpic103-raid/probe.sha256
```

Ожидаемый вывод и результат:

```text
Выведена и сохранена 64-символьная SHA-256 сумма файла probe.bin.
```

sha256sum -c /mnt/lpic103-raid/probe.sha256 возвращает OK.

## Шаг 13. Пометить active-диск неисправным

После перевода /dev/sdb в faulty массив продолжает работу на /dev/sdc, а /dev/sdd автоматически переходит из spare в active и начинает rebuild.

```bash
sudo mdadm /dev/md/lpic103 --fail /dev/sdb
```

Ожидаемый вывод и результат:

```text
/dev/sdb отмечен faulty; в /proc/mdstat начинается recovery на /dev/sdd.
```

## Шаг 14. Удалить неисправный диск из массива

```bash
sudo mdadm /dev/md/lpic103 --remove /dev/sdb
```

Ожидаемый вывод и результат:

```text
/dev/sdb удален из состава /dev/md/lpic103.
```

## Шаг 15. Наблюдать rebuild

Дождитесь окончания recovery. Во время восстановления массив доступен, но работает без полного запаса отказоустойчивости.

```bash
watch -n 2 cat /proc/mdstat
```

Ожидаемый вывод и результат:

```text
Индикатор recovery достигает 100%, затем массив снова отображается как [UU].
```

## Шаг 16. Дождаться завершения операций md

```bash
sudo mdadm --wait /dev/md/lpic103
```

Ожидаемый вывод и результат:

```text
Команда завершается после окончания recovery/rebuild.
```

## Шаг 17. Проверить состояние после rebuild

```bash
sudo mdadm --detail /dev/md/lpic103
```

Ожидаемый вывод и результат:

```text
State: clean; Active Devices: 2; Failed Devices: 0; /dev/sdc и /dev/sdd имеют роль active sync.
```

## Шаг 18. Перейти к данным массива

```bash
cd /mnt/lpic103-raid
```

## Шаг 19. Проверить целостность данных

```bash
sudo sha256sum -c probe.sha256
```

Ожидаемый вывод и результат:

```text
probe.bin: OK
```

После rebuild массив имеет State: clean, а checksum совпадает.
