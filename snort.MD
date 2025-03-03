**1. Подготовка системы Rocky Linux версий 8 или 9**

* **Обновление системы**:
    ```bash
    sudo dnf update -y
    ```
* **Установка необходимых пакетов**:
    ```bash
    sudo dnf install -y gcc make flex bison pcre-devel zlib-devel libpcap-devel openssl-devel daq daq-devel
    ```

**2. Установка Snort**

* **Загрузка исходного кода Snort**:
    * Перейдите на официальный сайт Snort (snort.org) и загрузите последнюю стабильную версию исходного кода.
    * Или вы можете использовать wget:

        ```bash
        wget https://www.snort.org/downloads/snort/snort-3.1.71.0.tar.gz
        ```

    * (Замените ссылку на актуальную версию)
* **Распаковка архива**:
    ```bash
    tar -xzfv snort-3.1.71.0.tar.gz
    cd snort-3.1.71.0
    ```
* **Компиляция и установка**:
    ```bash
    ./configure_cmake.sh --prefix=/usr/local --enable-sourcefire
    cd build
    make
    sudo make install
    sudo ldconfig
    ```

**3. Настройка Snort**

* **Создание директорий**:
    ```bash
    sudo mkdir /etc/snort
    sudo mkdir /var/log/snort
    sudo mkdir /etc/snort/rules
    ```
* **Копирование конфигурационных файлов**:
    ```bash
    sudo cp ../etc/snort.conf /etc/snort/
    sudo cp ../etc/rules/snort.rules /etc/snort/rules/
    ```
* **Редактирование snort.conf**:
    * Откройте файл `/etc/snort/snort.conf` в текстовом редакторе.
    * Найдите и измените следующие параметры:
        * `ipvar HOME_NET`: укажите вашу локальную сеть (например, `192.168.1.0/24`).
        * `ipvar EXTERNAL_NET`: обычно устанавливается в `!$HOME_NET`.
        * `var RULE_PATH`: укажите путь к правилам (например, `/etc/snort/rules`).
        * `var SO_RULE_PATH`: укажите путь к общим правилам.
        * `var PREPROC_RULE_PATH`: укажите путь к правилам препроцессора.
        * Настройте другие параметры в соответствии с вашими потребностями.
* **Настройка правил**:
    * Snort использует правила для обнаружения вторжений. Вы можете использовать готовые наборы правил или создавать собственные.
    * Для начала скопируйте базовый набор правил:
        ```bash
        sudo cp ../rules/snort.rules /etc/snort/rules/
        ```
    * Так же вы можете скачать правила с официального сайта snort.
* **Настройка сетевого интерфейса**:
    * Определите сетевой интерфейс, который будет использоваться Snort для мониторинга:
        ```bash
        ip a
        ```
    * Запишите имя интерфейса (например, `eth0`).
    * Переведите сетевой интерфейс в promiscuous mode:
        ```bash
        sudo ip link set eth0 promisc on
        ```
    * (Замените `eth0` на ваш интерфейс)

**4. Запуск Snort**

* **Тестирование конфигурации**:
    ```bash
    sudo snort -T -c /etc/snort/snort.conf
    ```
* **Запуск Snort в режиме IDS**:
    ```bash
    sudo snort -q -u snort -g snort -c /etc/snort/snort.conf -i eth0 -D
    ```
    * `-q`: тихий режим.
    * `-u snort -g snort`: запуск от имени пользователя и группы `snort`.
    * `-c`: путь к конфигурационному файлу.
    * `-i`: сетевой интерфейс.
    * `-D`: запуск в фоновом режиме.
* **Проверка логов**:
    ```bash
    sudo tail -f /var/log/snort/alert
    ```

**5. Автозапуск Snort**

* **Создание сервисного файла**:
    ```bash
    sudo nano /etc/systemd/system/snort.service
    ```
* **Добавление следующего содержимого**:

    ```ini
    [Unit]
    Description=Snort IDS
    After=network.target

    [Service]
    Type=simple
    ExecStart=/usr/local/bin/snort -q -u snort -g snort -c /etc/snort/snort.conf -i eth0 -D

    [Install]
    WantedBy=multi-user.target
    ```

* **Включение и запуск сервиса**:
    ```bash
    sudo systemctl enable snort.service
    sudo systemctl start snort.service
    ```

**6. Дополнительные настройки**

* **Установка PulledPork**: для автоматического обновления правил Snort.
* **Установка Barnyard2**: для обработки и записи логов Snort в базу данных.
* **Установка BASE**: для веб-интерфейса анализа логов Snort.

**Важные замечания:**

* Замените `eth0` на имя вашего сетевого интерфейса.
* Настройте правила Snort в соответствии с вашими потребностями.
* Регулярно обновляйте Snort и правила.
* В целях безопасности, рекомендуется запуск Snort от имени непривелигированного пользователя.
* Так же рекомендуется ознакомится с официальной документацией snort.
