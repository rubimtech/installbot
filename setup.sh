#!/bin/bash
# curl -sSL https://raw.githubusercontent.com/rubimtech/installbot/main/setup.sh | bash

# Проверка, выполнена ли команда с правами суперпользователя
if [ "$EUID" -ne 0 ]; then
  echo "Пожалуйста, запустите скрипт с правами суперпользователя (sudo)."
  exit 1
fi

# Функция для проверки и установки пакетов
install_package() {
  PACKAGE=$1
  if ! dpkg -l | grep -q "$PACKAGE"; then
    echo "Устанавливаю $PACKAGE..."
    apt update && apt install -y "$PACKAGE"
  else
    echo "$PACKAGE уже установлен."
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
  echo "Устанавливаю Python 3.12..."
  add-apt-repository -y ppa:deadsnakes/ppa
  apt update
  apt install -y python3.12 python3.12-venv python3.12-distutils
else
  echo "Python 3.12 уже установлен."
fi

# Настройка PostgreSQL
sudo -i -u postgres bash <<EOF
createuser --interactive
createdb solobot --owner=youruser
psql -c "ALTER USER youruser WITH PASSWORD 'yourpassword';"
EOF

# Настройка домена и сертификатов
read -p "Введите домен для вашего бота: " DOMAIN
certbot --nginx -d "$DOMAIN"

# Конфигурация Nginx
NGINX_CONFIG="/etc/nginx/sites-available/$DOMAIN"
NGINX_LINK="/etc/nginx/sites-enabled/$DOMAIN"
echo "Настраиваю Nginx для домена $DOMAIN..."
cat > "$NGINX_CONFIG" <<EOL
server {
    listen 80;
    server_name $DOMAIN;

    location /solonet_sub/ {
        proxy_pass http://localhost:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        add_header Content-Type text/plain;
        add_header Content-Disposition inline;

        add_header Cache-Control no-store;
        add_header Pragma no-cache;
    }

    location / {
        if ($arg_url != "") {
            return 301 $arg_url;
        }
        return 404 "URL argument is missing.";
    }

    location /webhook {
        proxy_pass http://localhost:3001/webhook;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location /yookassa/webhook {
        proxy_pass http://localhost:3001/yookassa/webhook;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

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
echo "Создаю директорию для бота: $BOT_DIR"
mkdir -p "$BOT_DIR"
cd "$BOT_DIR"
echo "Загружаю и распаковываю код бота..."

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

echo "Скрипт завершен. Пожалуйста, убедитесь, что все настройки выполнены корректно."
