#!/bin/bash
#-sSL https://raw.githubusercontent.com/rubimtech/installbot/main/setup_ssh.sh | bash
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

# Пример команды для копирования публичного ключа на удаленный сервер
# Убедитесь, что вы заменили <server_address> на нужный адрес сервера
# и <user> на имя пользователя, для которого нужно скопировать ключ

# echo "Копирование публичного ключа на сервер..."
# ssh-copy-id -i $PUBLIC_KEY user@server_address

echo "Процесс завершен."
