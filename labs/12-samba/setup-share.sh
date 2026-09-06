#!/usr/bin/env bash
# Готовит UNIX identities, каталог и SELinux context для Samba share [team].
# Samba passwords и smb.conf применяются отдельно после проверки testparm.
set -euo pipefail

# Операции user/group, /srv и SELinux требуют root.
[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "Запустите через sudo" >&2; exit 1; }
# Alice входит в разрешенную группу, Bob намеренно остается вне нее для deny test.
groupadd -f lpic103-smb
getent passwd lpic103-alice >/dev/null || useradd -M -s /usr/sbin/nologin -G lpic103-smb lpic103-alice
getent passwd lpic103-bob >/dev/null || useradd -M -s /usr/sbin/nologin lpic103-bob
usermod -aG lpic103-smb lpic103-alice
# setgid каталог наследует project group; others не имеют доступа.
install -d -o root -g lpic103-smb -m 2770 /srv/samba/lpic103-team

# При enforcing SELinux постоянное fcontext правило важнее временного chcon.
if command -v getenforce >/dev/null && [ "$(getenforce)" = Enforcing ]; then
    # -a создает правило, -m обновляет его при повторной подготовке стенда.
    semanage fcontext -a -t samba_share_t '/srv/samba/lpic103-team(/.*)?' 2>/dev/null ||
        semanage fcontext -m -t samba_share_t '/srv/samba/lpic103-team(/.*)?'
    restorecon -Rv /srv/samba/lpic103-team
fi

# Пароли запрашиваются интерактивно и не попадают в argv/history этого скрипта.
echo "Добавьте smb.conf.fragment в /etc/samba/smb.conf и выполните testparm -s."
echo "Затем создайте отдельные Samba-пароли: smbpasswd -a lpic103-alice; smbpasswd -a lpic103-bob"
