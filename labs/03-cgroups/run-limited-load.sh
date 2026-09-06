#!/usr/bin/env bash
# Создает ограниченную нагрузку только в transient unit lpic103-load.service.
# Не меняет system.slice/user.slice и автоматически завершается через 90 секунд.
set -euo pipefail

# Лабораторная рассчитана на unified hierarchy cgroup v2.
[ "$(stat -fc %T /sys/fs/cgroup)" = cgroup2fs ] || {
    echo "Требуется cgroup v2" >&2; exit 1;
}
command -v stress-ng >/dev/null || { echo "Установите stress-ng" >&2; exit 1; }

# systemd-run создает отдельную cgroup. CPUQuota=25% — четверть одного CPU;
# MemoryHigh создает pressure threshold, MemoryMax — жесткий предел;
# TasksMax ограничивает суммарное число процессов и потоков.
sudo systemd-run --unit=lpic103-load.service \
    --property=CPUQuota=25% \
    --property=MemoryHigh=192M \
    --property=MemoryMax=256M \
    --property=TasksMax=32 \
    /usr/bin/stress-ng --cpu 2 --vm 1 --vm-bytes 128M --timeout 90s

# Читаем effective values, а не предполагаем, что параметры применились.
systemctl show lpic103-load.service \
    -p ControlGroup -p CPUQuotaPerSecUSec -p MemoryHigh -p MemoryMax -p TasksMax
# Показываем PID процессов именно внутри созданной control group.
systemd-cgls --unit lpic103-load.service
