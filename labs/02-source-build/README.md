# Лабораторная 02. Сборка iperf3 из проверенного архива

Полные 22 шага с разбором вывода: [WALKTHROUGH.md](WALKTHROUGH.md).
[Общая подготовка](../../PREPARATION.md), одна ВМ; никаких сертификатов сервиса.

## Пакеты и точный источник архива

```bash
# Rocky 9/10: минимальные зависимости вместо зависящего от локали group name.
sudo dnf install -y gcc make pkgconf-pkg-config openssl-devel curl tar
# Debian/Ubuntu — альтернатива:
sudo apt update
sudo apt install -y build-essential pkg-config libssl-dev curl
```

Архив выпуска 3.21 и SHA256 опубликованы
[ESnet](https://downloads.es.net/pub/iperf/). Это фиксированный учебный пример,
не команда «обновить всё до latest».
```bash
install -d -m 0750 "$REPO/generated/downloads/iperf"
cd "$REPO/generated/downloads/iperf"
curl --fail --location --proto '=https' --tlsv1.2 \
  -o iperf-3.21.tar.gz https://downloads.es.net/pub/iperf/iperf-3.21.tar.gz
curl --fail --location --proto '=https' --tlsv1.2 \
  -o SHA256SUMS https://downloads.es.net/pub/iperf/iperf-3.21.tar.gz.sha256
sha256sum -c SHA256SUMS
tar -tzf iperf-3.21.tar.gz | head
```

Ожидается `iperf-3.21.tar.gz: OK`, внутри каталог `iperf-3.21/`.
HTTPS обеспечивает доверие к источнику в этом сценарии, checksum — целостность;
это не проверка подписи разработчика. При offline-выдаче преподаватель передает
оба этих файла, их имена и контрольную сумму по доверенному каналу.
В исходном пособии `iperf3-X.Y.tar.gz` замените на фактическое `iperf-3.21.tar.gz`.

## Сборка, установка и проверка

```bash
cd "$REPO"
LPIC103_BUILD_DIR="$REPO/generated/build-iperf3" \
  ./labs/02-source-build/build-iperf3.sh \
  generated/downloads/iperf/iperf-3.21.tar.gz generated/downloads/iperf/SHA256SUMS
cd "$REPO/generated/build-iperf3/iperf-3.21"
# Только после configure, make и make check с exit=0:
sudo make install
sudo ldconfig
/usr/local/bin/iperf3 --version
ldd /usr/local/bin/iperf3
# Если loader не видит /usr/local/lib, проверьте /etc/ld.so.conf.d/;
# полный файл для данного prefix предоставлен ниже.
sudo install -m 0644 "$REPO/labs/02-source-build/ld-local.conf" /etc/ld.so.conf.d/lpic103-local.conf
sudo ldconfig
sudo systemd-run --unit=lpic103-iperf-server.service /usr/local/bin/iperf3 -s -1 -B 127.0.0.1
/usr/local/bin/iperf3 -c 127.0.0.1 -t 3
sudo journalctl -u lpic103-iperf-server --no-pager
```

Если клиент стартовал до listener, повторите после `ss -lnt 'sport = :5201'`.
В ldd нет `not found`, в клиенте есть sender/receiver и Bitrate.
`-s -1` обслуживает одно соединение. Повторная сборка использует новый каталог.
Не пропускайте FAIL тестов. Для удаления именно собранной версии:
`sudo make uninstall` из сохраненного build tree, затем `sudo ldconfig`.
