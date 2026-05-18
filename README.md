# 1 Часть
## Плохой CI/CD файл
```bash
stages:
  - lint
  - test
  - build
  - scan
  - deploy

job_lint:
  stage: lint
  image: python:latest
  script:
    - pip install pylint
    - pylint myscript.py || true

job_test:
  stage: test
  image: python:latest
  script:
    - pip install pytest
    - pytest tests/

job_build:
  stage: build
  image: docker:latest
  script:
    - docker build -t myapp:latest .
    - docker login -u "admin" -p "p@ssword123"

job_scan:
  stage: scan
  image: docker:latest
  script:
    - echo "Сканируем образ"

job_deploy:
  stage: deploy
  image: alpine:latest
  script:
    - scp -r ./build user@prod-server:/var/www/
```

### Какие 5 плохих практик используются: 
1)	Использование тега :latest для образов (версии могу обновиться,  от версии к версии бывают различия в синтаксисе и прочие неприятные штуки)  
Как исправить: указать конкретную версию  
Как повлияло исправление: обеспечение стабильности   
<br></br>
2)	Игнорирование ошибок сборки (|| true) (не останавливаем процесс, если что-то сломалось, а заставляем пайплайн всегда гореть зелёным)  
Как исправить:  || true можно убрать   
Как повлияло исправление: в следующую сборку попадает только проверенный код  
Как повлияло исправление: обеспечение стабильности   
<br></br>
3)	Хардкод (- docker login -u "admin" -p "p@ssword123") (кроме того, что креды видит любо человек, имеющий доступ к репозиторию, так её и в логах пайплайна пароли-явки сохранятся в открытом виде)  
Как исправить: использовать переменные окружения или внешнее хранилище  
Как повлияло исправление: добавление безопасности  
Как повлияло исправление: повышение стабильности    
<br></br>
4)	Отсутствие кэширования зависимостей (каждый раз происходит - pip install pylint, - pip install pytest) (замедление работы, каждый раз качаем одни и те же мегабайты из интернета)  
Как исправить: пользоваться секцией cache:, чтобы сохранять папку с библиотеками между запусками  
Как повлияло исправление: увеличение скорости работы   
<br></br>
5)	Деплой из любой ветки (job_deploy просто запускает scp) (прод сработает, даже если просто создать черновую ветку, любой пуш в любую ветку пытается обновить живой сайт)  
Как исправить: добавить условие rules: - if: $CI_COMMIT_BRANCH == "main", чтобы деплой шел только из главной ветки  
Как повлияло исправление: безопасность продакшн-окружения  
Как повлияло исправление: обеспечение стабильности    
<br></br>

## Хороший вариант CI/CD файл
```bash
variables:
  PYTHON_IMAGE: "python:3.11-slim"
  DOCKER_IMAGE: "docker:24.0.5"

stages:
  - lint
  - test
  - build
  - scan
  - deploy

# кэш для Python зависимостей
cache:
  paths:
    - .cache/pip

# Шаблон для экономии места
.python_job:
  image: $PYTHON_IMAGE
  before_script:
    - pip install --cache-dir .cache/pip -r requirements.txt
linting:
  extends: .python_job
  stage: lint
  script:
    - pylint myscript.py # теперь не умалчиваем об ошибке

testing:
  extends: .python_job
  stage: test
  script:
    - pytest tests/

building:
  stage: build
  image: $DOCKER_IMAGE
  services:
    - docker:dind
  script:
    # переменные вместо хардкода
    - echo "$DOCKER_REGISTRY_PASSWORD" | docker login -u "$DOCKER_REGISTRY_USER" --password-stdin
    - docker build -t myapp:$CI_COMMIT_SHORT_SHA .
    - docker push myapp:$CI_COMMIT_SHORT_SHA

security_scan:
  stage: scan
  image: $DOCKER_IMAGE
  script:
    - echo "Trivy для сканирования образа"

deployment:
  stage: deploy
  image: alpine:3.18
  script:
    - echo "Деплой только из основной ветки"
  rules:
    - if: $CI_COMMIT_BRANCH == "main" # деплоим только финал
```

