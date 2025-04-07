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

# Настройка Chrony сервера, SSH, Nginx на HQ-RTR

# 1. Настройка Chrony
echo "Настройка Chrony..."
apt update
if [ $? -ne 0 ]; then handle_error "apt update" $?; fi
apt install chrony -y
if [ $? -ne 0 ]; then handle_error "apt install chrony -y" $?; fi
systemctl status chrony
if [ $? -ne 0 ]; then handle_error "systemctl status chrony" $?; fi
timedatectl
if [ $? -ne 0 ]; then handle_error "timedatectl" $?; fi

# 2. Редактирование chrony.conf
echo "Редактирование chrony.conf..."
vim /etc/chrony/chrony.conf <<EOF
local stratum 5
allow 192.168.1.0/26
allow 192.168.2.0/28
allow 172.16.5.0/28
allow 192.168.4.0/27
#pool 2.debian
#rtcsync
EOF
if [ $? -ne 0 ]; then handle_error "vim /etc/chrony/chrony.conf" $?; fi

# 3. Включение и перезапуск Chrony
echo "Включение и перезапуск Chrony..."
systemctl enable --now chrony
if [ $? -ne 0 ]; then handle_error "systemctl enable --now chrony" $?; fi
systemctl restart chrony
if [ $? -ne 0 ]; then handle_error "systemctl restart chrony" $?; fi

# 4. Отключение NTP
echo "Отключение NTP..."
timedatectl set-ntp 0
if [ $? -ne 0 ]; then handle_error "timedatectl set-ntp 0" $?; fi
timedatectl
if [ $? -ne 0 ]; then handle_error "timedatectl" $?; fi

# 5. Установка и настройка SSH
echo "Установка и настройка SSH..."
apt-get update
if [ $? -ne 0 ]; then handle_error "apt-get update" $?; fi
apt-get install openssh-server -y
if [ $? -ne 0 ]; then handle_error "apt-get install openssh-server -y" $?; fi

# 6. Редактирование sshd_config
echo "Редактирование sshd_config..."
vim /etc/ssh/sshd_config <<EOF
Port 22
MaxAuthTries 2
AllowUsers net_admin
PermitRootLogin no
Banner /root/banner
EOF
if [ $? -ne 0 ]; then handle_error "vim /etc/ssh/sshd_config" $?; fi

# 7. Создание баннера SSH
echo "Создание баннера SSH..."
mkdir -p /root/
if [ $? -ne 0 ]; then handle_error "mkdir -p /root/" $?; fi
vim /root/banner <<EOF
Authorized access only
EOF
if [ $? -ne 0 ]; then handle_error "vim /root/banner" $?; fi

# 8. Перезапуск SSH
echo "Перезапуск SSH..."
systemctl restart sshd
if [ $? -ne 0 ]; then handle_error "systemctl restart sshd" $?; fi
systemctl enable --now sshd
if [ $? -ne 0 ]; then handle_error "systemctl enable --now sshd" $?; fi

# 9. Установка и настройка Nginx
echo "Установка и настройка Nginx..."
apt install nginx -y
if [ $? -ne 0 ]; then handle_error "apt install nginx -y" $?; fi

# 10. Создание конфигурации Nginx для обратного прокси
echo "Создание конфигурации Nginx для обратного прокси..."
vim /etc/nginx/sites-available/proxy <<EOF
server {
  listen 80;
  server_name moodle.au-team.irpo;
  location / {
    proxy_pass http://192.168.1.2:80;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP  \$remote_addr;
    proxy_set_header X-Forwarded-For \$remote_addr;
   }
}

server {
  listen 80;
  server_name wiki.au-team.irpo;
  location / {
    proxy_pass http://192.168.4.2:8080;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP  \$remote_addr;
    proxy_set_header X-Forwarded-For \$remote_addr;
  }
}
EOF
if [ $? -ne 0 ]; then handle_error "vim /etc/nginx/sites-available/proxy" $?; fi

# 11. Включение сайта proxy и перезапуск Nginx
echo "Включение сайта proxy и перезапуск Nginx..."
rm -rf /etc/nginx/sites-available/default
if [ $? -ne 0 ]; then handle_error "rm -rf /etc/nginx/sites-available/default" $?; fi
rm -rf /etc/nginx/sites-enabled/default
if [ $? -ne 0 ]; then handle_error "rm -rf /etc/nginx/sites-enabled/default" $?; fi
ln -s /etc/nginx/sites-available/proxy /etc/nginx/sites-enabled
if [ $? -ne 0 ]; then handle_error "ln -s /etc/nginx/sites-available/proxy /etc/nginx/sites-enabled" $?; fi
ls -la /etc/nginx/sites-enabled
if [ $? -ne 0 ]; then handle_error "ls -la /etc/nginx/sites-enabled" $?; fi
systemctl restart nginx
if [ $? -ne 0 ]; then handle_error "systemctl restart nginx" $?; fi

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