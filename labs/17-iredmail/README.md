# Лабораторная 17: диагностика iRedMail

iRedMail — установщик стека, а не отдельная служба. Не запускайте установщик
повторно. `diagnose-base.sh` проверяет зависимости и endpoints; `mail-flow.sh`
отправляет одно письмо через submission и коррелирует queue ID с журналом и INBOX.

Дополнительно проверьте внешний relay без аутентификации:

```bash
swaks --server mail.example.test --port 25 \
  --from outsider@external.test --to user@outside.test --quit-after RCPT
```

Ожидается 454/550/554 `Relay access denied`. Пути webmail и журналов определяйте
по post-install report конкретного snapshot, не предполагая их заранее.
