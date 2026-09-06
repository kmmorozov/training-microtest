# RAID1 с hot spare

После успешного `preflight.sh /dev/sdb /dev/sdc /dev/sdd` и ручной сверки
MODEL/SERIAL выполните команды из лабораторной работы:

```bash
sudo mdadm --create /dev/md/lpic103 --metadata=1.2 --level=1 --raid-devices=2 /dev/sdb /dev/sdc
sudo mdadm /dev/md/lpic103 --add /dev/sdd
sudo mdadm --wait /dev/md/lpic103
sudo mdadm --detail /dev/md/lpic103
sudo mkfs.ext4 -L LPIC103_RAID /dev/md/lpic103
sudo install -d /mnt/lpic103-raid
sudo mount /dev/md/lpic103 /mnt/lpic103-raid
```

`mdadm --create` и `mkfs.ext4` уничтожают прежние метаданные на выбранных
устройствах. Поэтому они намеренно не автоматизированы.
