**1. Что такое firewalld?**

Firewalld — это динамический менеджер брандмауэра с поддержкой сетевых зон. Он предоставляет динамически управляемый брандмауэр с поддержкой сетевых зон и позволяет определять уровень доверия для сетевых подключений.

**2. Основные понятия**

* **Зоны**: firewalld использует зоны для управления правилами. Зоны — это наборы правил, определяющие, какой трафик разрешен в зависимости от уровня доверия сети.
* **Сервисы**: Сервисы — это предопределенные правила для конкретных служб, таких как HTTP, SSH и т. д.
* **Порты**: Порты — это конкретные номера портов, которые можно открыть или закрыть.
* **Богатые правила (Rich Rules)**: Богатые правила позволяют создавать более сложные правила с использованием различных критериев.

**3. Основные команды firewall-cmd**

* **Проверка статуса firewalld**:

```bash
sudo systemctl status firewalld
```

* **Перезагрузка firewalld**:

```bash
sudo firewall-cmd --reload
```

* **Получение списка зон**:

```bash
sudo firewall-cmd --get-zones
```

* **Получение активной зоны**:

```bash
sudo firewall-cmd --get-active-zones
```

* **Получение зоны по умолчанию**:

```bash
sudo firewall-cmd --get-default-zone
```

* **Установка зоны по умолчанию**:

```bash
sudo firewall-cmd --set-default-zone=<зона>
```

* **Добавление сервиса в зону**:

```bash
sudo firewall-cmd --zone=<зона> --add-service=<сервис>
```

* **Удаление сервиса из зоны**:

```bash
sudo firewall-cmd --zone=<зона> --remove-service=<сервис>
```

* **Добавление порта в зону**:

```bash
sudo firewall-cmd --zone=<зона> --add-port=<порт>/<протокол>
```

* **Удаление порта из зоны**:

```bash
sudo firewall-cmd --zone=<зона> --remove-port=<порт>/<протокол>
```

* **Добавление богатого правила**:

```bash
sudo firewall-cmd --zone=<зона> --add-rich-rule='<правило>'
```

* **Удаление богатого правила**:

```bash
sudo firewall-cmd --zone=<зона> --remove-rich-rule='<правило>'
```

* **Список всех правил в зоне**:

```bash
sudo firewall-cmd --zone=<зона> --list-all
```

* **Список всех открытых портов в зоне**:

```bash
sudo firewall-cmd --zone=<зона> --list-ports
```

* **Список всех сервисов доступных в firewalld**:

```bash
sudo firewall-cmd --get-services
```

* **Постоянные правила**: Чтобы правила сохранялись после перезагрузки, используйте опцию `--permanent`. Например:

```bash
sudo firewall-cmd --permanent --zone=public --add-service=http
```

**4. Примеры использования**

* **Разрешить трафик HTTP в зоне public**:

```bash
sudo firewall-cmd --zone=public --add-service=http --permanent
sudo firewall-cmd --reload
```

* **Разрешить трафик SSH в зоне public**:

```bash
sudo firewall-cmd --zone=public --add-service=ssh --permanent
sudo firewall-cmd --reload
```

* **Открыть порт 8080 для TCP в зоне public**:

```bash
sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent
sudo firewall-cmd --reload
```

* **Заблокировать трафик с определенного IP-адреса**:

```bash
sudo firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="192.168.1.100" reject' --permanent
sudo firewall-cmd --reload
```

* **Разрешить трафик с определенного IP-адреса на порт 22**:

```bash
sudo firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="192.168.1.100" port port="22" protocol="tcp" accept' --permanent
sudo firewall-cmd --reload
```

**5. Работа с зонами**

* **Список доступных зон**:

```bash
sudo firewall-cmd --get-zones
```

* **Список активных зон**:

```bash
sudo firewall-cmd --get-active-zones
```

* **Установка зоны по умолчанию**:

```bash
sudo firewall-cmd --set-default-zone=public --permanent
```

**6. Сервисы**

* **Список доступных сервисов**:

```bash
sudo firewall-cmd --get-services
```

* **Добавление сервиса в зону**:

```bash
sudo firewall-cmd --zone=public --add-service=http --permanent
sudo firewall-cmd --reload
```

**7. Богатые правила (Rich Rules)**

* Богатые правила позволяют создавать более сложные правила с использованием различных критериев, таких как IP-адреса, порты, протоколы и т. д.
* Пример: Разрешить трафик с IP-адреса 192.168.1.100 на порт 22:

```bash
sudo firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="192.168.1.100" port port="22" protocol="tcp" accept' --permanent
sudo firewall-cmd --reload
```

**8. Постоянные и временные правила**

* По умолчанию firewalld применяет временные правила, которые теряются после перезагрузки.
* Чтобы сделать правило постоянным, используйте опцию `--permanent`.
* После добавления или изменения постоянных правил необходимо перезагрузить firewalld:

```bash
sudo firewall-cmd --reload
```

**9. Дополнительные возможности**

* Firewalld поддерживает NAT (Network Address Translation) и переадресацию портов.
* Firewalld можно использовать для настройки брандмауэра для Docker и других контейнерных технологий.

**10. Рекомендации**

* Перед внесением изменений в firewalld рекомендуется создать резервную копию конфигурации.
* При настройке firewalld необходимо учитывать требования безопасности и доступности системы.
* Для более сложных конфигураций рекомендуется использовать богатые правила.

Надеюсь, эта инструкция поможет вам разобраться с firewalld.
