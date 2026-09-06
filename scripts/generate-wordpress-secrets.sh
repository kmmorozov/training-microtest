#!/usr/bin/env bash
# Печатает восемь независимых WordPress key/salt definitions в stdout.
# Вывод является секретом: перенаправляйте только в временный файл mode 0600.
set -euo pipefail

command -v openssl >/dev/null || { echo "Требуется openssl" >&2; exit 1; }
# Каждый вызов openssl создает 48 random bytes; base64 не содержит одинарной кавычки
# и безопасно помещается в показанный PHP single-quoted literal.
for name in AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY \
    AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT; do
    value=$(openssl rand -base64 48 | tr -d '\n')
    # Имена соответствуют восьми constants стандартного wp-config.php.
    printf "define('%s', '%s');\n" "$name" "$value"
done

# Предупреждение идет в stderr и не загрязняет перенаправленный PHP fragment.
echo "# Сохраните вывод в файл mode 0600 и удалите после установки wp-config.php." >&2
