#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]

set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
LOCAL_DIR="$(git rev-parse --show-toplevel)/site/"

# 1. Разбор аргумента --dry-run
DRY_RUN=""
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN="--dry-run"
fi

# 2. Проверки
# Требование 4: Если site/index.html отсутствует -> ошибка
if [[ ! -f "${LOCAL_DIR}/index.html" ]]; then
    echo "Ошибка: файл ${LOCAL_DIR}/index.html не найден. Деплой прерван." >&2
    exit 1
fi

# Требование 5: Если есть незафиксированные изменения -> ошибка
if [[ -n "$(git status --porcelain)" ]]; then
    echo "Ошибка: в репозитории есть незафиксированные изменения. Деплой прерван." >&2
    exit 1
fi

# 3. Синхронизация каталога
echo "Запуск синхронизации..."
rsync -avz --delete --chmod=D755,F644 -e "ssh -o BatchMode=yes -o ConnectTimeout=5" ${DRY_RUN} "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"

# 4. При --dry-run завершаемся, не проверяя доступность
if [[ -n "${DRY_RUN}" ]]; then
    echo "Пробный запуск (dry-run) завершён успешно."
    exit 0
fi

# 5. Проверка доступности ресурса
echo "Проверка доступности ${SITE_URL}..."
if ! curl -sf --cacert "${CA_CERT}" "${SITE_URL}" > /dev/null; then
    echo "Ошибка: ресурс ${SITE_URL} недоступен после деплоя." >&2
    exit 1
fi

# 6. Успешное завершение
COMMIT_HASH=$(git rev-parse --short HEAD)
echo "Деплой успешно завершён! Доставлен коммит: ${COMMIT_HASH}"
exit 0
