# Лабораторная 08. LVM: расширение, snapshot, thin pool

Все 43 шага и подробные выводы: [WALKTHROUGH.md](WALKTHROUGH.md).
[COMMANDS.md](COMMANDS.md) — компактный список операций;
[подготовка](../../PREPARATION.md). Нужны три **других пустых диска**
по 2 GiB или больше (/dev/sde–sdg в примере); не использовать диски RAID lab07.
```bash
# Rocky:
sudo dnf install -y lvm2 device-mapper-persistent-data e2fsprogs util-linux
# Debian/Ubuntu:
sudo apt install -y lvm2 thin-provisioning-tools e2fsprogs util-linux
sudo ./labs/08-lvm/preflight.sh /dev/sde /dev/sdf /dev/sdg
sudo pvs
sudo vgs
sudo lvs -a
```

Ключи, архивы и ручной lvm.conf не нужны: работает штатный полный конфиг пакета.
Исходные данные создаются tee/dd. Не меняйте global filter LVM для этой лабы.
На Rocky с devices file создание PV через pvcreate регистрирует устройства;
проверка: `sudo lvmdevices`, если команда доступна.

Выполняйте WALKTHROUGH по порядку. Увеличение LV не увеличивает ext4 до
`resize2fs`; наблюдайте разницу `lvs`/df. Для XFS команда другая
(`xfs_growfs`) и уменьшение недоступно — в данном упражнении используйте ext4.
Snapshot `ro,noload` показывает v1 при v2 в origin. Это файловый учебный тест,
не гарантия консистентности работающей БД: для БД нужна ее процедура quiesce.

Thin virtual size 3G может превышать физический pool 1500M. Data%/Meta% —
реально занятое место; не заполняйте их до 100%. Отчет — pvs/vgs/lvs/findmnt
из последних шагов. При `insufficient free space` сверьте размеры дисков
и extents; не удаляйте другие LV для продолжения. Откат целиком — snapshot ВМ;
перед ручным lvremove должны быть размонтированы **все** учебные ФС.
