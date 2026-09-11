#!/usr/bin/env python3
"""Проверить покрытие лабораторных, ссылки и синтаксис команд без их исполнения."""
import ast
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote

repo = Path(__file__).resolve().parents[1]
# Число шагов сверено с исходным руководством v4, а не выведено из самих README.
expected = [19, 22, 11, 25, 18, 33, 19, 43, 19, 21, 24, 26, 24, 22, 16, 50, 32, 40, 35]
errors = []
for number, count in enumerate(expected, 1):
    directories = sorted((repo / "labs").glob(f"{number:02d}-*"))
    if len(directories) != 1:
        errors.append(f"Lab {number}: ожидался один каталог, получено {len(directories)}")
        continue
    lab = directories[0]
    for name in ("README.md", "WALKTHROUGH.md"):
        if not (lab / name).is_file():
            errors.append(f"{lab.name}: отсутствует {name}")
    if not (lab / "WALKTHROUGH.md").exists():
        continue
    text = (lab / "WALKTHROUGH.md").read_text()
    steps = [int(x) for x in re.findall(r"^## Шаг (\d+)\.", text, re.M)]
    if steps != list(range(1, count + 1)):
        errors.append(f"{lab.name}: нарушено покрытие/порядок {count} шагов")
    # bash -n проверяет только грамматику: ни одна команда из документа не запускается.
    for i, block in enumerate(re.findall(r"```bash\n([\s\S]*?)\n```", text), 1):
        result = subprocess.run(["bash", "-n"], input=block, text=True, capture_output=True)
        if result.returncode:
            errors.append(f"{lab.name} block {i}: {result.stderr.strip()}")

# Пропускаем .git/generated, проверяем только собственные учебные Markdown.
documents = [repo / x for x in ("README.md", "PREPARATION.md", "STAND.md", "COMMANDS.md", "VERIFICATION.md")]
documents += list((repo / "labs").rglob("*.md"))
documents += list((repo / "lecture-examples").rglob("*.md"))
for path in documents:
    if not path.is_file():
        errors.append(f"Отсутствует документ {path.relative_to(repo)}")
        continue
    # Ссылки из fenced примеров не являются навигацией документа.
    text = re.sub(r"```[\s\S]*?```", "", path.read_text())
    for target in re.findall(r"\[[^\]\n]+\]\(([^)\n]+)\)", text):
        target = target.strip().strip("<>")
        if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target) or target.startswith("#"):
            continue
        target = unquote(target.split("#", 1)[0])
        if target and not (path.parent / target).exists():
            errors.append(f"{path.relative_to(repo)}: битая ссылка {target}")
# AST проверяет Python без pycache. Shell helpers без .sh проверяет shebang.
for folder in ("labs", "lecture-examples", "scripts"):
    for path in (repo / folder).rglob("*"):
        if not path.is_file() or "generated" in path.parts:
            continue
        if ".fragment" in path.name:
            errors.append(f"Остался неполный конфигурационный файл {path.relative_to(repo)}")
        if path.suffix == ".py":
            try:
                ast.parse(path.read_text(), filename=str(path))
            except SyntaxError as exc:
                errors.append(str(exc))
        if path.suffix != ".md" and path.read_bytes().startswith(b"#!/usr/bin/env bash"):
            result = subprocess.run(["bash", "-n", str(path)], capture_output=True, text=True)
            if result.returncode:
                errors.append(result.stderr.strip())

if errors:
    print("\n".join("ERROR: " + x for x in errors), file=sys.stderr)
    raise SystemExit(1)
print(f"OK: 19 README, {sum(expected)} последовательных шагов, ссылки, Bash/Python и полные файлы")
