#!/usr/bin/env python3
"""Создать согласованные полные wp-config.php и SQL с новыми секретами.

Запускать от обычного пользователя: выходной каталог закрыт и не перезаписывается.
Пароль никогда не передается аргументом shell и не печатается в stdout.
"""
import argparse
import os
from pathlib import Path
import re
import secrets

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("output", type=Path, help="новый каталог вне публикуемых файлов")
args = parser.parse_args()
# umask защищает файлы уже при создании, а не только после chmod.
os.umask(0o077)
args.output.mkdir(mode=0o700, parents=True, exist_ok=False)
repo = Path(__file__).resolve().parents[1]
config = (repo / "labs/16-wordpress/wp-config.php.template").read_text()
# Hex содержит только безопасные для PHP/SQL символы, не требует экранирования.
password = secrets.token_hex(32)
config = config.replace("<random-database-password>", password)
# Каждый из восьми salts независим, а не восемь копий одного значения.
config = re.sub("<unique-secret>", lambda _: secrets.token_hex(48), config)
# Первый HTTP-этап; после установки TLS пользователь меняет ровно этот флаг.
config = config.replace("define('FORCE_SSL_ADMIN', true);",
                        "define('FORCE_SSL_ADMIN', false);")
sql = """-- Полный SQL для новой отдельной базы; выполнять sudo mariadb < create-database.sql.
-- Пароль совпадает с wp-config.php; не публиковать файл и не выполнять дважды.
CREATE DATABASE lpic103_wp CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'lpic103_wp'@'localhost' IDENTIFIED BY 'PASSWORD_TOKEN';
GRANT ALL PRIVILEGES ON lpic103_wp.* TO 'lpic103_wp'@'localhost';
SHOW GRANTS FOR 'lpic103_wp'@'localhost';
""".replace("PASSWORD_TOKEN", password)
# Проверка не допускает забытые placeholders даже после изменения исходного шаблона.
if "<unique-secret>" in config or "<random-database-password>" in config:
    raise SystemExit("В конфигурации остались placeholders")
(args.output / "wp-config.php").write_text(config)
(args.output / "create-database.sql").write_text(sql)
print(f"Созданы два закрытых файла в {args.output}; секреты в терминал не выведены.")
