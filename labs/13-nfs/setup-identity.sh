#!/usr/bin/env bash
# Создает одинаковые numeric UID/GID 2103 на NFS server и client.
# AUTH_SYS передает числа, поэтому одинаковых имен с разными ID недостаточно.
set -euo pipefail

# Скрипт нужно выполнить отдельно на обеих ВМ до файловой проверки.
[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "Запустите через sudo на сервере и клиенте" >&2; exit 1; }
# Существующие identity не изменяются автоматически: оператор должен сверить id.
getent group lpic103-nfs >/dev/null || groupadd -g 2103 lpic103-nfs
getent passwd lpic103-nfs >/dev/null || useradd -u 2103 -g 2103 -m lpic103-nfs
id lpic103-nfs
# Ожидается uid=2103 и gid=2103; иначе lab нужно остановить и согласовать IDs.
echo "UID и GID должны быть 2103 на обеих ВМ."
