# Лабораторная 15. Forward proxy Squid

Все 16 шагов с выводами: [WALKTHROUGH.md](WALKTHROUGH.md).
[Общая подготовка](../../PREPARATION.md).
Squid 192.168.10.40, клиент .100, web endpoint .10.
Полный squid.conf.template содержит port ACL, CONNECT, allow/deny, logging.
```bash
# Rocky:
sudo dnf install -y squid curl
# Debian/Ubuntu:
sudo apt install -y squid curl
install -d -m 0700 generated/lab15
sed 's/192.168.X/192.168.10/g' labs/15-squid/squid.conf.template > generated/lab15/squid.conf
sudo cp -a /etc/squid/squid.conf /etc/squid/squid.conf.before-lpic103
sudo install -m 0644 generated/lab15/squid.conf /etc/squid/squid.conf
sudo squid -k parse
sudo systemctl enable --now squid
sudo systemctl restart squid
sudo firewall-cmd --permanent --zone=internal --add-port=3128/tcp
sudo firewall-cmd --reload
```

Замените internal реальной lab zone. Имена allowed.example.test и
blocked.example.test должны разрешаться **на proxy**, а не только на клиенте:
A .10 уже есть в зоне lab14, либо добавьте оба имени в /etc/hosts proxy.
На отдельной .10 для двух URL подготовьте настоящий HTTP endpoint:
```bash
sudo install -d -m 0755 /srv/lpic103-proxy-web
printf 'LPIC103 proxy origin OK\n' | sudo tee /srv/lpic103-proxy-web/index.html
sudo systemd-run --unit=lpic103-proxy-origin \
  /usr/bin/python3 -m http.server 80 --bind 192.168.10.10 --directory /srv/lpic103-proxy-web
sudo firewall-cmd --permanent --zone=internal --add-service=http
sudo firewall-cmd --reload
# Клиент:
curl --noproxy '' -sS -o /dev/null -w '%{http_code}\n' \
  -x http://192.168.10.40:3128 http://allowed.example.test/
curl --noproxy '' -sS -o /dev/null -w '%{http_code}\n' \
  -x http://192.168.10.40:3128 http://blocked.example.test/
```

Если на .10 уже работает Nginx/Apache на 80, используйте его, не запускайте
второй listener. NO_PROXY может обходить proxy, поэтому в проверках он сброшен.
Ожидаются 200 и 403. В access.log ищите адрес клиента, URL, TCP_MISS/200 и
TCP_DENIED/403. 503 для allowed означает проблему DNS/origin, а не успех ACL.
Ключей нет: это явный forward proxy без SSL bump.
Откат: исходный squid.conf, squid -k parse, restart; stop временного origin.
