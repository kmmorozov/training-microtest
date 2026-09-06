#!/usr/bin/env bash
# Применяет минимальный IPv4 ruleset через iptables-restore одной транзакцией.
# ВНИМАНИЕ: неверная административная подсеть может оборвать удаленное соединение.
# Держите вторую консоль и запускайте, например:
#   sudo MANAGEMENT_CIDR=10.20.30.0/24 ./iptables.sh
set -euo pipefail

# iptables-save/restore требуют root; явная проверка дает понятную ошибку.
[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "Запустите через sudo" >&2; exit 1; }
# RFC 5737 subnet используется как безопасная документационная заглушка.
management_cidr=${MANAGEMENT_CIDR:-192.0.2.0/24}
# Временный файл удаляется trap даже при ошибке; текущие правила сохраняются в /root.
rules=$(mktemp)
backup="/root/iptables-lpic103-$(date +%Y%m%d-%H%M%S).rules"
trap 'rm -f "$rules"' EXIT

# iptables-restore заменяет таблицу целиком. Политики INPUT/FORWARD — DROP,
# OUTPUT — ACCEPT. Порядок правил существенен: первое совпадение завершает поиск.
cat >"$rules" <<RULES
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
# Loopback нужен локальным службам; уже установленные соединения не обрываются.
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# Новые SSH-соединения принимаются только из указанной административной сети.
-A INPUT -p tcp -s $management_cidr --dport 22 -m conntrack --ctstate NEW -j ACCEPT
# Веб-порты открыты всем источникам согласно сценарию учебного сервера.
-A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT
-A INPUT -p tcp --dport 443 -m conntrack --ctstate NEW -j ACCEPT
# ICMP echo и сообщения журнала ограничены, чтобы не создать flood логов/ответов.
-A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/second --limit-burst 2 -j ACCEPT
-A INPUT -m limit --limit 5/minute --limit-burst 10 -j LOG --log-prefix "lpic103 denied: "
COMMIT
RULES

# Синтаксическая проверка выполняется до создания резервной копии и применения.
iptables-restore --test <"$rules"
iptables-save >"$backup"
echo "Текущие правила сохранены: $backup"
# Явное подтверждение защищает от случайного запуска скрипта вставкой из лекции.
read -r -p 'Применить ruleset? Убедитесь, что резервная консоль открыта. Введите YES: ' answer
[ "$answer" = YES ] || exit 1
# После подтверждения заменяем правила и печатаем фактически загруженный ruleset.
iptables-restore <"$rules"
iptables -S
