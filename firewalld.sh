#!/usr/bin/env bash
# Настраивает базовый хостовый firewall: HTTP/HTTPS доступны всем, а SSH —
# только узлам административной подсети. Скрипт меняет постоянную конфигурацию.
# Перед запуском задайте MANAGEMENT_CIDR и при необходимости FIREWALL_ZONE:
#   sudo MANAGEMENT_CIDR=10.20.30.0/24 FIREWALL_ZONE=public ./firewalld.sh
set -euo pipefail

# Значения по умолчанию безопасны для документации, но не для реальной сети.
management_cidr=${MANAGEMENT_CIDR:-192.0.2.0/24}
zone=${FIREWALL_ZONE:-public}

# Сначала убеждаемся, что daemon отвечает, и показываем привязку интерфейсов.
sudo firewall-cmd --state
sudo firewall-cmd --get-active-zones
# --permanent записывает настройки на диск; до reload текущий runtime не меняется.
sudo firewall-cmd --permanent --zone="$zone" --add-service=http
sudo firewall-cmd --permanent --zone="$zone" --add-service=https
# Общий service=ssh удаляется; остается адресное разрешение management subnet.
# Ошибка удаления игнорируется: отсутствие уже удаленного правила нормально.
sudo firewall-cmd --permanent --zone="$zone" --remove-service=ssh 2>/dev/null || true
# Rich rule ограничивает SSH IPv4-источником; для IPv6 добавьте отдельное правило.
sudo firewall-cmd --permanent --zone="$zone" \
    --add-rich-rule="rule family=\"ipv4\" source address=\"$management_cidr\" service name=\"ssh\" accept"
# Атомарно загружаем постоянные правила и печатаем итог для ручной проверки.
sudo firewall-cmd --reload
sudo firewall-cmd --zone="$zone" --list-all
