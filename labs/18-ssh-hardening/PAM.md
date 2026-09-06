# PAM, TOTP и безопасное применение

Создайте резервный сеанс/консоль и копию PAM-файла mode 0600. Установите
`google-authenticator` (RHEL-like) или `libpam-google-authenticator` (Debian), затем
от имени целевого пользователя выполните:

```bash
google-authenticator -t -d -f -r 3 -R 30 -w 3
stat -c '%U:%G %a %n' ~/.google_authenticator
```

В **auth-секции** `/etc/pam.d/sshd` замените парольный `password-auth`/`common-auth`
на одну строку:

```text
auth required pam_google_authenticator.so
```

Account/session includes не удаляйте. Затем установите `65-lpic103-mfa.conf`,
выполните `sshd -t` и проверьте effective configuration через `sshd -T`. Reload
допустим только при открытом резервном сеансе. Сначала проверьте два новых входа,
и лишь затем применяйте `70-lpic103-hardening.conf`.

FIDO2-ключ создается на клиенте:

```bash
ssh-keygen -t ed25519-sk -O resident -O verify-required -f ~/.ssh/id_lpic103_sk
ssh-copy-id -i ~/.ssh/id_lpic103_sk.pub user@server
```

При отсутствии поддержки Ed25519-SK проверьте токен/OpenSSH и используйте
`ecdsa-sk`. TOTP secret и recovery codes не помещайте в репозиторий.
