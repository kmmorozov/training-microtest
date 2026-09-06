#!/usr/bin/env bash
# Создает защищенную точку восстановления конфигурации одного systemd сервиса.
# Архивирует только /etc/*, фиксирует unit/packages/listeners и делает restore-test.
set -euo pipefail

# Аргументы явно разделяют config tree, unit и закрытый backup destination.
[ "$#" -eq 3 ] || {
    echo "Использование: sudo $0 /etc/service unit.service /root/backup-dir" >&2; exit 2;
}
[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "Требуются root-права" >&2; exit 1; }
# realpath устраняет ../ и symlink ambiguity до проверки разрешенной области.
config=$(realpath "$1")
unit=$2
destination=$3
# Ограничение /etc/* не дает случайно заархивировать /, /home или весь volume.
case "$config" in /etc/*) ;; *) echo "Разрешен config только внутри /etc" >&2; exit 1;; esac
[ -e "$config" ] || { echo "Нет $config" >&2; exit 1; }

# Каждый запуск получает новый timestamped каталог mode 0700 без перезаписи.
stamp=$(date +%Y%m%d-%H%M%S)
out="$destination/$unit-$stamp"
install -d -m 0700 "$out"
archive="$out/config.tgz"
# Относительный путь и -C / делают архив восстанавливаемым; ACL/xattrs сохраняются.
tar --xattrs --acls -C / -czf "$archive" "${config#/}"
# Effective unit может включать drop-ins, поэтому systemctl cat важнее копии одного файла.
systemctl cat "$unit" >"$out/unit-effective.txt"
# Socket baseline позволяет сравнить listeners после изменения/отката.
ss -lntup >"$out/listening.txt"
# Фиксируем package inventory только выбранного семейства ОС.
if command -v rpm >/dev/null; then
    rpm -qa | sort >"$out/packages.txt"
else
    dpkg-query -W >"$out/packages.txt"
fi
# SHA-256 обнаруживает повреждение/подмену архива; это не криптографическая подпись.
sha256sum "$archive" >"$out/SHA256SUMS"

# Backup считается рабочим только после успешной распаковки в отдельный temp tree.
restore=$(mktemp -d /tmp/lpic103-restore.XXXXXX)
# trap удаляет только каталог, созданный mktemp с узким prefix.
trap 'rm -rf "$restore"' EXIT
tar -xzf "$archive" -C "$restore"
test -e "$restore/${config#/}"
# Повторная checksum-проверка завершает минимальный restore-test.
sha256sum -c "$out/SHA256SUMS"
echo "Backup и пробное восстановление: OK — $out"
