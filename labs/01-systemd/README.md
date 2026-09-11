# Лабораторная 01. systemd unit и drop-in

Полные 19 шагов, команды и вывод: [WALKTHROUGH.md](WALKTHROUGH.md).
Сначала [общая подготовка](../../PREPARATION.md). Одна ВМ с systemd,
sudo и Bash; Rocky: `sudo dnf install -y systemd bash shadow-utils`;
Ubuntu/Debian: `sudo apt install -y systemd bash passwd`.
Пакеты из ОС, ключи/архивы не нужны.

## Полные файлы и установка

**Зачем: Устанавливаем полный unit и вспомогательный скрипт, чтобы получить воспроизводимый сервис для проверки systemd и локального переопределения.**

| Файл | Куда установить |
|---|---|
| [lpic103-demo](lpic103-demo) | /usr/local/libexec/lpic103-demo, 0755 |
| [lpic103-demo.service](lpic103-demo.service) | /etc/systemd/system/lpic103-demo.service |
| [override.conf](override.conf) | /etc/systemd/system/lpic103-demo.service.d/override.conf |

Из корня репозитория:
```bash
# Скрипт создает служебного пользователя и устанавливает полный unit.
sudo ./labs/01-systemd/install.sh
systemctl cat lpic103-demo.service
systemctl show lpic103-demo -p User -p MainPID -p Restart
sudo journalctl -u lpic103-demo --since '-2 min' --no-pager
# Этап изменения: устанавливаем полный самостоятельный drop-in.
sudo install -d /etc/systemd/system/lpic103-demo.service.d
sudo install -m 0644 labs/01-systemd/override.conf \
  /etc/systemd/system/lpic103-demo.service.d/override.conf
sudo systemd-analyze verify /etc/systemd/system/lpic103-demo.service
sudo systemctl daemon-reload
sudo systemctl restart lpic103-demo
sudo journalctl -u lpic103-demo --since '-30 sec' --no-pager
```

Для учебного ручного выполнения используйте шаги WALKTHROUGH вместо install.sh.
`daemon-reload` перечитывает определение, `restart` создает новый процесс с
новым INTERVAL. Сравните временные метки 10 s → 3 s и MainPID.
Если `User ... not found` — проверьте getent; `203/EXEC` — путь, mode и shebang.
Откат: `systemctl stop lpic103-demo`, убрать только созданный override или
восстановить его копию, daemon-reload, start. Пакетные units не изменяются.
