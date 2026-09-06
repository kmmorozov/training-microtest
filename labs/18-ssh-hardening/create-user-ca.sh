#!/usr/bin/env bash
# Создает offline OpenSSH user CA; запускать на отдельном защищенном CA-host.
# На SSH server копируется только lpic103_user_ca.key.pub.
set -euo pipefail

# generated/ исключен из Git; пользователь может задать другой защищенный каталог.
out=${1:-"$(dirname "$0")/generated"}
install -d -m 0700 "$out"
[ ! -e "$out/lpic103_user_ca.key" ] || { echo "CA уже существует: $out" >&2; exit 1; }
# umask 077 защищает private key уже в момент создания.
umask 077
# Ed25519 дает компактный современный CA key без выбора RSA size.
ssh-keygen -t ed25519 -f "$out/lpic103_user_ca.key" -C lpic103-offline-user-ca
# Явные modes документируют границу private/public material.
chmod 0600 "$out/lpic103_user_ca.key"
chmod 0644 "$out/lpic103_user_ca.key.pub"
echo "Закрытый ключ CA остается на offline CA-host: $out/lpic103_user_ca.key"
