# Лабораторная 18. SSH CA, FIDO2 и TOTP с полными конфигами

Все 40 шагов и результаты: [WALKTHROUGH.md](WALKTHROUGH.md).
[Общая подготовка](../../PREPARATION.md).
Три роли: SSH-сервер .10, клиент .100, отдельный CA-host. В примере UNIX login
labadmin существует на сервере, у него есть sudo и рабочий вход по обычному ключу.

## 1. Пакеты и резервный вход

**Зачем: Устанавливаем необходимые компоненты и сохраняем резервный вход, чтобы ошибка настройки SSH или PAM не заблокировала администрирование.**

```bash
# Rocky сервер/клиент:
sudo dnf install -y openssh-server openssh-clients
# Сервер TOTP — после EPEL:
sudo dnf install -y google-authenticator
# Debian/Ubuntu:
sudo apt install -y openssh-server openssh-client libpam-google-authenticator
ssh -V
# Сервер:
sudo ssh-keygen -A
sudo cp -a /etc/ssh/sshd_config /etc/ssh/sshd_config.before-lpic103
sudo cp -a /etc/pam.d/sshd /etc/pam.d/sshd.before-lpic103
sudo groupadd -f ssh-users
sudo usermod -aG ssh-users labadmin
sudo sshd -t
```

Держите консоль ВМ и текущую SSH-сессию. Host keys создаются на сервере,
user key — на клиенте, SSH CA key — на CA-host; X.509 ca.key из TLS не подходит.
Unit: sshd на Rocky, ssh на Debian/Ubuntu. При socket activation Ubuntu
учитывайте ssh.socket; порт остается22, дополнительных действий не требуется.

## 2. Создание CA и подпись пользовательского ключа

**Зачем: Разделяем доверенный CA и пользовательский ключ, чтобы разрешать ограниченный по имени и сроку сертификатный вход без передачи закрытых ключей.**

```bash
# CA-host: новый каталог, задайте passphrase CA.
./labs/18-ssh-hardening/create-user-ca.sh "$REPO/generated/ssh-ca"
# Клиент: задайте passphrase пользовательского ключа.
ssh-keygen -t ed25519 -f ~/.ssh/id_lpic103_cert -C lpic103-cert
# Передать CA-host только PUBLIC key (caadmin и адрес замените своими):
scp ~/.ssh/id_lpic103_cert.pub caadmin@192.168.10.200:~/id_lpic103_cert.pub
# CA-host: подписать на 60 минут для principal labadmin:
./labs/18-ssh-hardening/sign-user-key.sh \
  generated/ssh-ca/lpic103_user_ca.key labadmin ~/id_lpic103_cert.pub
# Вернуть сертификат клиенту:
scp ~/id_lpic103_cert-cert.pub labadmin@192.168.10.100:~/.ssh/
# На сервер передать только public CA:
scp generated/ssh-ca/lpic103_user_ca.key.pub \
  labadmin@192.168.10.10:~/lpic103_user_ca.pub
```

При offline CA вместо SCP используйте носитель для двух **публичных** файлов.
Private CA остается на CA-host; private user key не передается.
`ssh-keygen -L -f ~/.ssh/id_lpic103_cert-cert.pub` показывает principal,
key ID, validity и CA fingerprint. Сверьте часы: сертификат живет один час.

```bash
# Сервер: полный конфиг первого этапа, не drop-in.
sudo install -m 0644 ~/lpic103_user_ca.pub /etc/ssh/lpic103_user_ca.pub
sudo install -m 0600 labs/18-ssh-hardening/sshd_config-ca.conf /etc/ssh/sshd_config
sudo sshd -t
sudo sshd -T | grep -E 'trusteduserca|authenticationmethods|allowgroups'
sudo systemctl reload sshd
# Debian/Ubuntu вместо sshd: sudo systemctl reload ssh
# Клиент:
ssh -i ~/.ssh/id_lpic103_cert \
  -o CertificateFile=~/.ssh/id_lpic103_cert-cert.pub labadmin@192.168.10.10 id
```

В полных sshd_config нет Include: старые conflicting drop-ins не активны.
На нестандартной ВМ сопоставьте host key paths с `ls /etc/ssh/ssh_host_*_key`.

## 3. FIDO2

