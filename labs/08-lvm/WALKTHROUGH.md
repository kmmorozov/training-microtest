# Лабораторная работа 08. LVM для сервисных данных: расширение, snapshot и thin provisioning

[Подготовка, пакеты, полные конфиги и уточнения](README.md) · [Общие материалы и ключи](../../PREPARATION.md)

Ниже все шаги руководства лабораторных v4 от 10.08.2026 с сохраненными
командами и ожидаемыми результатами. Сначала выполните подготовку в README:
она определяет адреса, значения переменных и различия ОС. Команды выполняются
по одной, на указанной машине; альтернативные ветки ОС не выполняются вместе.
В командах по умолчанию X=10/Y=20/Z=30, lab NIC=enp0s8, зоны internal/external/public.
Их необходимо сопоставить с реальными NIC/zone по README. Имена unit и web-user
по умолчанию Rocky; для Debian/Ubuntu используйте соответствия из README.
Выводы — образцы, а не протокол запуска на вашей ВМ.

Цель лабораторной работы: на одной VG создать том данных, расширить его и файловую систему, получить согласованный snapshot и создать thin volume.

Стенд: одна изолированная Linux-ВМ с lvm2 и тремя отдельными пустыми дисками /dev/sde, /dev/sdf и /dev/sdg суммарным размером не менее 6 ГБ.

Сценарий: том приложения почти заполнен. Сначала его увеличивают без остановки, затем перед изменением приложения фиксируют состояние snapshot и создают thin volume для тестового экземпляра.

Планируемый результат: одна цепочка PV → VG содержит расширенный lv_data, читаемый snapshot состояния до изменения и thin pool с виртуальным томом.

## Ограничения и безопасность

Важно: /dev/sde, /dev/sdf и /dev/sdg должны быть выделенными пустыми учебными дисками. pvcreate перезапишет их метаданные.

Важно: Snapshot зависит от origin и той же VG и не заменяет резервную копию.

Важно: не используйте lvreduce: уменьшение томов в эту работу не входит.

## Ход выполнения

## Шаг 1. Проверить назначенные диски

Все три устройства должны быть отдельными учебными дисками без разделов, файловых систем и точек монтирования. Для сценария требуется не менее 6 ГБ суммарного свободного пространства.

```bash
lsblk -o NAME,MODEL,SERIAL,TYPE,SIZE,FSTYPE,MOUNTPOINTS /dev/sde /dev/sdf /dev/sdg
```

Ожидаемый вывод и результат:

```text
sde, sdf и sdg имеют TYPE=disk; FSTYPE и MOUNTPOINTS пусты; дочерних разделов нет.
```

## Шаг 2. Проверить отсутствие сигнатур

Ключ -n не изменяет диски. Если команда обнаружила старую сигнатуру, устройство нельзя передавать pvcreate до проверки его назначения.

```bash
sudo wipefs -n /dev/sde /dev/sdf /dev/sdg
```

Ожидаемый вывод и результат:

```text
Для /dev/sde, /dev/sdf и /dev/sdg список сигнатур пуст.
```

## Шаг 3. Проверить свободное имя volume group

Проверка выполняется по метаданным LVM, поэтому обнаружит даже неактивную VG, для которой каталог /dev/vg_lpic103 еще не создан.

```bash
sudo vgs --noheadings -o vg_name vg_lpic103 2>/dev/null | wc -l
```

Ожидаемый вывод и результат:

```text
0 — volume group с именем vg_lpic103 отсутствует.
```

## Шаг 4. Создать physical volumes

pvcreate записывает метаданные LVM непосредственно на три выделенных диска.

```bash
sudo pvcreate /dev/sde /dev/sdf /dev/sdg
```

Ожидаемый вывод и результат:

```text
Physical volume успешно создан на /dev/sde, /dev/sdf и /dev/sdg.
```

## Шаг 5. Создать volume group

VG объединяет extents трех PV в единый пул, из которого далее создаются обычный LV, snapshot и thin pool.

```bash
sudo vgcreate vg_lpic103 /dev/sde /dev/sdf /dev/sdg
```

Ожидаемый вывод и результат:

```text
Volume group vg_lpic103 successfully created.
```

## Шаг 6. Проверить physical volumes

```bash
sudo pvs -o pv_name,vg_name,pv_size,pv_free /dev/sde /dev/sdf /dev/sdg
```

Ожидаемый вывод и результат:

```text
Три строки PV: /dev/sde, /dev/sdf и /dev/sdg входят в vg_lpic103.
```

## Шаг 7. Проверить volume group

