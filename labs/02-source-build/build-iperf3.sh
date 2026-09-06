#!/usr/bin/env bash
# Проверенная сборка iperf3 из выданного преподавателем архива.
# Скрипт компилирует и тестирует без root; установку намеренно не выполняет.
set -euo pipefail

# Требуются ровно архив и подписанный/доверенно переданный checksum manifest.
if [ "$#" -ne 2 ]; then
    echo "Использование: $0 /path/iperf3-X.Y.tar.gz /path/SHA256SUMS" >&2
    exit 2
fi
archive=$(realpath "$1")
sums=$(realpath "$2")
# LPIC103_BUILD_DIR позволяет вынести build tree; по умолчанию он рядом с запуском.
workdir=${LPIC103_BUILD_DIR:-"$PWD/build-iperf3"}

# Закрытый для посторонних каталог защищает промежуточные результаты сборки.
install -d -m 0750 "$workdir"
cp -- "$archive" "$sums" "$workdir/"
cd "$workdir"
# Любое несовпадение SHA-256 останавливает скрипт из-за set -e.
sha256sum -c "$(basename "$sums")"
# Сначала показываем первые пути: это помогает заметить неожиданный layout архива.
tar tf "$(basename "$archive")" | sed -n '1,20p'
tar xf "$(basename "$archive")"
# Ищем единственный ожидаемый верхнеуровневый каталог исходников iperf-3.*.
source_dir=$(find . -mindepth 1 -maxdepth 1 -type d -name 'iperf-*' -print -quit)
[ -n "$source_dir" ] || { echo "Каталог iperf-* в архиве не найден" >&2; exit 1; }
cd "$source_dir"
# /usr/local не принадлежит package manager системы.
./configure --prefix=/usr/local
# Параллельность равна числу доступных logical CPUs.
make -j"$(nproc)"
# Ошибка project tests блокирует рекомендацию make install.
make check

# Root нужен только для отдельного, явно подтвержденного этапа установки.
echo "Сборка и тесты завершены. Изучите config.log. Для установки выполните:"
echo "  cd '$PWD' && sudo make install && sudo ldconfig"
