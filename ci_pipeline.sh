#!/bin/bash
VAULT_TOKEN="my-root-token"
VAULT_API_URL="http://127.0.0.1:8200/v1/secret/data/lab4-data"
CURL_PATH="/cygdrive/c/Windows/System32/curl.exe"

echo "Запуск CI/CD пайплайна (Deploy)"

# Получаем секрет через API
if [ ! -f "$CURL_PATH" ]; then
    CURL_PATH="curl"
fi

RESPONSE=$($CURL_PATH -s -H "X-Vault-Token: $VAULT_TOKEN" $VAULT_API_URL)

# Извлекаем значение пароля из JSON ответа 
SECRET_PASSWORD=$(echo "$RESPONSE" | sed 's/.*"db_password":"\([^"]*\)".*/\1/')

# Проверка на наличие ошибок в ответе от Vault
if [[ -z "$SECRET_PASSWORD" || "$RESPONSE" == *"errors"* || "$RESPONSE" == *"404"* ]]; then
    echo "Ошибка, не удалось получить секрет из Vault"
    echo "Технический ответ сервера: $RESPONSE"
    exit 1
fi

echo "Секрет успешно получен из защищенного хранилища"

# имитация использования секрета
echo "Запуск процесса деплоя приложения"
# используем переменную, но не выводим её значение в консоль 
sleep 1
echo "Аутентификация в базе данных, выполнено."
sleep 1
echo "Деплой завершен успешно"
echo "Пайплайн завершен успешно "
