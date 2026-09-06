# Самостоятельные примеры лекций

Эти файлы дополняют лабораторные артефакты:

- `system/` — постоянные sysctl-параметры;
- `nginx/` — virtual host, reverse proxy и TLS;
- `apache/` — platform-specific VirtualHost;
- `nfs/` — сетевой automount в fstab;
- `postfix/` — минимальная relay policy;
- `dovecot/` — различающийся синтаксис веток 2.3 и 2.4.
- `tls/` — OpenSSL CSR с SAN/EKU;
- `cockpit/` и `webmin/` — локальные настройки management endpoints.

Фрагменты не заменяют package main config. До reload выполните штатную проверку
и сопоставьте пути, unit и major version со своей ОС. Сертификаты создаются
`scripts/generate-lab-pki.sh`; private keys в Git не хранятся.
