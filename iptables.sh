# Сброс всех существующих правил
iptables -F
iptables -X

# Политика по умолчанию: запретить все входящие и перенаправленные пакеты
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Разрешить трафик loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Разрешить установленные и связанные соединения
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Разрешить HTTP и HTTPS
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Разрешить SSH (если необходимо, измените порт)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Защита от SYN-флуда
iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 4 -j ACCEPT

# Защита от ping-флуда
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 1 -j ACCEPT

# Регистрация отброшенных пакетов
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables denied: "

# Сохранение правил 
iptables-save > /etc/sysconfig/iptables
