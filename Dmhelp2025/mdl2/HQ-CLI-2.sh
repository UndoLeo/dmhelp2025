#!/bin/bash
set -e
set -x

# Массив для хранения сообщений об ошибках
errors=()

# Функция для обработки ошибок
handle_error() {
  local command="$1"
  local exit_code="$2"
  errors+=("Команда '$command' завершилась с кодом $exit_code")
  echo "Ошибка: $command завершилась с кодом $exit_code"
}

# Настройка Ansible и SSH на HQ-CLI

# 1. Создание пользователя sshuser
echo "Создание пользователя sshuser..."
useradd sshuser -u 1010
if [ $? -ne 0 ]; then handle_error "useradd sshuser -u 1010" $?; fi
echo "sshuser:P@ssw0rd" | chpasswd
if [ $? -ne 0 ]; then handle_error "echo \"sshuser:P@ssw0rd\" | chpasswd" $?; fi

# 2. Настройка sudo
echo "Настройка sudo..."
apt-get update
if [ $? -ne 0 ]; then handle_error "apt-get update" $?; fi
apt-get install sudo -y
if [ $? -ne 0 ]; then handle_error "apt-get install sudo -y" $?; fi
echo "sshuser ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/sshuser
if [ $? -ne 0 ]; then handle_error "echo \"sshuser ALL=(ALL:ALL) NOPASSWD: ALL\" | sudo tee /etc/sudoers.d/sshuser" $?; fi
chmod 0440 /etc/sudoers.d/sshuser
if [ $? -ne 0 ]; then handle_error "chmod 0440 /etc/sudoers.d/sshuser" $?; fi

# 3. Установка SSH и настройка порта
echo "Установка SSH и настройка порта..."
apt-get update
if [ $? -ne 0 ]; then handle_error "apt-get update" $?; fi
apt-get install openssh-server -y
if [ $? -ne 0 ]; then handle_error "apt-get install openssh-server -y" $?; fi

vim /etc/ssh/sshd_config <<EOF
Port 2024
MaxAuthTries 2
AllowUsers sshuser
PermitRootLogin no
Banner /root/banner
EOF
if [ $? -ne 0 ]; then handle_error "vim /etc/ssh/sshd_config" $?; fi

# 4. Создание баннера SSH
echo "Создание баннера SSH..."
mkdir -p /root/
if [ $? -ne 0 ]; then handle_error "mkdir -p /root/" $?; fi
vim /root/banner <<EOF
Authorized access only
EOF
if [ $? -ne 0 ]; then handle_error "vim /root/banner" $?; fi

# 5. Перезапуск SSH
echo "Перезапуск SSH..."
systemctl enable --now sshd
if [ $? -ne 0 ]; then handle_error "systemctl enable --now sshd" $?; fi
systemctl restart sshd
if [ $? -ne 0 ]; then handle_error "systemctl restart sshd" $?; fi

# 6. Установка Python и Jinja2
echo "Установка Python и Jinja2..."
apt-get update
if [ $? -ne 0 ]; then handle_error "apt-get update" $?; fi
apt-get install python3 python3-pip -y
if [ $? -ne 0 ]; then handle_error "apt-get install python3 python3-pip -y" $?; fi
pip3 install jinja2
if [ $? -ne 0 ]; then handle_error "pip3 install jinja2" $?; fi

# Вывод сводки об ошибках в конце скрипта
if [ ${#errors[@]} -gt 0 ]; then
  echo "--------------------------------------------------"
  echo "Обнаружены следующие ошибки:"
  for error in "${errors[@]}"; do
    echo "- $error"
  done
  echo "--------------------------------------------------"
  exit 1  # Завершить скрипт с ненулевым кодом возврата
else
  echo "Скрипт выполнен успешно без ошибок."
  exit 0  # Завершить скрипт с нулевым кодом возврата
fi