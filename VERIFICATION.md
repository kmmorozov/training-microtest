# Проверки материалов

Дата: 11.09.2026. Синтаксические проверки не заменяют прохождение сетевых,
дисковых и аппаратных сценариев на ВМ. Образцы вывода в WALKTHROUGH не выдаются
за фактически записанные логи.

## Воспроизведение

```bash
./scripts/validate-materials.sh
# Только если установлен Podman; пакеты ставятся внутри одноразового контейнера:
podman run --rm -v "$PWD:/materials:ro" docker.io/rockylinux/rockylinux:10 \
  bash /materials/scripts/check-platform-configs.sh
podman run --rm -v "$PWD:/materials:ro" docker.io/library/ubuntu:24.04 \
  bash /materials/scripts/check-platform-configs.sh
```

В container test имя enp0s8 заменяется **в тестовой копии** на существующий NIC
контейнера: Kea -t требует его наличия. Адреса, reservation и option121
сохраняются. DHCP listener не запускается. Репозиторий подключен read-only,
новые ключи и generated configs создаются только внутри контейнера.

## Подтверждено

Rocky Linux 10.2: Kea **3.0.3**, BIND **9.18.33**, Nginx **1.26.3**,
PHP-FPM/CLI **8.3.33**, Samba **4.23.5**, OpenSSH **9.9p1** из пакетов этого
среза. Успешно завершились:

- kea-dhcp4 -t: полный config, memfile, reservation, HEX option121;
- testparm -s: global/share Samba;
- nginx -t: полные HTTP/TLS main configs WordPress;
- php-fpm -t и php -l сгенерированного wp-config.php;
- named-checkconf -z: полный main с rndc.key и обеими зонами;
- sshd -t: полные CA/MFA configs с существующими host keys;
- генерация TLS PKI и проверка цепочек пяти leaf certificates.

Полный прогон завершился строкой PASS и exit status 0.
Kea в проверенном Rocky10.2 пришел из **BaseOS**, EPEL не потребовался.
Типовые предупреждения Kea про multi-threading/queue control сами по себе
не означают отказ parser: проверяйте итоговый exit status.

## Границы проверки

Офлайн-проверка покрытия проверяет 19 README, все 499 шагов и порядок нумерации,
относительные Markdown-ссылки, Bash/Python-синтаксис, comments/executable bits,
отсутствие fragment-файлов и отслеживаемых секретов.

Контейнер не доказывает DORA между ВМ, firewalld/SELinux policy хоста,
фактический PAM/FIDO2/TOTP вход, RAID rebuild, LVM filesystem consistency,
полную доставку iRedMail и маршрутизацию VPN. Для них даны отдельные
positive/negative проверки, ожидаемый вывод и откат в README/WALKTHROUGH.
Закрытые почтовые конфиги и host-specific Webmin комплект генерируются на
целевом установленном стенде и не включаются в публичный Git.