# 2 Часть
## Запуск HashiCorp Vault в Docker (ададим мастер-ключ для удобства подключения)
```bash
docker run -d --name vault-lab \
  -p 8200:8200 \
  -e "SKIP_SETCAP=true" \
  -e "VAULT_DEV_ROOT_TOKEN_ID=my-root-token" \
  -e 'VAULT_LOCAL_CONFIG={"disable_mlock": true}' \
  hashicorp/vault server -dev -dev-listen-address="0.0.0.0:8200"
```

Проверим работоспособность контейнера:
<img width="974" height="54" alt="image" src="https://github.com/user-attachments/assets/f380a453-048e-4581-8a99-3e35c79cc670" />

Заходим внутрь контейнера:
```bash
docker exec -it vault-lab sh
```
После этого указываем адрес сервера, записываем секкрет и проверяем, что секрет записался:
```bash
export VAULT_ADDR='http://127.0.0.1:8200'
vault kv put secret/lab4-data db_password="VAULT_SUPER_SECRET_2026"
vault kv get secret/lab4-data
```
<br></br>
Результат работы команды:  
<img width="974" height="707" alt="image" src="https://github.com/user-attachments/assets/29fd8e3f-f491-4497-b9b7-57a3e545de05" />
<br></br>
Можно зайти на Vault:
<img width="974" height="574" alt="image" src="https://github.com/user-attachments/assets/fc1028bc-5588-4858-862f-37f98aec14c8" />
<br></br>
Потом зайти в secret и lab4-data: 
<img width="974" height="476" alt="image" src="https://github.com/user-attachments/assets/4e1444c1-6bc9-4e50-9d68-4c7b85b5d517" />
<br></br>
<img width="974" height="302" alt="image" src="https://github.com/user-attachments/assets/061c43c3-4706-45dc-865b-7ffcd96cf227" />
<br></br>
<img width="974" height="396" alt="image" src="https://github.com/user-attachments/assets/b801478f-56f8-437d-a39f-3ef92c46bd8c" />
<br></br>
<br></br>
После этого создадим ci_pipeline.sh, который будет имитировать работу хорошего пайплайна. Он должен сходить в Vault, взять пароль и использовать его, не печатая в логах

```bash
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
```
Выдаём права:
```bash
chmod +x ci_pipeline.sh
```
Запуск скрипта:
```bash
bash ci_pipeline.sh
```
<br></br>
Результат работы скрипта:
<img width="672" height="191" alt="image" src="https://github.com/user-attachments/assets/b4bb9ba7-2edf-4a91-bc19-0f5c53583f6f" />
<img width="974" height="292" alt="image" src="https://github.com/user-attachments/assets/629b9bc5-23e9-4514-a929-b8a4b909d294" />

В ci_pipeline.sh используется принцип маскирования. Пароль записывается в переменную SECRET_PASSWORD, которая существует   
только внутри оперативной памяти. По завершаении скрипта переменная исчезает. Передаём скрипт напрямуюю в команду деплоя,   
не выводим пароль через echo.
<br></br>
## Почему хранение в CI/CD переменных репозитория - это плохо?  
1.	Расползание секретов: если много микросервисов используют одну и ту же БД, придется скопировать пароль в настройки многих разных репозиториев  
2.	Избыточный доступ: любой человек с правами “Maintainer” в проекте может зайти в настройки и нажать кнопку «Reveal value», увидев ваш пароль. Vault позволяет давать доступ только на чтение в момент сборки  
3.	Отсутствие ротации: cекреты в переменных GitLab/GitHub обычно “вечные”  
4.	Нет аудита: нельзя узнать, кто именно и когда использовал секрет   
<br></br>
## Почему способ с Vault — это красиво:
1.	Все секреты компании лежат в одном защищенном месте, смена пароля в Vault “обновляет” его для всех пайплайнов  
2.	Vault умеет создавать временные пароли  
3.	У Vault есть свои логи (подробный аудит)  
4.	Политики доступа:  можно настроить очень гибко: “Пайплайну разрешено только читать пароль, а разработчику *** - только менять его”  



