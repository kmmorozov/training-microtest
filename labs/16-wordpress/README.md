# Лабораторная 16: WordPress

1. Проверьте выданный архив и подготовьте дерево через `prepare-wordpress.sh`.
2. Замените пароль и salts в `wp-config.php.template`; установите файл как
   `/var/www/lpic103-wp/wp-config.php` с владельцем `root:<web-group>` и mode 0640.
   Salts можно создать `scripts/generate-wordpress-secrets.sh`, сохранив вывод во
   временный защищенный файл mode 0600.
3. Выполните SQL из шаблона в локальном интерактивном `sudo mariadb`, не передавая
   пароль в аргументах shell.
4. Выберите Nginx-конфиг своей ОС. В Debian-шаблоне подставьте фактическую версию
   PHP из `/run/php/`; на RHEL согласуйте pool с `php-fpm-rhel.fragment`.
5. Возьмите `wp.crt`, `wp.key` и CA из результата `scripts/generate-lab-pki.sh`.
6. Проверьте `php-fpm -t` (если поддерживается), `nginx -t`, затем reload.

Закрытый ключ устанавливается mode 0600. Код WordPress остается root:root; право
записи получает только `wp-content/uploads`.