```bash
sudo vgs -o vg_name,pv_count,lv_count,vg_size,vg_free vg_lpic103
```

Ожидаемый вывод и результат:

```text
vg_lpic103 содержит 3 PV и имеет свободное пространство для последующих LV.
```

pvs и vgs показывают только назначенные диски и VG vg_lpic103.

## Шаг 8. Создать logical volume данных

LV является блочным устройством; файловая система и точка монтирования создаются отдельными следующими действиями.

```bash
sudo lvcreate -L 1G -n lv_data vg_lpic103
```

Ожидаемый вывод и результат:

```text
Logical volume lv_data created.
```

## Шаг 9. Создать файловую систему

ext4 создается на LV, а не непосредственно на одном из physical volumes.

```bash
sudo mkfs.ext4 -L LPIC103_DATA /dev/vg_lpic103/lv_data
```

Ожидаемый вывод и результат:

```text
ext4 с меткой LPIC103_DATA создана на /dev/vg_lpic103/lv_data.
```

## Шаг 10. Создать точки монтирования

```bash
sudo install -d /srv/lpic103-data /mnt/lpic103-snapshot
```

## Шаг 11. Подключить том данных

```bash
sudo mount /dev/vg_lpic103/lv_data /srv/lpic103-data
```

## Шаг 12. Создать контрольный файл

```bash
echo 'lvm data' | sudo tee /srv/lpic103-data/probe.txt
```

## Шаг 13. Зафиксировать исходную версию данных

```bash
echo v1 | sudo tee /srv/lpic103-data/version.txt
```

## Шаг 14. Сбросить файловые буферы

Запись исходных данных должна попасть на LV до проверки и последующего snapshot.

```bash
sync
```

## Шаг 15. Проверить источник точки монтирования

```bash
findmnt /srv/lpic103-data
```

Ожидаемый вывод и результат:

```text
TARGET=/srv/lpic103-data; SOURCE=/dev/mapper/vg_lpic103-lv_data; FSTYPE=ext4.
```

## Шаг 16. Проверить исходный размер файловой системы

```bash
df -hT /srv/lpic103-data
```

Ожидаемый вывод и результат:

```text
В выводе ext4 имеет размер около 1 ГБ.
```

Оба контрольных файла читаются из смонтированного lv_data.

## Шаг 17. Расширить logical volume

Сначала увеличивается блочный LV. Файловая система пока сохраняет прежний размер.

```bash
sudo lvextend -L +512M /dev/vg_lpic103/lv_data
```

Ожидаемый вывод и результат:

```text
Размер lv_data увеличен примерно до 1,5 ГБ.
```

## Шаг 18. Проверить новый размер logical volume

```bash
sudo lvs -o lv_name,lv_size /dev/vg_lpic103/lv_data
```

Ожидаемый вывод и результат:

```text
lv_data имеет размер примерно 1,5 ГБ.
```

## Шаг 19. Сравнить размер файловой системы до расширения

```bash
df -hT /srv/lpic103-data
```

Ожидаемый вывод и результат:

```text
До resize2fs файловая система по-прежнему имеет размер около 1 ГБ.
```

## Шаг 20. Расширить файловую систему

resize2fs передает ext4 добавленное пространство LV без размонтирования.

```bash
sudo resize2fs /dev/vg_lpic103/lv_data
```

Ожидаемый вывод и результат:

```text
The filesystem ... is now <N> blocks long.
```

## Шаг 21. Проверить размер расширенной файловой системы

```bash
df -hT /srv/lpic103-data
```

Ожидаемый вывод и результат:

```text
После resize2fs файловая система имеет размер около 1,5 ГБ.
```

## Шаг 22. Проверить сохранность контрольного файла

```bash
cat /srv/lpic103-data/probe.txt
```

df показывает прирост примерно на 512 МБ, probe.txt содержит lvm data.

## Шаг 23. Подготовить данные к snapshot

Для простого файла достаточно sync. Для работающей БД перед snapshot потребовался бы native flush или согласованная остановка приложения.

```bash
sync
```

## Шаг 24. Создать snapshot

Snapshot хранит исходные блоки, изменившиеся в origin, и зависит от той же VG; он не является независимой резервной копией.

```bash
sudo lvcreate --snapshot --name lv_before --size 512M /dev/vg_lpic103/lv_data
```

Ожидаемый вывод и результат:

```text
Logical volume lv_before created.
```

## Шаг 25. Изменить данные в origin

```bash
echo v2 | sudo tee /srv/lpic103-data/version.txt
```

## Шаг 26. Подключить snapshot только для чтения

Параметр noload запрещает replay журнала ext4 внутри snapshot и сохраняет зафиксированное состояние неизменным.

