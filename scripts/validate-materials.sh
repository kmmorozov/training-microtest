#!/usr/bin/env bash
# Read-only self-check структуры учебного репозитория.
# Не запускает services и не применяет configs; подходит для local/CI проверки.
set -euo pipefail

# Абсолютный repo root делает результаты независимыми от текущей директории.
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo"
fail=0

# В курсе должно быть ровно по одному каталогу для номеров 01..19.
for number in $(seq -w 1 19); do
    if ! find labs -mindepth 1 -maxdepth 1 -type d -name "$number-*" -print -quit | grep -q .; then
        echo "ERROR: отсутствует каталог labs/$number-*" >&2
        fail=1
    fi
done

# Проверяем Bash syntax как обычных скриптов, так и копируемых templates.
while IFS= read -r file; do
    if ! bash -n "$file"; then
        echo "ERROR: bash syntax: $file" >&2
        fail=1
    fi
done < <(find . -type f \( -name '*.sh' -o -name '*.sh.template' \) -print | sort)

# Любой файл с shebang должен запускаться напрямую после clone, включая
# extensionless helpers и templates, которые студент копирует под новым именем.
while IFS= read -r file; do
    if [ ! -x "$file" ]; then
        echo "ERROR: нет executable bit у файла с shebang: $file" >&2
        fail=1
    fi
done < <(rg -l '^#!' labs lecture-examples scripts firewalld.sh iptables.sh | sort)

# ast.parse проверяет Python без создания __pycache__ в рабочем дереве.
if ! python3 -c 'import ast; ast.parse(open("labs/10-network-diagnostics/https-server.py", encoding="utf-8").read())'; then
    echo "ERROR: Python syntax" >&2
    fail=1
fi

# Учебный файл должен объяснять назначение и хотя бы один важный параметр.
# Проверяем минимум две отдельные строки комментариев во всех scripts/configs,
# включая расширения fragment/template и исполняемые файлы без расширения.
# Регулярное выражение учитывает Bash/Python/Nginx (#), INI/PHP-FPM (;),
# SQL (--), C/PHP block comments и Python docstrings.
comment_pattern='^[[:space:]]*(#|;|//|/\*|\*|--|""")'
commented_materials=(
    dhcpd.conf firewalld.sh httpd.conf iptables.sh nginx.conf
    openvpn-client1.conf openvpn.conf snort.conf squid.conf sshd_config
)
while IFS= read -r -d '' file; do
    commented_materials+=("$file")
done < <(
    find labs lecture-examples scripts -type f \
        ! -name '*.md' ! -name '*.html' -print0 | sort -z
)
for file in "${commented_materials[@]}"; do
    comment_count=$(rg -c "$comment_pattern" "$file" 2>/dev/null || true)
    if [ "${comment_count:-0}" -lt 2 ]; then
        echo "ERROR: недостаточно поясняющих комментариев: $file" >&2
        fail=1
    fi
done

# Private key/bundle/generated directory не должны попасть в Git index.
if git ls-files | grep -E '(^|/)(generated/|.*\.(key|p12|pfx|ovpn)$)' >/dev/null; then
    echo "ERROR: в Git отслеживается закрытый ключ/сгенерированный bundle" >&2
    fail=1
fi

# CRLF может ломать shebang и parser некоторых Unix-конфигов.
if rg -l $'\r$' --glob '!LICENSE' . >/dev/null; then
    echo "ERROR: найдены CRLF" >&2
    fail=1
fi

# Минимальный manifest защищает от случайного удаления ключевых материалов.
required=(
    README.md COMMANDS.md STAND.md
    labs/01-systemd/lpic103-demo.service
    labs/10-network-diagnostics/lpic103-tls.service
    labs/11-dhcp/dhcpd.conf.template
    labs/14-bind/db.example.test.template
    labs/16-wordpress/nginx-wordpress-rhel.conf
    labs/18-ssh-hardening/65-lpic103-mfa.conf
    labs/19-openvpn/server-lpic103.conf.template
    scripts/generate-lab-pki.sh
)
for file in "${required[@]}"; do
    [ -s "$file" ] || { echo "ERROR: отсутствует/пуст $file" >&2; fail=1; }
done

# Ненулевой status агрегируется, чтобы один запуск показал максимум проблем.
if [ "$fail" -ne 0 ]; then
    exit 1
fi
echo "OK: 19 лабораторных, syntax/modes, комментарии, обязательные файлы и секреты проверены"
