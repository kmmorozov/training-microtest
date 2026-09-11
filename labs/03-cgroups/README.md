# Лабораторная 03. Ограничения systemd/cgroup v2

Все 11 шагов с командами и выводом: [WALKTHROUGH.md](WALKTHROUGH.md).
[Общая подготовка](../../PREPARATION.md). Одна ВМ, минимум 1 GiB свободной RAM;
stress-ng берется из EPEL на Rocky и репозитория ОС на Debian/Ubuntu.
```bash
# Rocky: сначала EPEL/CRB по общей подготовке.
sudo dnf install -y stress-ng
# Debian/Ubuntu:
sudo apt install -y stress-ng
stat -fc %T /sys/fs/cgroup
cat /sys/fs/cgroup/cgroup.controllers
stress-ng --version
./labs/03-cgroups/run-limited-load.sh
```

Нужен `cgroup2fs`. Скрипт подробно комментирует CPUQuota=25%, MemoryHigh=192M,
MemoryMax=256M, TasksMax=32. Полный аналог для постоянного service:
[lpic103-load.service](lpic103-load.service). Выберите transient-скрипт **или**
unit; не запускайте оба с одинаковым именем.
```bash
systemctl show lpic103-load -p ControlGroup -p CPUQuotaPerSecUSec \
  -p MemoryHigh -p MemoryMax -p TasksMax
systemd-cgls --unit lpic103-load.service
systemd-cgtop --iterations=3
sudo journalctl -u lpic103-load --since '-3 min' --no-pager
```

CPUQuota — четверть одного CPU, а не 25% всех ядер.
Свойства снимайте пока идет 90-секундная нагрузка: успешно завершившийся
transient unit может быть выгружен, и поздний `systemctl show` его не найдет.
Тогда итог проверяйте в journal; для сохранения unit установите постоянный файл.
Если unit уже failed: сначала журнал, `sudo systemctl reset-failed lpic103-load`,
потом повтор. Для остановки нагрузки: `sudo systemctl stop lpic103-load`.
Архивы/ключи не нужны.
