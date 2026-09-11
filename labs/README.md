# Все лабораторные: подготовка и полный разбор

В каждом каталоге README описывает пакеты, происхождение материалов/ключей,
установку полных файлов, различия ОС, приемку и откат. WALKTHROUGH содержит
все нумерованные шаги, команды и характерные выводы исходного руководства.
Всего **19 лабораторных и 499 шагов**. Сначала [общая подготовка](../PREPARATION.md).

| № | Подготовка и полные конфиги | Команды и вывод |
|---|---|---|
| 01 | [Создание systemd unit и безопасное изменение его конфигурации ](01-systemd/README.md) | [19 шагов](01-systemd/WALKTHROUGH.md) |
| 02 | [Контролируемая сборка iperf3 из исходного кода ](02-source-build/README.md) | [22 шагов](02-source-build/WALKTHROUGH.md) |
| 03 | [Ограничение ресурсов сервиса через systemd и cgroups ](03-cgroups/README.md) | [11 шагов](03-cgroups/WALKTHROUGH.md) |
| 04 | [Базовый запуск Cockpit и ограничение административного доступа ](04-cockpit/README.md) | [25 шагов](04-cockpit/WALKTHROUGH.md) |
| 05 | [Модуль ядра, conntrack и счетчик netfilter ](05-kernel-netfilter/README.md) | [18 шагов](05-kernel-netfilter/WALKTHROUGH.md) |
| 06 | [Каталоги сервиса, UNIX-права, ACL и специальные атрибуты ](06-filesystem-acl/README.md) | [33 шагов](06-filesystem-acl/WALKTHROUGH.md) |
| 07 | [RAID1 с hot spare, отказ диска и rebuild ](07-raid/README.md) | [19 шагов](07-raid/WALKTHROUGH.md) |
| 08 | [LVM для сервисных данных: расширение, snapshot и thin provisioning ](08-lvm/README.md) | [43 шагов](08-lvm/WALKTHROUGH.md) |
| 09 | [Миграция сервисных данных с коротким окном остановки ](09-migration/README.md) | [19 шагов](09-migration/WALKTHROUGH.md) |
| 10 | [Послойная диагностика недоступного сетевого сервиса ](10-network-diagnostics/README.md) | [21 шагов](10-network-diagnostics/WALKTHROUGH.md) |
| 11 | [DHCP: пул, reservation, classless route и проверка клиента ](11-dhcp/README.md) | [24 шагов](11-dhcp/WALKTHROUGH.md) |
| 12 | [Базовый файловый ресурс Samba с групповой моделью доступа ](12-samba/README.md) | [26 шагов](12-samba/WALKTHROUGH.md) |
| 13 | [NFSv4 export с root_squash и согласованными UID/GID ](13-nfs/README.md) | [24 шагов](13-nfs/WALKTHROUGH.md) |
| 14 | [Авторитетный BIND: прямая и обратная зона ](14-bind/README.md) | [22 шагов](14-bind/WALKTHROUGH.md) |
| 15 | [Forward proxy Squid: ACL, запрет домена и журнал запроса ](15-squid/README.md) | [16 шагов](15-squid/WALKTHROUGH.md) |
| 16 | [Nginx, PHP-FPM, MariaDB и WordPress ](16-wordpress/README.md) | [50 шагов](16-wordpress/WALKTHROUGH.md) |
| 17 | [Диагностика готового почтового комплекса iRedMail ](17-iredmail/README.md) | [32 шагов](17-iredmail/WALKTHROUGH.md) |
| 18 | [Защита SSH: сертификат, FIDO2 и TOTP ](18-ssh-hardening/README.md) | [40 шагов](18-ssh-hardening/WALKTHROUGH.md) |
| 19 | [OpenVPN 2.6: защищенный маршрут к лабораторной сети ](19-openvpn/README.md) | [35 шагов](19-openvpn/WALKTHROUGH.md) |

## Приоритет исправленных инструкций

Rocky 10 DHCP: **Kea**, а не dhcpd. README lab11 полностью заменяет ISC-серверные
шаги исходного упражнения; для Rocky9/Ubuntu24.04 отдельная ISC-ветка.

Samba: smb.conf устанавливается целиком. BIND: один named.conf со всеми зонами,
два полных zone-файла и локально созданный rndc.key. WordPress: полный
nginx.conf (отдельные HTTP/TLS), php-fpm.conf с pool и сгенерированные полные
SQL/wp-config.php. SSH: полные sshd_config для CA/MFA и полные PAM по ОС.

iRedMail: готовый комплект создается установщиком; README содержит точный
источник, выборы мастера, создание аккаунтов и экспорт всех реальных конфигов.
Архив с SQL-паролями/TLS-ключами хранится закрыто, Git содержит генератор
и инструкции, не общие для всех слушателей действующие private keys.

## Порядок использования

1. Выберите отдельную ВМ/роль и установите пакеты своей ОС по README.
2. Получите файлы из этого репозитория, архивы — по указанным официальным URL.
3. Создайте/получите только необходимые ключи согласно PREPARATION.
4. Скопируйте **полный** файл из выбранного варианта, замените адреса своей схемы.
5. Проверьте синтаксис штатной программой, примените и выполните проверки WALKTHROUGH.
6. Сохраните отчет: версии, effective config без секретов, positive/negative результат.

Шаблон .template может быть полным конфигом с параметрами стенда; это не
недостающий fragment. Значения X=10/Y=20/Z=30, enp0s8 и internal/public/external
в примерах не гарантируют совпадение с вашей ВМ. Проверяйте ip/nmcli/firewall-cmd.
Блоки вывода в WALKTHROUGH иллюстративны; их не вводят в shell.
