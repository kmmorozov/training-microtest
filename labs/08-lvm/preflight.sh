#!/usr/bin/env bash
# Только read-only preflight перед pvcreate лабораторной 08.
# Скрипт не создает PV/VG/LV и требует три явных пустых учебных диска.
set -euo pipefail

[ "$#" -eq 3 ] || { echo "Использование: $0 /dev/sde /dev/sdf /dev/sdg" >&2; exit 2; }
for disk in "$@"; do
    # Принимаем только целый block device типа disk.
    [ -b "$disk" ] || { echo "$disk не является блочным устройством" >&2; exit 1; }
    [ "$(lsblk -ndo TYPE "$disk")" = disk ] || { echo "$disk не TYPE=disk" >&2; exit 1; }
    # Дочерние устройства, mounts и filesystem/LVM signatures блокируют продолжение.
    [ "$(lsblk -nr "$disk" | wc -l)" -eq 1 ] || { echo "$disk содержит дочерние устройства" >&2; exit 1; }
    [ -z "$(lsblk -nro MOUNTPOINTS "$disk" | sed '/^$/d')" ] || { echo "$disk смонтирован" >&2; exit 1; }
    if wipefs -n "$disk" | sed -n '2p' | grep -q .; then echo "$disk содержит сигнатуру" >&2; exit 1; fi
done
# Проверка метаданных LVM надежнее проверки наличия /dev/vg_lpic103.
if sudo vgs vg_lpic103 >/dev/null 2>&1; then
    echo "VG vg_lpic103 уже существует" >&2
    exit 1
fi
# Перед ручным pvcreate оператор сверяет MODEL/SERIAL/SIZE всех трех устройств.
lsblk -o NAME,MODEL,SERIAL,TYPE,SIZE,FSTYPE,MOUNTPOINTS "$@"
echo "Read-only preflight пройден. pvcreate выполняйте вручную по руководству."
