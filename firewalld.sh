#!/bin/bash

# Установка зоны по умолчанию для общедоступных сетей
firewall-cmd --set-default-zone=public

# Разрешение основных сервисов для веб-сервера
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-service=ssh

# Ограничение доступа к SSH только с определенных IP-адресов (замените на свои)
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" service name="ssh" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.0.0.0/24" service name="ssh" accept'

# Блокировка всех других входящих подключений к SSH
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" service name="ssh" reject'

# Разрешение исходящих подключений (по умолчанию)
firewall-cmd --permanent --add-masquerade

# Перезагрузка Firewalld для применения изменений
firewall-cmd --reload

echo "Firewalld настроен для безопасного веб-сервера."
