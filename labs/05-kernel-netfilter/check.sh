#!/usr/bin/env bash
# Read-mostly подготовка лабораторной 05: проверяет модуль dummy и nft-синтаксис.
# Сам ruleset не применяется: команда применения только печатается в конце.
set -euo pipefail

# modinfo фиксирует происхождение, зависимости и параметры модуля.
modinfo dummy | sed -n '1,25p'
# dummy не управляет физическим устройством; numdummies=1 создает только dummy0.
sudo modprobe dummy numdummies=1
# Проверяем, что ожидаемый виртуальный link действительно появился.
ip -details link show dummy0
# -c выполняет dry validation всей nft-транзакции без изменения ruleset.
sudo nft -c -f "$(dirname "$0")/lpic103_lab.nft"
echo "Проверка успешна. Применение: sudo nft -f labs/05-kernel-netfilter/lpic103_lab.nft"
