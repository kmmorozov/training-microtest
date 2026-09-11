# Общая подготовка: ОС, репозиторий, пакеты, архивы и ключи

Основной стенд: Rocky Linux 10, альтернативный — Ubuntu Server 24.04 LTS.
Debian 12/13 допустим с выбором фактической версии PHP/Dovecot. Не переносите
RPM, PAM-файлы и имена служб между дистрибутивами.

## Репозиторий и рабочий каталог

ISO: [Rocky downloads](https://rockylinux.org/download), [Ubuntu Server](https://ubuntu.com/download/server).
Для Rocky 10 учитывайте требования CPU выбранного образа. Создайте ВМ 2 vCPU,
2–4 GiB RAM (почта 4–8 GiB), 20 GiB диска; storage-лабы требуют дополнительных
дисков. Сделайте snapshot чистой системы.

```bash
# Rocky:
sudo dnf install -y git curl ca-certificates openssl python3 nano tar unzip
# Ubuntu/Debian — отдельная ветка:
sudo apt update
sudo apt install -y git curl ca-certificates openssl python3 nano tar unzip
# Одинаково после установки git:
git clone https://github.com/kmmorozov/training-microtest.git
cd training-microtest
export REPO="$PWD"
install -d -m 0700 generated
git log -1 --oneline
```

Если изменения преподавателя еще не опубликованы, получите целиком его рабочую
копию репозитория (SCP/архив) и перейдите в нее. `REPO` всегда указывает именно
на корень этой копии. После открытия нового терминала повторите
`cd .../training-microtest; export REPO="$PWD"`.
Ниже и в README лабораторных команды даны **от корня репозитория**.
В WALKTHROUGH явно встречаются переходы в другие каталоги: перед копированием
файлов из `labs/` вернитесь `cd "$REPO"`.

## Подписи пакетов и EPEL

Rocky: штатные BaseOS/AppStream/Extras, ключи устанавливает пакет `rocky-gpg-keys`.
Ключи из случайного форума и `--nogpgcheck` не нужны.

```bash
cat /etc/os-release
uname -m
# Rocky:
rpm -q rocky-release rocky-repos rocky-gpg-keys
dnf repolist --enabled
ls /etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-*
# Только если лабораторная требует EPEL (stress-ng, OpenVPN, TOTP, swaks):
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --set-enabled crb
sudo dnf install -y epel-release
sudo dnf makecache --refresh
dnf repolist --enabled
# Ubuntu/Debian: подписи APT обрабатываются пакетами archive-keyring.
apt-cache policy
```

Ключ EPEL устанавливается `epel-release` из доверенного репозитория:
не отключайте проверку подписей. На Ubuntu пакет из Universe можно включить
через `sudo add-apt-repository universe` (пакет software-properties-common).
На Debian не добавляйте Ubuntu Universe.
Источник: [официальная установка EPEL](https://docs.fedoraproject.org/en-US/epel/getting-started/).

Фиксируйте версию до работы: `rpm -q ИМЯ` или `dpkg-query -W ИМЯ`.
При `No match`/нет candidate: сначала проверяйте релиз, репозиторий и DNS.
Kea на Rocky 10 берется из штатных BaseOS/AppStream и не требует EPEL.
Проверенный пакет Rocky 10.2 поставляется BaseOS; dnf info kea покажет ваш Repo.

## Адреса, DNS, время и firewall

Полная карта — [STAND.md](STAND.md). По умолчанию X=10, Y=20, Z=30.
Management/NAT используется только для SSH и скачивания; учебные L2 — отдельные
internal switches. DHCP гипервизора в lab 11 выключен. Не назначайте один
статический IP двум одновременно работающим ВМ.

```bash
ip -br link
ip -br address
ip route
nmcli -f NAME,DEVICE connection show
timedatectl
# Укажите реальную зону lab NIC в командах каждой лабораторной.
sudo firewall-cmd --get-active-zones
```

В канонических README по умолчанию используется firewalld на обеих ОС.
На чистой Rocky ВМ: `sudo dnf install -y firewalld`; на чистой
Debian/Ubuntu: `sudo apt install -y firewalld`, затем
`sudo systemctl enable --now firewalld`. Перед включением сохраните
консоль и SSH service в management zone. Если уже активен UFW, используйте
его альтернативную ветку в WALKTHROUGH и не запускайте второй firewall.
Зону lab NIC можно назначить `sudo firewall-cmd --permanent --zone=internal
--change-interface=enp0s8`, затем reload; в NetworkManager сохраните
connection.zone=internal в профиле. Начальный SSH вход должен оставаться
доступен на отдельном management NIC.

Имена, пакеты и time sync нужны **до** потери DNS/default route. Сертификаты
проверяют часы: настройте chronyd (Rocky: `dnf install chrony;
systemctl enable --now chronyd`) или systemd-timesyncd Ubuntu.
В лабах без DNS можно добавить в /etc/hosts полные строки из STAND.md через
`sudoedit /etc/hosts`. Это дополнение к host-specific файлу, не замена localhost.

## Учебная X.509 PKI: откуда берутся CA, ключи и сертификаты

На отдельной CA-ВМ клонируйте репозиторий и установите OpenSSL.
Для полного набора VPN понадобится также OpenVPN (Rocky: EPEL + `dnf install
openvpn`; Debian/Ubuntu: `apt install openvpn`).
Для TLS lab 10/16 достаточно режима `--tls-only`.

```bash
# CA-ВМ; каталог должен быть новым/пустым. Второй раз в тот же каталог не запускать.
./scripts/generate-lab-pki.sh --tls-only "$REPO/generated/pki"
# Альтернатива для lab 19: полный набор в новом каталоге.
./scripts/generate-lab-pki.sh "$REPO/generated/vpn-pki"
openssl x509 -in generated/pki/ca.crt -noout -subject -fingerprint -sha256
openssl verify -CAfile generated/pki/ca.crt generated/pki/app.crt
openssl x509 -in generated/pki/app.crt -noout -subject -dates -ext subjectAltName
```

Обе команды генерации — **альтернативы** для разных комплектов, не обязательные
два шага. Генератор создает CA и отдельные пары app, wp, mail, server, client.
CA.key остается на CA-ВМ; никакие закрытые ключи из Интернета не скачиваются.

| Получатель | Передать | Права после установки |
|---|---|---|
| TLS сервер lab 10 | ca.crt, app.crt, app.key | key root:lpic103-tls 0640 |
| WordPress lab 16 | ca.crt, wp.crt, wp.key | key root 0600 |
| Почта | ca.crt, mail.crt, mail.key | по unit/group TLS-службы |
| VPN сервер | ca.crt, server.crt, server.key, tls-crypt.key | keys root 0600 |
| VPN клиент | ca.crt, client.crt, client.key, tls-crypt.key | keys root 0600 |
| Клиенты curl/OpenSSL | только ca.crt | публичный 0644 |
| Никто кроме CA-ВМ | ca.key | 0600, каталог 0700 |

Пример передачи lab 10 с CA-ВМ (labadmin — существующий sudo-пользователь):

```bash
ssh labadmin@192.168.10.10 'install -d -m 0700 ~/lpic103-materials/pki'
scp generated/pki/ca.crt generated/pki/app.crt generated/pki/app.key \
  labadmin@192.168.10.10:~/lpic103-materials/pki/
# Клиент получает только доверенный сертификат:
ssh labadmin@192.168.10.100 'install -d -m 0700 ~/lpic103-materials/pki'
scp generated/pki/ca.crt labadmin@192.168.10.100:~/lpic103-materials/pki/
```

Сверьте SSH host fingerprint через консоль ВМ перед первой передачей. На получателе
задайте `export PKI="$HOME/lpic103-materials/pki"`. В заданиях
`<CA-файл>` = `$PKI/ca.crt`; его можно использовать прямо с `--cacert`.
Системное доверие, если необходимо: Rocky — копия CA в
/etc/pki/ca-trust/source/anchors/ и `update-ca-trust`;
Debian/Ubuntu — /usr/local/share/ca-certificates/lpic103.crt и
`update-ca-certificates`. Не устанавливайте leaf как корневой CA.

OpenSSH CA отличается от X.509 CA. Его создание, передача .pub и подпись
пользовательского ключа описаны отдельно в [lab 18](labs/18-ssh-hardening/README.md).
TOTP создается каждым пользователем локально; FIDO2 требует физического токена.

## Архивы и отсутствие Интернета на стенде

[Lab 02](labs/02-source-build/README.md) содержит точные HTTPS URL iperf и
официального SHA256. [Lab 16](labs/16-wordpress/README.md) — URL WordPress и
создание манифеста выдаваемого комплекта. Не используйте слово latest в
именах сохраненных артефактов: фиксируйте версию и сумму.

Без Интернета преподаватель скачивает архивы на доверенной машине и передает
их с SHA256SUMS по SCP/носителю. Самостоятельно вычисленная сумма доказывает
неизменность последующих копий, но **не** аутентичность первоначальной загрузки.

Пакеты офлайн берутся из ISO/внутреннего зеркала той же версии ОС. Для Rocky
на машине с теми же репозиториями: `dnf download --resolve --alldeps
--destdir ./rpms ИМЯ` (dnf-plugins-core), затем `dnf install ./rpms/*.rpm`.
Передавайте все зависимости и штатные ключи. Простое копирование одного RPM
обычно недостаточно. Для APT используйте полное локальное зеркало/ISO:
пакеты из кэша другой версии Ubuntu/Debian не подходят.

## Полные конфиги и порядок установки

Файлы называются как целые конфиги и устанавливаются целиком; полный
`nginx.conf` содержит events/http/server, полный BIND — options/controls/zones,
полный PHP-FPM — global/pool, Samba — global/share. У systemd drop-in,
sysctl.d, exports.d самостоятельная единица конфигурации по дизайну мала —
она приведена целиком вместе с основным unit/порядком установки.

Перед изменением сохраните пакетный файл: `sudo cp -a FILE FILE.before-lpic103`.
Затем install/tee полного файла → штатный syntax check → reload/restart →
positive/negative проверки из WALKTHROUGH. Для отката восстановите именно свою
копию, проверьте синтаксис и перезапустите службу. Секреты и runtime-файлы
живут в generated/ или вне Git, а не в учебных конфигурациях.
