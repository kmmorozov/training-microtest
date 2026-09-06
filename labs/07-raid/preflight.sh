#!/usr/bin/env bash
# Только read-only preflight перед разрушительным mdadm --create лабораторной 07.
# Скрипт НИЧЕГО не форматирует и требует три явных device path.
set -euo pipefail

# Ожидаются два active RAID1-компонента и один hot spare.
[ "$#" -eq 3 ] || { echo "Использование: $0 /dev/sdb /dev/sdc /dev/sdd" >&2; exit 2; }
for disk in "$@"; do
    # Защита от опечатки/обычного файла и от передачи partition/LV вместо disk.
    [ -b "$disk" ] || { echo "$disk не является блочным устройством" >&2; exit 1; }
    [ "$(lsblk -ndo TYPE "$disk")" = disk ] || { echo "$disk не TYPE=disk" >&2; exit 1; }
    # Смонтированный диск или диск с дочерним разделом нельзя передавать mdadm.
    [ -z "$(lsblk -nro MOUNTPOINTS "$disk" | sed '/^$/d')" ] || { echo "$disk смонтирован" >&2; exit 1; }
    [ "$(lsblk -nr "$disk" | wc -l)" -eq 1 ] || { echo "$disk содержит дочерние устройства" >&2; exit 1; }
    # wipefs -n только читает signatures; любая найденная signature останавливает lab.
    if wipefs -n "$disk" | sed -n '2p' | grep -q .; then
        echo "$disk содержит сигнатуру; остановка" >&2; exit 1
    fi
done
# Имя массива не должно конфликтовать с уже собранным md device.
sudo test ! -e /dev/md/lpic103 || { echo "/dev/md/lpic103 уже существует" >&2; exit 1; }
# MODEL/SERIAL должны быть вручную сверены с назначением учебных дисков.
lsblk -o NAME,MODEL,SERIAL,TYPE,SIZE,FSTYPE,MOUNTPOINTS "$@"
echo "Read-only preflight пройден. Выполняйте команды руководства вручную."
