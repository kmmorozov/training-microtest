# Лабораторная работа 03. Ограничение ресурсов сервиса через systemd и cgroups

[Подготовка, пакеты, полные конфиги и уточнения](README.md) · [Общие материалы и ключи](../../PREPARATION.md)

Ниже все шаги руководства лабораторных v4 от 10.08.2026 с сохраненными
командами и ожидаемыми результатами. Сначала выполните подготовку в README:
она определяет адреса, значения переменных и различия ОС. Команды выполняются
по одной, на указанной машине; альтернативные ветки ОС не выполняются вместе.
В командах по умолчанию X=10/Y=20/Z=30, lab NIC=enp0s8, зоны internal/external/public.
Их необходимо сопоставить с реальными NIC/zone по README. Имена unit и web-user
по умолчанию Rocky; для Debian/Ubuntu используйте соответствия из README.
Выводы — образцы, а не протокол запуска на вашей ВМ.

Цель лабораторной работы: задать и проверить CPUQuota, MemoryHigh, MemoryMax и TasksMax для отдельного unit.

Стенд: одна Linux-ВМ с systemd, cgroup v2, stress-ng и sudo.

Сценарий: тестовый сервис создает чрезмерную нагрузку. Нужно ограничить процесс по CPU, памяти и числу задач и подтвердить фактическое применение ограничений cgroups.

Планируемый результат: тестовый transient unit виден в дереве cgroup; effective limits считаны через systemctl show, влияние CPUQuota наблюдается в cgtop, а завершение нагрузки интерпретировано по Result и exit status.

## Ограничения и безопасность

Важно: на общем стенде не задавайте лимиты для system.slice или user.slice.

Важно: при MemoryMax процесс может быть завершен OOM killer внутри cgroup; используйте только указанный тест.

## Ход выполнения

## Шаг 1. Проверить права и атрибуты

**Зачем: Определяем тип файловой системы cgroup, чтобы убедиться в использовании cgroup v2 перед настройкой контроллеров.**

```bash
stat -fc %T /sys/fs/cgroup
```

Ожидаемый вывод и результат:

```text
cgroup2fs
```

## Шаг 2. Сформировать или вывести контрольные данные

**Зачем: Проверяем доступные контроллеры cgroup v2, чтобы убедиться, что ядро поддерживает нужные ограничения ресурсов.**

```bash
cat /sys/fs/cgroup/cgroup.controllers
```

## Шаг 3. Проверить версию systemd

**Зачем: Проверьте, что стенд использует systemd; первая строка сообщает фактическую версию менеджера служб.**

```bash
systemd --version | head -1
```

Ожидаемый вывод и результат:

```text
systemd <версия> ...
```

## Шаг 4. Создать контролируемую нагрузку

**Зачем: Проверяем наличие и версию генератора нагрузки до запуска ограниченного systemd-unit.**

```bash
stress-ng --version
```

Ожидаемый вывод и результат:

```text
stress-ng, version <версия>
```

Для cgroup v2 stat выводит cgroup2fs.

## Шаг 5. Запустить временный unit

**Зачем: systemd-run создаст изолированный scope/service, поэтому тест не меняет чужой unit. Команда обращается к systemd. enable управляет автозапуском, --now также меняет текущее состояние, status/show читают фактические свойства, reload применяет проверенную конфигурацию без полного restart.**

```bash
sudo systemd-run --unit=lpic103-load.service \
  --property=CPUQuota=25% \
  --property=MemoryHigh=192M \
  --property=MemoryMax=256M \
  --property=TasksMax=32 \
  /usr/bin/stress-ng --cpu 2 --vm 1 --vm-bytes 128M --timeout 90s
```

Ожидаемый вывод и результат:

```text
Running as unit: <имя>.service
```

systemctl status lpic103-load.service показывает active во время теста.

## Шаг 6. Показать свойства unit

**Зачем: Сравните свойства systemd с файлами cgroup и наблюдаемой нагрузкой. Команда обращается к systemd. enable управляет автозапуском, --now также меняет текущее состояние, status/show читают фактические свойства, reload применяет проверенную конфигурацию без полного restart.**

```bash
systemctl show lpic103-load.service \
  -p ControlGroup -p CPUQuotaPerSecUSec -p MemoryHigh -p MemoryMax -p TasksMax
```

Ожидаемый вывод и результат:

```text
<Property>=<effective value>
...; exit status = 0
```

## Шаг 7. Проверить дерево и нагрузку cgroups

**Зачем: Проверяем дерево процессов учебной cgroup, чтобы убедиться, что рабочие процессы stress-ng находятся внутри ограничиваемой группы.**

```bash
systemd-cgls --unit lpic103-load.service
```

Ожидаемый вывод и результат:

```text
Control group /system.slice/<unit>
└─<PID> <process>
```

## Шаг 8. Проверить дерево и нагрузку cgroups

**Зачем: Наблюдаем потребление ресурсов по cgroup за несколько обновлений, чтобы сопоставить нагрузку с заданными лимитами.**

```bash
systemd-cgtop --iterations=3
```

Ожидаемый вывод и результат:

```text
Control Group Tasks %CPU Memory ...
/system.slice/<unit> ...
```

CPU unit не занимает полностью один logical CPU.

MemoryCurrent ниже MemoryMax.

## Шаг 9. Проверить состояние службы

**Зачем: Проверьте состояние до или после 90-секундного timeout. Во время нагрузки unit будет active; после штатного завершения — inactive (dead). Само состояние inactive после timeout не является ошибкой.**

```bash
systemctl status lpic103-load.service --no-pager
```

Ожидаемый вывод и результат:

```text
Во время теста: Active: active (running).
После timeout: Active: inactive (dead).
```

## Шаг 10. Просмотреть журнал службы

**Зачем: Выберите журнал нужного unit и ограничьте временной диапазон, чтобы связать сообщение с только что выполненным действием.**

```bash
journalctl -u lpic103-load.service --since '-5 min' --no-pager
```

Ожидаемый вывод и результат:

```text
... <unit>[PID]: <сообщение, относящееся к текущему действию> ...
```

## Шаг 11. Показать свойства unit

**Зачем: Проверяем причину завершения и пиковое потребление памяти, чтобы отличить штатный timeout от ошибки или остановки из-за лимита.**

```bash
systemctl show lpic103-load.service -p Result -p ExecMainCode -p ExecMainStatus -p MemoryPeak
```

Ожидаемый вывод и результат:

```text
Result=success
ExecMainCode=exited
ExecMainStatus=0
MemoryPeak=<bytes>
```

Result и exit status получены и интерпретированы.