```bash
sudo mount -o ro,noload /dev/vg_lpic103/lv_before /mnt/lpic103-snapshot
```

## Шаг 27. Вывести метку origin

```bash
printf 'origin='
```

## Шаг 28. Прочитать версию из origin

```bash
cat /srv/lpic103-data/version.txt
```

## Шаг 29. Вывести метку snapshot

```bash
printf 'snapshot='
```

## Шаг 30. Прочитать версию из snapshot

```bash
cat /mnt/lpic103-snapshot/version.txt
```

Origin содержит v2, а snapshot сохраняет состояние v1.

## Шаг 31. Проверить заполнение snapshot

Data% показывает заполнение copy-on-write области. При достижении 100% snapshot становится непригоден.

```bash
sudo lvs -o lv_name,origin,lv_size,data_percent vg_lpic103
```

Ожидаемый вывод и результат:

```text
lv_before ссылается на lv_data; Data% заметно ниже 100%.
```

## Шаг 32. Изменить блоки origin

Запись новых блоков в origin должна увеличить Data% snapshot.

```bash
sudo dd if=/dev/zero of=/srv/lpic103-data/change.bin bs=1M count=64 status=none
```

## Шаг 33. Сбросить измененные блоки

```bash
sync
```

## Шаг 34. Повторно проверить заполнение snapshot

```bash
sudo lvs -o lv_name,origin,lv_size,data_percent vg_lpic103
```

Ожидаемый вывод и результат:

```text
Data% snapshot вырос и остается заметно ниже 100%.
```

## Шаг 35. Создать thin pool

Thin pool выделяет физическое пространство по мере записи и отдельно учитывает data и metadata.

```bash
sudo lvcreate --type thin-pool -L 1500M -n pool0 vg_lpic103
```

Ожидаемый вывод и результат:

```text
Thin pool pool0 created.
```

## Шаг 36. Создать thin volume

Виртуальный размер thin volume может быть больше pool, поэтому Data% и Metadata% необходимо контролировать, не допуская исчерпания.

```bash
sudo lvcreate --type thin -V 3G -n thin_web vg_lpic103/pool0
```

Ожидаемый вывод и результат:

```text
Thin logical volume thin_web created с виртуальным размером 3 ГБ.
```

## Шаг 37. Создать файловую систему на thin volume

```bash
sudo mkfs.ext4 /dev/vg_lpic103/thin_web
```

Ожидаемый вывод и результат:

```text
ext4 создана на /dev/vg_lpic103/thin_web.
```

## Шаг 38. Проверить thin provisioning

```bash
sudo lvs -a -o lv_name,lv_size,pool_lv,data_percent,metadata_percent vg_lpic103
```

Ожидаемый вывод и результат:

```text
thin_web имеет виртуальный размер 3 ГБ и использует pool0 размером около 1,5 ГБ; Data% и Metadata% ниже 100%.
```

thin_web имеет виртуальный размер 3 ГБ при pool около 1,5 ГБ.

## Шаг 39. Проверить связь physical volumes и VG

```bash
sudo pvs -o pv_name,vg_name,pv_size,pv_free
```

Ожидаемый вывод и результат:

```text
/dev/sde, /dev/sdf и /dev/sdg входят в vg_lpic103.
```

## Шаг 40. Проверить свободное пространство VG

```bash
sudo vgs -o vg_name,vg_size,vg_free
```

Ожидаемый вывод и результат:

```text
В строке vg_lpic103 показаны суммарный размер трех PV и остаток свободных extents.
```

## Шаг 41. Проверить все logical volumes

```bash
sudo lvs -a -o lv_name,vg_name,lv_size,origin,pool_lv,data_percent,metadata_percent
```

Ожидаемый вывод и результат:

```text
Выведены lv_data, lv_before, pool0, служебные thin-pool volumes и thin_web.
```

## Шаг 42. Проверить физическую цепочку хранения

```bash
lsblk -o NAME,TYPE,FSTYPE,SIZE,MOUNTPOINTS /dev/sde /dev/sdf /dev/sdg
```

Ожидаемый вывод и результат:

```text
Под sde, sdf и sdg показаны компоненты device-mapper VG vg_lpic103; lv_data связан с /srv/lpic103-data.
```

## Шаг 43. Проверить итоговую точку монтирования

```bash
findmnt -T /srv/lpic103-data
```

Ожидаемый вывод и результат:

```text
/srv/lpic103-data смонтирована с /dev/mapper/vg_lpic103-lv_data как ext4.
```

Каждый верхний слой ссылается на ожидаемый нижний слой.
