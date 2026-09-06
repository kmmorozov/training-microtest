# Cockpit

Конфиг сохраняет TLS-only доступ и запрещает выбор другого destination на login
page. Само ограничение источника выполняется firewall из лабораторной 04.
Сертификат и private key устанавливаются одним PEM bundle в
`/etc/cockpit/ws-certs.d/` с именем, сортирующимся после package example; точный
формат и владелец сверяются с man page установленной версии Cockpit.

После изменения:

```bash
systemctl restart cockpit.socket
curl -kI https://127.0.0.1:9090
```

Затем установите доверие к CA и повторите тест без `-k`.
