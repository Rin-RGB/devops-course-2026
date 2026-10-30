#!/usr/bin/env bash
# Скрипт аудита конфигурации сервера devops-vm

FAILURES=0

check() {
    local description="$1"
    local command="$2"
    if eval "$command" > /dev/null 2>&1; then
        echo "[ OK ] $description"
    else
        echo "[FAIL] $description"
        FAILURES=$((FAILURES + 1))
    fi
}

echo "=== [1] Служба SSH ==="
check "Служба ssh активна" "systemctl is-active ssh | grep -q active"
check "SSH слушает порт 2222" "sudo ss -tlnp | grep -q ':2222'"

echo ""
echo "=== [2] Межсетевой экран ==="
check "UFW активен" "sudo ufw status | grep -q 'Status: active'"

echo ""
echo "=== [3] Пользователь devops ==="
check "Пользователь devops существует" "id devops > /dev/null 2>&1"
check "devops входит в группу sudo" "groups devops | grep -q sudo"

echo ""
echo "=== [4] Веб-сервер ==="
check "Служба nginx активна" "systemctl is-active nginx | grep -q active"
check "Конфигурация nginx синтаксически корректна" "sudo nginx -t 2>&1 | grep -q successful"
check "Сертификат истекает не ранее чем через 30 дней" "sudo openssl x509 -checkend \$((30*24*60*60)) -noout -in /etc/ssl/certs/devops.crt"
check "В каталоге ресурса нет файлов с правом записи для всех" "! sudo find /var/www/devops-site -perm -o+w -print -quit | grep -q ."
check "Права ключа TLS равны 600" "sudo stat -c '%a' /etc/ssl/private/devops.key | grep -q 600"

echo ""
if [ $FAILURES -gt 0 ]; then
    echo "Аудит завершён с ошибками: $FAILURES"
    exit 1
else
    echo "Аудит завершён успешно."
    exit 0
fi
