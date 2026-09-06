#!/usr/bin/env python3
"""Минимальный учебный HTTPS endpoint для послойной диагностики lab 10.

Сервер намеренно не является production web server: он обслуживает статические
файлы из WorkingDirectory systemd unit и слушает TCP/8443 на всех интерфейсах.
"""
import http.server
import ssl

# 0.0.0.0 дает возможность проверять firewall и удаленный клиентский путь.
address = ("0.0.0.0", 8443)
server = http.server.ThreadingHTTPServer(address, http.server.SimpleHTTPRequestHandler)
# PROTOCOL_TLS_SERVER выбирает только серверную роль; минимум TLS 1.2 запрещает
# устаревшие SSLv3/TLS 1.0/1.1.
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.minimum_version = ssl.TLSVersion.TLSv1_2
context.load_cert_chain("/etc/lpic103-tls/server.crt", "/etc/lpic103-tls/server.key")
# Оборачиваем listener до serve_forever, поэтому plain HTTP на 8443 не принимается.
server.socket = context.wrap_socket(server.socket, server_side=True)
server.serve_forever()
