# iptables

Raw iptables — альтернатива firewalld/UFW, а не дополнительный слой ручного
редактирования того же ruleset. На современной системе сначала определите backend:

```bash
iptables --version
sudo iptables -S
sudo nft list ruleset
```

Скрипт `iptables.sh` строит ruleset во временном файле, проверяет его через
`iptables-restore --test`, сохраняет текущие правила и требует явного `YES`.
До применения оставьте резервную консоль. Постоянное сохранение зависит от ОС
(`iptables-services`, `netfilter-persistent` и т. п.) и выполняется только после
позитивного и негативного клиентских тестов.
