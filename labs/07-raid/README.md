# Лабораторная 07. RAID1, hot spare, отказ и rebuild

Все 19 шагов и контрольные выводы: [WALKTHROUGH.md](WALKTHROUGH.md).
Краткая последовательность дисковых операций: [COMMANDS.md](COMMANDS.md).
[Подготовка](../../PREPARATION.md). Одна ВМ и **три дополнительных пустых диска**
по 2 GiB или больше, одинакового размера. Добавьте их через настройки ВМ.
```bash
# Rocky:
sudo dnf install -y mdadm e2fsprogs util-linux procps-ng
# Debian/Ubuntu:
sudo apt install -y mdadm e2fsprogs util-linux procps
lsblk -o NAME,MODEL,SERIAL,TYPE,SIZE,FSTYPE,MOUNTPOINTS
sudo ./labs/07-raid/preflight.sh /dev/sdb /dev/sdc /dev/sdd
```

/dev/sdb–sdd — пример, замените **во всех шагах** на проверенные устройства.
Нужны пустые FSTYPE/MOUNTPOINTS, отсутствие сигнатур wipefs -n, совпадающие
MODEL/SERIAL с добавленными дисками. Системный диск не участвует.
При NVMe имена другие; идентифицируйте диск по serial, не порядку букв.

WALKTHROUGH полностью создает массив/ФС, probe.bin и SHA256, имитирует отказ,
ждет rebuild и повторяет checksum. `[UU]` означает два активных зеркала,
`[U_]` — деградированный массив, spare становится активным после отказа.
RAID не заменяет backup; random probe создается dd, скачивать его не нужно.
Образец полный конфигурации сохранения массива генерируется **из его UUID**:
```bash
sudo mdadm --detail --scan
# Сохранить вывод для отчета, не заменяя конфиг других массивов:
sudo mdadm --detail --scan | tee generated/lab07-mdadm.conf
```

Автосборка после reboot не часть данного упражнения: live /dev/md и mount
достаточны для проверки rebuild. Для постоянного dedicated стенда добавьте
полную строку ARRAY в mdadm.conf своей ОС и обновите initramfs согласно пакету.
Перед остановкой массива: выйдите из mountpoint, umount, затем
`sudo mdadm --stop /dev/md/lpic103`. Снятие metadata — отдельное удаление данных,
для возврата чистого стенда используйте snapshot ВМ.
