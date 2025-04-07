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

# Настройка NFS клиента и Chrony на HQ-CLI

# 1. Установка NFS клиента
echo "Установка NFS клиента..."
apt-get update
if [ $? -ne 0 ]; then handle_error "apt-get update" $?; fi
apt-get install nfs-common -y
if [ $? -ne 0 ]; then handle_error "apt-get install nfs-common -y" $?; fi

# 2. Создание точки монтирования
echo "Создание точки монтирования..."
mkdir -p /mnt/nfs
if [ $? -ne 0 ]; then handle_error "mkdir -p /mnt/nfs" $?; fi

# 3. Добавление записи в /etc/fstab
echo "Добавление записи в /etc/fstab..."
vim /etc/fstab <<EOF
192.168.1.2:/raid5/nfs	/mnt/nfs	nfs	intr,soft,_netdev,x-systemd.automount 0 0
EOF
if [ $? -ne 0 ]; then handle_error "vim /etc/fstab" $?; fi

# 4. Монтирование NFS
echo "Монтирование NFS..."
mount -a
if [ $? -ne 0 ]; then handle_error "mount -a" $?; fi
mount -v
if [ $? -ne 0 ]; then handle_error "mount -v" $?; fi

# 5. Проверка монтирования
echo "Проверка монтирования..."
touch /mnt/nfs/cock
if [ $? -ne 0 ]; then handle_error "touch /mnt/nfs/cock" $?; fi

# 6. Настройка Chrony/timesyncd
echo "Настройка Chrony/timesyncd..."
systemctl disable --now chronyd
if [ $? -ne 0 ]; then handle_error "systemctl disable --now chronyd" $?; fi
systemctl status chronyd
if [ $? -ne 0 ]; then handle_error "systemctl status chronyd" $?; fi

apt-get update
if [ $? -ne 0 ]; then handle_error "apt-get update" $?; fi
apt-get install systemd-timesyncd -y
if [ $? -ne 0 ]; then handle_error "apt-get install systemd-timesyncd -y" $?; fi
vim /etc/systemd/timesyncd.conf <<EOF
[Time]
NTP=192.168.1.1
EOF
if [ $? -ne 0 ]; then handle_error "vim /etc/systemd/timesyncd.conf" $?; fi
systemctl enable --now systemd-timesyncd
if [ $? -ne 0 ]; then handle_error "systemctl enable --now systemd-timesyncd" $?; fi
timedatectl timesync-status
if [ $? -ne 0 ]; then handle_error "timedatectl timesync-status" $?; fi
timedatectl status
if [ $? -ne 0 ]; then handle_error "timedatectl status" $?; fi

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