#!/usr/bin/env bash
set -uo pipefail
PASS=0; FAIL=0

check() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo " [OK] $desc"; ((PASS++))
  else
    echo " [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"; ((FAIL++))
  fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"
check "Вход от имени root запрещён" "no" "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"
check "Парольная аутентификация отключена" "no" "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"
# TODO 1: проверьте, что значение параметра port отлично от 22
check "Порт SSH изменен" "2222" "$(sudo sshd -T | awk '/^port/{print $2}')"
# TODO 2: проверьте, что значение параметра maxauthtries равно 3
check "Лимит попыток входа = 3" "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

echo "[2] Межсетевой экран"
check "Межсетевой экран активен" "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"
# TODO 3: проверьте, что политика по умолчанию для входящего трафика равна deny
check "Входящий трафик запрещен по умолчанию" "deny" "$(sudo ufw status verbose | grep Default | awk -F'[ ,]' '{for(i=1;i<=NF;i++) if($i=="(incoming)") print $(i-1)}')"

echo "[3] Учётные записи"
awk -F: '$3>=1000 && $3<65534 {printf " %s (uid=%s)\n",$1,$3}' /etc/passwd

echo "[4] Веб-сервер"
# а) Служба nginx активна
check "Служба nginx активна" "active" "$(systemctl is-active nginx)"

# б) Конфигурация nginx синтаксически корректна
if sudo nginx -t >/dev/null 2>&1; then
    nginx_test="0"
else
    nginx_test="1"
fi
check "Конфигурация nginx корректна" "0" "$nginx_test"

# в) Сертификат истекает не ранее чем через 30 дней
if sudo openssl x509 -checkend 2592000 -noout -in /etc/ssl/certs/devops.crt >/dev/null 2>&1; then
    cert_valid="0"
else
    cert_valid="1"
fi
check "Сертификат действителен более 30 дней" "0" "$cert_valid"

# г) Нет файлов с правами на запись всем И права ключа = 600
if [[ -z "$(sudo find /var/www/devops-site -perm -o+w)" ]]; then
    no_writable="0"
else
    no_writable="1"
fi
check "Нет файлов, доступных для записи всем" "0" "$no_writable"

check "Права ключа = 600" "600" "$(sudo stat -c '%a' /etc/ssl/private/devops.key)"

echo "[5] Контейнеризация"

# а) Служба docker активна
check "Служба docker активна" "active" "$(systemctl is-active docker)"

# б) Контейнер СУБД находится в состоянии healthy
check "Контейнер СУБД healthy" "healthy" "$(sudo docker inspect -f '{{.State.Health.Status}}' app-db-1 2>/dev/null)"

# в) Порты 5000 и 5432 не прослушиваются ни на одном адресе, кроме 127.0.0.1
# Ищем в выводе ss строки с портами 5000 или 5432, которые НЕ начинаются с 127.0.0.1
bad_ports=$(sudo ss -tln | grep -E ':(5000|5432)\b' | grep -v '127.0.0.1' || true)
if [[ -z "$bad_ports" ]]; then
    ports_ok="0"
else
    ports_ok="1"
fi
check "Порты 5000 и 5432 скрыты от сети" "0" "$ports_ok"

# г) Права файла ~/app/.env равны 600
check "Права .env равны 600" "600" "$(stat -c '%a' ~/app/.env 2>/dev/null || echo 'no_file')"

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
