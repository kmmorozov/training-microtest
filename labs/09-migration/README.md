# Лабораторная 09. Двухпроходная миграция

Все 19 шагов с checksum/ACL и переключением: [WALKTHROUGH.md](WALKTHROUGH.md).
[Подготовка](../../PREPARATION.md). Одна ВМ, около 100 MiB свободного места.
```bash
# Rocky:
sudo dnf install -y rsync acl attr coreutils
# Debian/Ubuntu:
sudo apt install -y rsync acl attr coreutils
sudo install -d -m 0750 /srv/lpic103-migrate-src /srv/lpic103-migrate-dst
sudo install -d -m 0755 /usr/local/libexec
sudo install -m 0755 labs/09-migration/lpic103-writer /usr/local/libexec/lpic103-writer
sudo install -m 0644 labs/09-migration/lpic103-writer.service \
  /etc/systemd/system/lpic103-writer.service
sudo systemctl daemon-reload
sudo systemd-analyze verify /etc/systemd/system/lpic103-writer.service
```

Полный unit и writer уже в каталоге, данные генерируются локально.
В WALKTHROUGH замените transient `systemd-run` writer на
`sudo systemctl start lpic103-writer` при выборе этого постоянного unit.
Сначала выполните создание base.bin/ACL, затем writer и rsync dry-run.
[migrate.sh](migrate.sh) выполняет первый проход, остальное разбирается вручную.

`-aHAX` сохраняет metadata, hard links, ACL и xattrs; `--delete` удаляет лишнее
в **приемнике**, поэтому trailing slash и realpath важны. Второй проход идет
после остановки writer. Пустой rsync/diff — признак совпадения.
После bind mount из последнего шага возобновите запись:
```bash
sudo systemctl start lpic103-writer
sleep 2
sudo tail -n 3 /srv/lpic103-migrate-dst/events.log
findmnt -T /srv/lpic103-migrate-src
```

Этот шаг завершает окно остановки; измерение только времени rsync из исходного
пособия не включает последующую проверку и restart. На приемнике появились
новые события — переключение доказано.
Откат: остановить writer, `sudo umount /srv/lpic103-migrate-src`, проверить
исходные данные, затем start. Если после переключения были новые записи,
сначала перенесите delta обратно: просто unmount потеряет их видимость.
