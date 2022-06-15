- начальное конфигурирование Astra Linux

- русский и английский readme.md

- нужны конфиги для 12, 13, 14 postgresql

- -- Проверка репликации
  -- на МАСТЕР
  sudo ps wax|grep sender
  -- на СЛАВЕ
  sudo ps wax|grep receiver

- Параметр wal_keep_segments лучше увеличить для потоковой репликации.

- Нужно ли делать дополнительные проверки? например на 
SHOW password_encryption;


