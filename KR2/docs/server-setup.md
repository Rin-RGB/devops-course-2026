# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины
- Объём оперативной памяти: 2048 МБ (2 ГБ)
- Количество ядер процессора: 2
- Объём дискового накопителя: 25 ГБ (динамически расширяемый)

## 2. Сетевые интерфейсы
- **Адаптер 1 (enp0s3):** Тип подключения NAT. Полученный IP-адрес: 10.0.2.15/24. Назначение: доступ в Интернет для обновления пакетов.
- **Адаптер 2 (enp0s8):** Тип подключения «Виртуальный адаптер хоста» (Host-only). Полученный IP-адрес: 192.168.56.101/24. Назначение: доступ с хостовой системы (SSH, веб-сервер в лабе №6).

## 3. Правило проброса портов
- Порт хостовой системы: 2222
- Порт гостевой системы: 2222
(Правило для адаптера 1, протокол TCP)

## 4. Учётные записи
- **student:** (системная учетная запись, создана при установке). Входит в группы: student, sudo. Аутентификация: по паролю.
- **devops:** Входит в группы: devops, sudo. Аутентификация: по SSH-ключу (ed25519, файл `~/.ssh/devops_vm` на хосте). Парольная аутентификация отключена.

## 5. Служба SSH
- Порт: 2222
- Расположение файла конфигурации: `/etc/ssh/sshd_config.d/99-hardening.conf`
- Изменённые директивы и их значения:
  - `Port 2222`
  - `PermitRootLogin no`
  - `PasswordAuthentication no`
  - `PubkeyAuthentication yes`
  - `PermitEmptyPasswords no`
  - `MaxAuthTries 3`
  - `LoginGraceTime 30`
  - `AllowUsers devops`
  - `X11Forwarding no`
  - `ClientAliveInterval 300`
  - `ClientAliveCountMax 2`
- Примечание: в файле `/etc/ssh/sshd_config.d/50-cloud-init.conf` строка `PasswordAuthentication yes` закомментирована.

## 6. Правила межсетевого экрана (UFW)
- Политика по умолчанию: `deny (incoming)`, `allow (outgoing)`.
- Перечень правил:
  - `2222/tcp` — **LIMIT IN** (комментарий: 'SSH rate-limited')
  - `80/tcp` — **ALLOW IN** (комментарий: 'HTTP')
  - `443/tcp` — **ALLOW IN** (комментарий: 'HTTPS')

## 7. Снимки состояния
- `01-clean-install` — 08.10.2026 14:39 (чистая установка Ubuntu Server).
- `02-keys-configured` — 08.10.2026 16:37 (настроена ключевая аутентификация, создан пользователь devops).
- `03-ssh-hardened` — 26.10.2026 14:55 (усилена защита SSH, сменен порт).
- `04-ufw-configured` — 26.10.2026 15:45 (настроен межсетевой экран и логирование).

# Настройка сервера devops-vm

## 8. Веб-сервер
- **Устанавливаемый пакет:** `nginx`
- **Путь к конфигурации ресурса:** `/etc/nginx/sites-available/devops-site` (активируется симлинком в `/etc/nginx/sites-enabled/`)
- **Каталог ресурса:** `/var/www/devops-site`
  - Владелец: `devops:devops`
  - Права: `755` для каталогов, `644` для файлов
- **Сертификат:** `/etc/ssl/certs/devops.crt` (права `644`, владелец `root:root`)
- **Закрытый ключ:** `/etc/ssl/private/devops.key` (права `600`, владелец `root:root`)
- **Команда формирования сертификата:**
  ```bash
  sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/devops.key \
    -out /etc/ssl/certs/devops.crt \
    -subj "/CN=devops.local" \
    -addext "subjectAltName=DNS:devops.local"
