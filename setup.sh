#!/bin/bash
# curl -sSL https://raw.githubusercontent.com/rubimtech/installbot/main/setup.sh | bash

# Проверка, выполнена ли команда с правами суперпользователя
if [ "$EUID" -ne 0 ]; then
  echo "\033[31mПожалуйста, запустите скрипт с правами суперпользователя (sudo).\033[0m"
  exit 1
fi

# Функция для проверки и установки пакетов
install_package() {
  PACKAGE=$1
  if ! dpkg -l | grep -q "$PACKAGE"; then
    echo "\033[33mУстанавливаю $PACKAGE...\033[0m"
    apt update && apt install -y "$PACKAGE"
  else
    echo "\033[32m$PACKAGE уже установлен.\033[0m"
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

# Установка Python 3.12
if ! python3.12 --version &>/dev/null; then
  echo "\033[33mУстанавливаю Python 3.12...\033[0m"
  add-apt-repository -y ppa:deadsnakes/ppa
  apt update
  apt install -y python3.12 python3.12-venv python3.12-distutils
else
  echo "\033[32mPython 3.12 уже установлен.\033[0m"
fi

# Настройка PostgreSQL
read -p "Введите имя пользователя PostgreSQL: " DB_USER
read -s -p "Введите пароль для пользователя PostgreSQL: " DB_PASS
echo ""
read -p "Введите имя базы данных: " DB_NAME

sudo -i -u postgres bash <<EOF
if ! psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER';" | grep -q 1; then
  echo "\033[33mСоздаю пользователя PostgreSQL '$DB_USER'...\033[0m"
  psql -c "CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS';"
else
  echo "\033[32mПользователь PostgreSQL '$DB_USER' уже существует.\033[0m"
fi

if ! psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME';" | grep -q 1; then
  echo "\033[33mСоздаю базу данных '$DB_NAME'...\033[0m"
  createdb "$DB_NAME" -O "$DB_USER"
else
  echo "\033[32mБаза данных '$DB_NAME' уже существует.\033[0m"
fi
EOF

# Настройка домена и сертификатов
read -p "Введите домен для вашего бота: " DOMAIN
certbot --nginx -d "$DOMAIN"

# Конфигурация Nginx
NGINX_CONFIG="/etc/nginx/sites-available/$DOMAIN"
NGINX_LINK="/etc/nginx/sites-enabled/$DOMAIN"
echo "\033[33mНастраиваю Nginx для домена $DOMAIN...\033[0m"
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
ln -s "$NGINX_CONFIG" "$NGINX_LINK"
systemctl restart nginx

# Настройка Python окружения
BOT_DIR="/opt/solobot"
echo "\033[33mСоздаю директорию для бота: $BOT_DIR\033[0m"
mkdir -p "$BOT_DIR"
cd "$BOT_DIR"

echo "\033[33mЗагружаю и распаковываю код бота...\033[0m"

# Загрузка файла с Яндекс.Диска
YANDEX_DISK_PUBLIC_URL="https://disk.yandex.ru/d/hToR5KQ8jDrvUw"
YANDEX_DOWNLOAD_URL=$(curl -s "https://cloud-api.yandex.net/v1/disk/public/resources/download?public_key=$YANDEX_DISK_PUBLIC_URL" | grep -oP '(?<="href":")[^"]+')

curl -L -o solobot.zip "$YANDEX_DOWNLOAD_URL"

unzip solobot.zip -d "$BOT_DIR"
mv "$BOT_DIR/solo_bot"/* "$BOT_DIR"
rm -r "$BOT_DIR/solo_bot" solobot.zip

python3.12 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

echo "\033[32mСкрипт завершен. Пожалуйста, убедитесь, что все настройки выполнены корректно.\033[0m"
