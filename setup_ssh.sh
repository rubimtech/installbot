#!/bin/bash
# curl -sSL https://raw.githubusercontent.com/rubimtech/installbot/main/setup_ssh.sh | bash

# Путь к директории с ключами
KEY_DIR="$HOME/.ssh"
PRIVATE_KEY="$KEY_DIR/id_rsa"
PUBLIC_KEY="$KEY_DIR/id_rsa.pub"

# Проверка на наличие публичного и приватного ключей
if [ ! -f "$PUBLIC_KEY" ]; then
    echo "Публичный ключ не найден: $PUBLIC_KEY"
    echo "Генерация новой пары ключей..."

    # Создание директории .ssh, если она не существует
    mkdir -p $KEY_DIR

    # Генерация новой пары ключей
    ssh-keygen -t rsa -b 2048 -f $PRIVATE_KEY -N ""

    echo "Ключи успешно созданы: $PRIVATE_KEY и $PUBLIC_KEY"
else
    echo "Публичный ключ найден: $PUBLIC_KEY"
fi

# Создание директории .ssh, если она не существует
mkdir -p ~/.ssh

# Проверка, существует ли файл authorized_keys
if [ ! -f ~/.ssh/authorized_keys ]; then
    echo "Файл authorized_keys не найден. Создание файла..."
    touch ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    echo "Файл authorized_keys создан."
fi

# Добавление публичного ключа в файл authorized_keys, если его нет
if ! grep -q "$(cat $PUBLIC_KEY)" ~/.ssh/authorized_keys; then
    echo "Добавление публичного ключа в файл authorized_keys..."
    cat $PUBLIC_KEY >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    echo "Публичный ключ добавлен в файл authorized_keys."
else
    echo "Публичный ключ уже добавлен в файл authorized_keys."
fi

# Вывод сообщения о завершении
echo "Процесс завершен."


