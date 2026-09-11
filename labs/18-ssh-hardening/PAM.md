# Полный PAM и SSH MFA

Канонический сценарий — [README](README.md), все 40 шагов —
[WALKTHROUGH](WALKTHROUGH.md).

Полные файлы /etc/pam.d/sshd: [Rocky](pam-sshd-rhel) и
[Debian/Ubuntu](pam-sshd-debian). Они включают auth/account/password/session;
вставлять отдельную строку в неизвестный auth stack не требуется.
Полные конфиги sshd: [этап CA](sshd_config-ca.conf),
[этап MFA](sshd_config-mfa.conf).

Прежде чем менять PAM, сделайте копию, сохраните консоль, проверьте модули
и совместимость policy выбранной ОС. sshd -t не валидирует PAM.
Положительный и отрицательный входы, создание TOTP и откат разобраны в README.
