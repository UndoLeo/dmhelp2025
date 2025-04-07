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

# -----------------------------------------------------------------------------
# Настройка системы
# -----------------------------------------------------------------------------

# 1. Настройка имени хоста
echo "1. Настройка имени хоста..."
hostnamectl set-hostname hq-cli.au-team.irpo
if [ $? -ne 0 ]; then handle_error "hostnamectl set-hostname hq-cli.au-team.irpo" $?; fi
exec bash
if [ $? -ne 0 ]; then handle_error "exec bash" $?; fi

# 2. Настройка временной зоны
echo "2. Настройка временной зоны..."
timedatectl set-timezone Asia/Vladivostok
if [ $? -ne 0 ]; then handle_error "timedatectl set-timezone Asia/Vladivostok" $?; fi

# -----------------------------------------------------------------------------
# Настройка VLAN
# -----------------------------------------------------------------------------

# 3. Создание директории для VLAN ens20.200
echo "3. Создание директории для VLAN ens20.200..."
mkdir -p /etc/net/ifaces/ens20.200
if [ $? -ne 0 ]; then handle_error "mkdir -p /etc/net/ifaces/ens20.200" $?; fi

# 4. Создание файла options для VLAN
echo "4. Создание файла options для VLAN..."
touch /etc/net/ifaces/ens20.200/options
if [ $? -ne 0 ]; then handle_error "touch /etc/net/ifaces/ens20.200/options" $?; fi

# 5. Настройка VLAN ens20.200
echo "5. Настройка VLAN ens20.200..."
cat <<EOF > /etc/net/ifaces/ens20.200/options
TYPE=vlan
HOST=ens20
VID=200
DISABLED=no
BOOTPROTO=dhcp
EOF
if [ $? -ne 0 ]; then handle_error "cat <<EOF > /etc/net/ifaces/ens20.200/options" $?; fi

# -----------------------------------------------------------------------------
# Вывод сводки об ошибках
# -----------------------------------------------------------------------------

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