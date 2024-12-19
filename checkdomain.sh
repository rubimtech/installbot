#!/bin/bash

# Домен для проверки
read -p "Введите домен для проверки: " DOMAIN

# Получение IP-адреса сервера
SERVER_IP=$(curl -s ifconfig.me)

if [[ -z "$SERVER_IP" ]]; then
  echo "Не удалось получить IP-адрес сервера. Проверьте интернет-соединение."
  exit 1
fi

echo "IP-адрес сервера: $SERVER_IP"

# Проверка DNS-записи домена
DOMAIN_IP=$(nslookup "$DOMAIN" | grep -A 1 "Name:" | grep "Address" | awk '{print $2}' | head -n 1)

if [[ -z "$DOMAIN_IP" ]]; then
  echo "Не удалось найти IP-адрес для домена $DOMAIN. Проверьте DNS-настройки."
  exit 1
fi

echo "IP-адрес домена: $DOMAIN_IP"

# Сравнение IP-адресов
if [[ "$SERVER_IP" == "$DOMAIN_IP" ]]; then
  echo "Домен $DOMAIN привязан к серверу."
else
  echo "Домен $DOMAIN не привязан к серверу."
  echo "Ожидаемый IP-адрес: $SERVER_IP"
  echo "Найденный IP-адрес: $DOMAIN_IP"
fi
