# firewalld

Firewalld хранит runtime и permanent policy. Сначала проверьте активную zone,
добавьте runtime-правило и выполните клиентский тест; затем создайте эквивалентное
`--permanent` правило, reload и повторите тест.

```bash
firewall-cmd --state
firewall-cmd --get-active-zones
firewall-cmd --zone=public --list-all
sudo firewall-cmd --zone=public --add-service=https
sudo firewall-cmd --permanent --zone=public --add-service=https
sudo firewall-cmd --reload
firewall-cmd --zone=public --list-all
```

Административные сервисы ограничивайте source-zone или rich rule. Не используйте
`--runtime-to-permanent` вслепую: команда сохраняет все runtime-изменения.
Практические шаблоны находятся в лабораторных 04 и 19, расширенный разбор — в
`COMMANDS.md`.