**Зачем: Настраиваем аппаратный ключ и проверяем отдельный вход, чтобы подтвердить работу FIDO2 до включения второго фактора.**

Нужен физический FIDO2-токен с поддержкой выбранного алгоритма и доступом
USB/HID на клиенте. Токен не заменяется скачанным ключом. При SSH с ВМ
настройте USB passthrough. Клиент запросит PIN/касание.
```bash
ssh-keygen -t ed25519-sk -O resident -O verify-required \
  -f ~/.ssh/id_lpic103_sk -C lpic103-fido2
ssh-copy-id -i ~/.ssh/id_lpic103_sk.pub labadmin@192.168.10.10
ssh -i ~/.ssh/id_lpic103_sk -o IdentitiesOnly=yes labadmin@192.168.10.10 id
```

Для токена без Ed25519-SK используйте ecdsa-sk. Если токена нет, этап нельзя
считать выполненным; обычный Ed25519 проверяет другую модель. При server
keys-only ssh-copy-id использует ранее рабочий ключ/agent или передайте .pub
через существующую сессию в ~/.ssh/authorized_keys (mode600, каталог700).

## 4. TOTP и полный PAM

**Зачем: Подключаем TOTP через полный PAM-конфиг и задаем обязательную последовательность факторов, чтобы одного ключа было недостаточно для входа.**

На сервере **в сеансе labadmin**, не root:
```bash
google-authenticator -t -d -f -r 3 -R 30 -w 3
stat -c '%U:%G %a %n' ~/.google_authenticator
timedatectl
```

Сканируйте QR локальным TOTP приложением на телефоне; recovery codes
сохраните закрыто. Не делайте screenshot для отчета.
Точный токен/секрет уникален, файл принадлежит labadmin с mode600.

```bash
# Сервер Rocky:
sudo install -m 0644 labs/18-ssh-hardening/pam-sshd-rhel /etc/pam.d/sshd
# Debian/Ubuntu вместо этого:
sudo install -m 0644 labs/18-ssh-hardening/pam-sshd-debian /etc/pam.d/sshd
# Полный MFA-конфиг для обеих ОС:
sudo install -m 0600 labs/18-ssh-hardening/sshd_config-mfa.conf /etc/ssh/sshd_config
sudo sshd -t
sudo sshd -T | grep -E 'usepam|kbdinteractive|authenticationmethods|allowgroups'
sudo systemctl reload sshd
# Debian/Ubuntu: sudo systemctl reload ssh
```

PAM файлы приведены целиком, с account/session policy ОС.
`sshd -t` **не проверяет PAM-стек**, поэтому сначала сравните его со своей
копией и убедитесь, что все упомянутые pam_*.so и includes существуют.
На Rocky custom authselect-профиль может иметь дополнительные требования:
сохраняйте его account/session политику. Системный common-auth/password-auth
не заменяйте глобально: здесь меняется только /etc/pam.d/sshd.

## 5. Проверки и откат

**Зачем: Проверяем разрешенные и запрещенные способы входа и готовим откат через резервную сессию, чтобы подтвердить защиту без потери управления.**

В новом клиентском терминале:
```bash
ssh -i ~/.ssh/id_lpic103_cert -o IdentitiesOnly=yes \
  -o CertificateFile=~/.ssh/id_lpic103_cert-cert.pub \
  -o PreferredAuthentications=publickey,keyboard-interactive labadmin@192.168.10.10 id
ssh -i ~/.ssh/id_lpic103_sk -o IdentitiesOnly=yes labadmin@192.168.10.10 id
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no labadmin@192.168.10.10 true
ssh -o BatchMode=yes root@192.168.10.10 true
```

Первые два требуют верный TOTP; неверный код дает отказ. Последние две команды
также должны отказать. Проверьте журнал выбранного unit. Не закрывайте старую
сессию до всех проверок. TOTP повторно использовать нельзя при -d: дождитесь
нового кода для второго успешного входа.

Откат из сохраненной консоли:
```bash
sudo cp -a /etc/ssh/sshd_config.before-lpic103 /etc/ssh/sshd_config
sudo cp -a /etc/pam.d/sshd.before-lpic103 /etc/pam.d/sshd
sudo sshd -t
sudo systemctl reload sshd
# Debian/Ubuntu — reload ssh.
```
