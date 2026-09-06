#!/usr/bin/env bash
# Устанавливает все артефакты лабораторной 01 и запускает demo unit.
# Скрипт меняет /usr/local, /etc/systemd и состояние systemd; нужен sudo.
set -euo pipefail

# EUID проверяется до первой системной операции, чтобы не получить полуустановку.
[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "Запустите через sudo" >&2; exit 1; }
# Абсолютный каталог источников позволяет запускать скрипт из любой директории.
src_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# Создаем непривилегированного пользователя только при его отсутствии.
getent passwd lpic103-demo >/dev/null || \
    useradd --system --home-dir /nonexistent --shell /usr/sbin/nologin lpic103-demo
install -d -m 0755 /usr/local/libexec /etc/systemd/system/lpic103-demo.service.d
# install одновременно копирует файл и задает предсказуемый mode.
install -m 0755 "$src_dir/lpic103-demo" /usr/local/libexec/lpic103-demo
install -m 0644 "$src_dir/lpic103-demo.service" /etc/systemd/system/lpic103-demo.service
install -m 0644 "$src_dir/override.conf" /etc/systemd/system/lpic103-demo.service.d/override.conf
# Синтаксис и ссылки проверяются до загрузки определения в PID 1.
systemd-analyze verify /etc/systemd/system/lpic103-demo.service
# daemon-reload перечитывает units, но сам по себе не запускает процесс.
systemctl daemon-reload
# --now включает автозапуск и немедленно стартует службу.
systemctl enable --now lpic103-demo.service
# Финальный status делает результат установки наблюдаемым.
systemctl --no-pager --full status lpic103-demo.service
