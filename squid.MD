# Squid

Канонический конфиг лабораторной 15: `labs/15-squid/squid.conf.template`.

`http_access` проверяется сверху вниз до первого совпадения. Поэтому защитные
ограничения и `deny blocked` должны находиться **до** `allow labnet`, а последним
правилом остается `deny all`. Проверка и применение:

```bash
sudo squid -k parse
sudo squid -k reconfigure
sudo ss -lntp 'sport = :3128'
curl -x http://proxy:3128 http://allowed.example.test/
tail -n 20 /var/log/squid/access.log
```

Не публикуйте open proxy. Обычный HTTPS CONNECT не означает расшифровку TLS.
