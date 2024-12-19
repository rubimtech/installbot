#!/bin/bash

# Проверка наличия пакета и установка, если его нет
check_and_install_package() {
  PACKAGE=$1
  COMMAND=$2

  if ! command -v "$COMMAND" &> /dev/null; then
    echo "Пакет $PACKAGE не установлен. Устанавливаем..."
    sudo apt update
    sudo apt install -y "$PACKAGE"
    
    if ! command -v "$COMMAND" &> /dev/null; then
      echo "Не удалось установить $PACKAGE. Проверьте настройки системы."
      exit 1
    fi
  else
    echo "$COMMAND уже установлен."
  fi
}

# Проверяем и устанавливаем необходимые пакеты
check_and_install_package "dnsutils" "dig"

# Основной функционал скрипта
read -p "Введите домен для проверки: " DOMAIN

SERVER_IP=$(curl -s ifconfig.me)
DOMAIN_IP=$(dig +short "$DOMAIN" | head -n 1)

if [[ -z "$DOMAIN_IP" ]]; then
  echo "Не удалось найти IP-адрес для домена $DOMAIN. Проверьте DNS-настройки."
  exit 1
fi

if [[ "$SERVER_IP" == "$DOMAIN_IP" ]]; then
  echo "Домен $DOMAIN привязан к серверу."
else
  echo "Домен $DOMAIN не привязан к серверу."
  echo "Ожидаемый IP-адрес: $SERVER_IP"
  echo "Найденный IP-адрес: $DOMAIN_IP"
fi
