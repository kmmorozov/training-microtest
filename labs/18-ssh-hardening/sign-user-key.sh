#!/usr/bin/env bash
# Подписывает только переданный user PUBLIC key короткоживущим offline CA.
# Private user key и private CA key не должны покидать свои доверенные hosts.
set -euo pipefail

# CA private key, principal (UNIX login), public key пользователя.
[ "$#" -eq 3 ] || {
    echo "Использование: $0 /offline/lpic103_user_ca.key user /path/id_ed25519.pub" >&2; exit 2;
}
ca=$(realpath "$1")
principal=$2
public_key=$(realpath "$3")
# Ограничиваем principal безопасным набором символов имени учетной записи.
case "$principal" in ''|*[!a-zA-Z0-9._-]*) echo "Некорректный principal" >&2; exit 2;; esac
[ -f "$ca" ] && [ -f "$public_key" ] || { echo "Ключ не найден" >&2; exit 1; }
# Identity попадает в audit; validity допускает 5 min clock skew и живет 60 min.
ssh-keygen -s "$ca" -I "lpic103-$principal-$(date +%Y%m%d)" \
    -n "$principal" -V -5m:+60m "$public_key"
# Сразу показываем type, validity, principals и extensions выданного сертификата.
ssh-keygen -L -f "${public_key%.pub}-cert.pub"
