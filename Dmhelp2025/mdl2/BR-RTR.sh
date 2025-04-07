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

# Настройка SSH, Chrony/timesyncd, NAT на BR-RTR

# 1. Установка и настройка SSH
echo "Установка и настройка SSH..."
apt update
if [ $? -ne 0 ]; then handle_error "apt update" $?; fi
apt install openssh-server -y
if [ $? -ne 0 ]; then handle_error "apt install openssh-server -y" $?; fi

# 2. Редактирование sshd_config
echo "Редактирование sshd_config..."
vim /etc/ssh/sshd_config <<EOF
Port 22
MaxAuthTries 2
AllowUsers net_admin
PermitRootLogin no
Banner /root/banner
EOF
if [ $? -ne 0 ]; then handle_error "vim /etc/ssh/sshd_config" $?; fi

# 3. Создание баннера SSH
echo "Создание баннера SSH..."
mkdir -p /root/
if [ $? -ne 0 ]; then handle_error "mkdir -p /root/" $?; fi
vim /root/banner <<EOF
Authorized access only
EOF
if [ $? -ne 0 ]; then handle_error "vim /root/banner" $?; fi

# 4. Перезапуск SSH
echo "Перезапуск SSH..."
systemctl restart sshd
if [ $? -ne 0 ]; then handle_error "systemctl restart sshd" $?; fi
systemctl enable --now sshd
if [ $? -ne 0 ]; then handle_error "systemctl enable --now sshd" $?; fi

# 5. Настройка Chrony/timesyncd
echo "Настройка Chrony/timesyncd..."
apt-get purge ntp -y
if [ $? -ne 0 ]; then handle_error "apt-get purge ntp -y" $?; fi
apt-get purge chrony -y
if [ $? -ne 0 ]; then handle_error "apt-get purge chrony -y" $?; fi
apt update
if [ $? -ne 0 ]; then handle_error "apt update" $?; fi
apt install systemd-timesyncd -y
if [ $? -ne 0 ]; then handle_error "apt install systemd-timesyncd -y" $?; fi

# 6. Редактирование timesyncd.conf
echo "Редактирование timesyncd.conf..."
vim /etc/systemd/timesyncd.conf <<EOF
[Time]
NTP=172.16.4.2
EOF
if [ $? -ne 0 ]; then handle_error "vim /etc/systemd/timesyncd.conf" $?; fi
systemctl enable --now systemd-timesyncd
if [ $? -ne 0 ]; then handle_error "systemctl enable --now systemd-timesyncd" $?; fi
timedatectl status
if [ $? -ne 0 ]; then handle_error "timedatectl status" $?; fi

# 7. Настройка NAT
echo "Настройка NAT..."
iptables -t nat -A PREROUTING -p tcp -d 192.168.4.1 --dport 80 -j DNAT --to-destination 192.168.4.2:8080
if [ $? -ne 0 ]; then handle_error "iptables -t nat -A PREROUTING -p tcp -d 192.168.4.1 --dport 80 -j DNAT --to-destination 192.168.4.2:8080" $?; fi
iptables -t nat -A PREROUTING -p tcp -d 192.168.4.1 --dport 2024 -j DNAT --to-destination 192.168.4.2:2024
if [ $? -ne 0 ]; then handle_error "iptables -t nat -A PREROUTING -p tcp -d 192.168.4.1 --dport 2024 -j DNAT --to-destination 192.168.4.2:2024" $?; fi
iptables-save > /root/rules
if [ $? -ne 0 ]; then handle_error "iptables-save > /root/rules" $?; fi

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