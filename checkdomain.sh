#!/bin/bash

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
