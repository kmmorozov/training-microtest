#!/usr/bin/env bash
# Первый проход безопасной двухпроходной миграции с обязательным rsync dry-run.
# Финальный проход выполняется отдельно после остановки writer по инструкции.
set -euo pipefail

# Допускаются параметры для явности, но ниже они ограничены точной учебной парой.
src=${1:-/srv/lpic103-migrate-src}
dst=${2:-/srv/lpic103-migrate-dst}
src=$(realpath "$src")
dst=$(realpath "$dst")
[ "$src" != "$dst" ] || { echo "source и destination совпадают" >&2; exit 1; }
# --delete опасен, поэтому никакие произвольные пути скрипт не принимает.
case "$src:$dst" in
    /srv/lpic103-migrate-src:/srv/lpic103-migrate-dst) ;;
    *) echo "Разрешена только учебная пара /srv/lpic103-migrate-{src,dst}" >&2; exit 1;;
esac

# -aHAX сохраняет metadata/hardlinks/ACL/xattrs; -n гарантирует отсутствие записи.
sudo rsync -aHAXn --delete --info=stats2 "$src/" "$dst/"
printf 'Dry-run выше не должен содержать неожиданных удалений.\n'
read -r -p 'Выполнить первый проход? Введите YES: ' answer
[ "$answer" = YES ] || exit 1
# Первый реальный проход выполняется при работающем сервисе и переносит bulk data.
sudo rsync -aHAX --delete --info=stats2 "$src/" "$dst/"

# Автоматически останавливать чужой unit скрипт не будет: границы downtime
# преподаватель/слушатель фиксирует вручную перед final delta.
echo "Для финального прохода остановите writer и выполните:"
echo "sudo rsync -aHAX --delete --info=stats2 '$src/' '$dst/'"
echo "sudo rsync -aHAXn --delete --itemize-changes '$src/' '$dst/'"
