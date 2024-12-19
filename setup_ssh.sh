#!/bin/bash

# Проверка, что скрипт запущен от пользователя root
if [ "$(id -u)" -ne 0 ]; then
    echo "Скрипт должен быть запущен от пользователя root."
    exit 1
fi

# Убедитесь, что публичный ключ существует
PUBLIC_KEY_PATH="$HOME/.ssh/id_rsa.pub"
if [ ! -f "$PUBLIC_KEY_PATH" ]; then
    echo "Публичный ключ не найден: $PUBLIC_KEY_PATH"
    exit 1
fi

# Создание каталога .ssh, если он не существует
SSH_DIR="$HOME/.ssh"
if [ ! -d "$SSH_DIR" ]; then
    echo "Создание директории $SSH_DIR..."
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
fi

# Добавление публичного ключа в файл authorized_keys
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
echo "Добавление публичного ключа в $AUTHORIZED_KEYS..."
cat "$PUBLIC_KEY_PATH" >> "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"

# Проверка конфигурации SSH для разрешения аутентификации по ключу
SSHD_CONFIG="/etc/ssh/sshd_config"
if ! grep -q "PubkeyAuthentication yes" "$SSHD_CONFIG"; then
    echo "Разрешение аутентификации по ключу не найдено. Добавление в $SSHD_CONFIG..."
    echo "PubkeyAuthentication yes" >> "$SSHD_CONFIG"
fi

if ! grep -q "AuthorizedKeysFile .ssh/authorized_keys" "$SSHD_CONFIG"; then
    echo "Путь к файлу authorized_keys не найден. Добавление в $SSHD_CONFIG..."
    echo "AuthorizedKeysFile .ssh/authorized_keys" >> "$SSHD_CONFIG"
fi

# Перезапуск SSH сервиса для применения изменений
echo "Перезапуск SSH сервиса..."
systemctl restart ssh

# Уведомление о завершении
echo "SSH настроен для аутентификации с использованием публичного ключа."
