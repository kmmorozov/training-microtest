Настройка OpenVPN сервера и клиента на RedHat-подобной системе включает несколько ключевых этапов: установку необходимых пакетов, генерацию сертификатов и ключей, настройку сервера и клиента, а также настройку маршрутизации и брандмауэра.

Вот подробное руководство:

**1. Установка OpenVPN и EasyRSA:**

* **На сервере:**

    ```bash
    sudo yum install openvpn easy-rsa
    ```

* **На клиенте:**

    ```bash
    sudo yum install openvpn
    ```

**2. Генерация сертификатов и ключей (на сервере):**

* Скопируйте скрипты EasyRSA:

    ```bash
    sudo cp -r /usr/share/easy-rsa/3 /etc/openvpn/easy-rsa
    cd /etc/openvpn/easy-rsa
    ```

* Инициализация PKI:

    ```bash
    ./easyrsa init-pki
    ```

* Создание центра сертификации (CA):

    ```bash
    ./easyrsa build-ca
    ```

* Генерация ключа сервера:

    ```bash
    ./easyrsa build-server-full server
    ```

* Генерация ключа клиента:

    ```bash
    ./easyrsa build-client-full client1
    ```

* Генерация ключа Diffie-Hellman:

    ```bash
    ./easyrsa gen-dh
    ```

* Копирование необходимых файлов:

    ```bash
    sudo cp pki/ca.crt /etc/openvpn/
    sudo cp pki/issued/server.crt /etc/openvpn/
    sudo cp pki/private/server.key /etc/openvpn/
    sudo cp pki/dh.pem /etc/openvpn/
    sudo cp pki/issued/client1.crt /etc/openvpn/
    sudo cp pki/private/client1.key /etc/openvpn/
    ```

**3. Настройка сервера OpenVPN:**

* Скопируйте пример конфигурационного файла:

    ```bash
    sudo cp /usr/share/doc/openvpn/sample/sample-config-files/server.conf /etc/openvpn/
    ```

* Отредактируйте `/etc/openvpn/server.conf`:

    * Укажите пути к сертификатам и ключам.
    * Настройте сеть VPN (например, `server 10.8.0.0 255.255.255.0`).
    * Включите маршрутизацию (`push "redirect-gateway def1"`).
    * Настройте DNS (`push "dhcp-option DNS 8.8.8.8"`).
    * Раскомментируйте строку dh dh.pem
    * проверьте что ca, cert, key, лежат в тех же папках что и server.conf

* Включение переадресации IP:

    ```bash
    sudo sysctl -w net.ipv4.ip_forward=1
    ```

* Настройка брандмауэра:

    ```bash
    sudo firewall-cmd --permanent --add-service=openvpn
    sudo firewall-cmd --permanent --add-masquerade
    sudo firewall-cmd --reload
    ```

**4. Настройка клиента OpenVPN:**

* Скопируйте пример конфигурационного файла:

    ```bash
    sudo cp /usr/share/doc/openvpn/sample/sample-config-files/client.conf /etc/openvpn/client.conf
    ```

* Отредактируйте `/etc/openvpn/client.conf`:

    * Укажите адрес сервера.
    * Укажите пути к сертификатам и ключам клиента.
    * Проверьте что ca, cert, key лежат в той же папке что и client.conf
    * Укажите имя файла сертификата ca.
    * Укажите имя файла сертификата client.
    * Укажите имя файла ключа client.

* Скопируйте сертификаты и ключи клиента на клиентскую машину.

**5. Запуск OpenVPN:**

* **На сервере:**

    ```bash
    sudo systemctl start openvpn@server
    sudo systemctl enable openvpn@server
    ```

* **На клиенте:**

    ```bash
    sudo openvpn --config /etc/openvpn/client.conf
    ```

**Дополнительные советы:**

* Используйте надежные пароли для ключей.
* Регулярно обновляйте OpenVPN и EasyRSA.
* Настройте брандмауэр для дополнительной безопасности.
* Для удобства работы с клиентами, можно создать для каждого клиента свой конфигурационный файл, и папку, и в эту папку положить все необходимые сертификаты и ключи, и файл конфигурации клиента.
* Так же, для удобства работы, можно использовать OpenVPN Access Server.
* При возникновении проблем, проверяйте логи OpenVPN.

Этот процесс требует внимательности, но после успешной настройки вы получите безопасное и надежное VPN-соединение.
