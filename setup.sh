#!/bin/bash
# curl -sSL https://raw.githubusercontent.com/rubimtech/installbot/main/setup.sh | bash

# Проверка, выполнена ли команда с правами суперпользователя
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[31mПожалуйста, запустите скрипт с правами суперпользователя (sudo).\033[0m"
  exit 1
fi

# Переменные, задаваемые пользователем
PGUSER="user"
PGPASSWORD="pass"
DBNAME="$(generate_dbname)"
DOMAIN="5319f6883d27.vps.myjino.ru"
YANDEX_DISK_CODE="hToR5KQ8jDrvUw"

# Функция для генерации имени базы данных
generate_dbname() {
  echo "$(tr -dc A-Za-z </dev/urandom | head -c 4)_bot"
}

# Функция для проверки переменной и задания значения
ask_if_empty() {
  VAR_NAME=$1
  PROMPT=$2
  DEFAULT_VALUE=$3
  VALUE=${!VAR_NAME}

  if [ -z "$VALUE" ]; then
    read -p "$PROMPT" USER_INPUT
    # Если пользователь оставил строку пустой, оставляем переменную пустой, без значения по умолчанию
    if [ -n "$USER_INPUT" ]; then
      VALUE=$USER_INPUT
    fi
    declare -g "$VAR_NAME"="$VALUE"
  fi
}

# Спрашиваем значения переменных
ask_if_empty "PGUSER" "Введите имя пользователя для PostgreSQL: " ""
ask_if_empty "PGPASSWORD" "Введите пароль для пользователя $PGUSER: " ""
ask_if_empty "DBNAME" "Введите имя базы данных [по умолчанию: сгенерированное значение]: " "$DBNAME"
ask_if_empty "DOMAIN" "Введите домен для вашего бота: " ""
ask_if_empty "YANDEX_DISK_CODE" "Введите код публичного доступа к каталогу Яндекс.Диска: " ""

# Функция для проверки и установки пакетов
install_package() {
  PACKAGE=$1
  if ! dpkg -l | grep -q "$PACKAGE"; then
    echo -e "\033[33mУстанавливаю $PACKAGE...\033[0m"
    apt update && apt install -y "$PACKAGE"
  else
    echo -e "\033[32m$PACKAGE уже установлен.\033[0m"
  fi
}

# Установка основных пакетов
install_package curl
install_package nginx
install_package python3-venv
install_package python3-pip
install_package postgresql
install_package postgresql-contrib
install_package certbot
install_package python3-certbot-nginx
install_package jq

# Установка Python 3.12
if ! python3.12 --version &>/dev/null; then
  echo -e "\033[33mУстанавливаю Python 3.12...\033[0m"
  add-apt-repository -y ppa:deadsnakes/ppa
  apt update
  apt install -y python3.12 python3.12-venv python3.12-distutils
else
  echo -e "\033[32mPython 3.12 уже установлен.\033[0m"
fi

# Настройка PostgreSQL
if sudo -i -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$PGUSER'" | grep -q 1; then
  echo -e "\033[32mПользователь $PGUSER уже существует.\033[0m"
else
  echo -e "\033[33mСоздаю пользователя $PGUSER...\033[0m"
  sudo -i -u postgres createuser "$PGUSER"
  sudo -i -u postgres psql -c "ALTER USER $PGUSER WITH PASSWORD '$PGPASSWORD';"
fi

if sudo -i -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DBNAME'" | grep -q 1; then
  echo -e "\033[32mБаза данных $DBNAME уже существует.\033[0m"
else
  echo -e "\033[33mСоздаю базу данных $DBNAME...\033[0m"
  sudo -i -u postgres createdb "$DBNAME" --owner="$PGUSER"
fi

# Настройка домена и сертификатов
yes Y | certbot --nginx -d "$DOMAIN" --agree-tos --email "user@example.com"



# Конфигурация Nginx
NGINX_CONFIG="/etc/nginx/sites-available/$DOMAIN"
NGINX_LINK="/etc/nginx/sites-enabled/$DOMAIN"
echo -e "\033[33mНастраиваю Nginx для домена $DOMAIN...\033[0m"

# Проверяем, если в /etc/nginx/sites-enabled/ существует директория с именем домена, удаляем её
if [ -d "$NGINX_LINK" ]; then
  sudo rm -r "$NGINX_LINK"
fi

# Настроим конфигурацию Nginx
cat > "$NGINX_CONFIG" <<EOL
server {
    listen 80;
    server_name $DOMAIN;

    location /solonet_sub/ {
        proxy_pass http://localhost:3001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        add_header Content-Type text/plain;
        add_header Content-Disposition inline;

        add_header Cache-Control no-store;
        add_header Pragma no-cache;
    }

    location / {
        if (\$arg_url != "") {
            return 301 \$arg_url;
        }
        return 404 "URL argument is missing.";
    }

    location /webhook {
        proxy_pass http://localhost:3001/webhook;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location /yookassa/webhook {
        proxy_pass http://localhost:3001/yookassa/webhook;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOL

# Создаём символическую ссылку на конфигурацию
sudo ln -s "$NGINX_CONFIG" "$NGINX_LINK"

# Перезапускаем Nginx
sudo systemctl restart nginx

# Настройка Python окружения
BOT_DIR="/opt/solobot"
echo -e "\033[33mСоздаю директорию для бота: $BOT_DIR\033[0m"
mkdir -p "$BOT_DIR"
cd "$BOT_DIR"
echo -e "\033[33mЗагружаю и распаковываю код бота...\033[0m"

# Загрузка файлов с Яндекс.Диска
YANDEX_DISK_PUBLIC_URL="https://disk.yandex.ru/d/$YANDEX_DISK_CODE"
FILE_LIST=$(curl -s "https://cloud-api.yandex.net/v1/disk/public/resources?public_key=$YANDEX_DISK_PUBLIC_URL&limit=100" | jq -r '.embedded.items[] | select(.type == "file") | .file')

if [ -z "$FILE_LIST" ]; then
  echo -e "\033[31mКаталог пуст или ссылка недействительна.\033[0m"
  exit 1
fi

# Скачиваем файлы
for FILE_URL in $FILE_LIST; do
  FILE_NAME=$(basename "$FILE_URL")
  echo -e "\033[33mСкачиваю $FILE_NAME...\033[0m"
  curl -L -o "$FILE_NAME" "$FILE_URL"
done

# Создаем виртуальное окружение Python
python3.12 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

echo -e "\033[32mСкрипт завершен. Пожалуйста, убедитесь, что все настройки выполнены корректно.\033[0m" 
