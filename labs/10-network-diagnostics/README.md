# Лабораторная 10. Послойная диагностика HTTPS

Все 21 шага и разбор результата: [WALKTHROUGH.md](WALKTHROUGH.md).
[Подготовка/получение PKI](../../PREPARATION.md).
Сервер app.example.test = 192.168.10.10, клиент .100, DNS .53 (lab14).
```bash
# Rocky, обе ВМ:
sudo dnf install -y python3 openssl curl bind-utils nmap-ncat tcpdump
# Ubuntu/Debian:
sudo apt install -y python3 openssl curl dnsutils netcat-openbsd tcpdump
```

Преподаватель создает PKI режимом --tls-only и передает серверу ca.crt,
app.crt/app.key, клиенту **только** ca.crt по PREPARATION.
На получателях `PKI="$HOME/lpic103-materials/pki"`. Готовые полные файлы:
https-server.py, lpic103-tls.service, index.html — в этом каталоге.
```bash
# На сервере:
sudo ./labs/10-network-diagnostics/setup-server.sh "$PKI"
sudo firewall-cmd --permanent --zone=internal --add-port=8443/tcp
sudo firewall-cmd --reload
# internal замените фактической зоной lab NIC.
# На клиенте:
getent ahostsv4 app.example.test
curl --fail --cacert "$PKI/ca.crt" https://app.example.test:8443/
openssl s_client -connect app.example.test:8443 -servername app.example.test \
  -verify_hostname app.example.test -verify_return_error -CAfile "$PKI/ca.crt" </dev/null
```

До внесения дефекта ожидаются HTTP 200 и Verify return code 0.
Без BIND добавьте `192.168.10.10 app.example.test` в /etc/hosts клиента;
тогда этап dig проверяет отдельно DNS и ожидаемо требует поднятого lab14.

## Внесение одного воспроизводимого дефекта

**Зачем: Вносим один контролируемый дефект на учебной ВМ, чтобы научиться локализовать причину отказа и подтвердить восстановление после отката.**

На сервере запомните исходную firewall zone. Чтобы воспроизвести закрытый порт,
уберите только выданное в этой лабе правило 8443 из runtime:
`sudo firewall-cmd --zone=internal --remove-port=8443/tcp`.
Не меняйте одновременно DNS/сертификат/службу. Запишите, какой дефект внесен.
Слушатель выполняет WALKTHROUGH: link → address → route → DNS → TCP →
listener → firewall → TLS → HTTP. Для лабораторного timeout проверьте, что
нет другого правила, разрешающего 8443.

Исправление: `sudo firewall-cmd --zone=internal --add-port=8443/tcp`,
повторить curl/OpenSSL. В tcpdump до исправления видны попытки соединения,
после — двусторонний TCP/TLS. В `<CA-файл>` подставляйте "$PKI/ca.crt".
При самоподписанном сертификате не используйте -k как «исправление».
Откат endpoint: stop/disable lpic103-tls и убрать только правило 8443 этой лабы.
