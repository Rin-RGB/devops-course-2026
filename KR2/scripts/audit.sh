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

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
