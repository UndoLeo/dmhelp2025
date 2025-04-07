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
hostnamectl set-hostname br-srv.au-team.irpo
if [ $? -ne 0 ]; then handle_error "hostnamectl set-hostname br-srv.au-team.irpo" $?; fi

# 2. Настройка временной зоны
echo "2. Настройка временной зоны..."
timedatectl set-timezone Asia/Vladivostok
if [ $? -ne 0 ]; then handle_error "timedatectl set-timezone Asia/Vladivostok" $?; fi

# -----------------------------------------------------------------------------
# Настройка пользователя sshuser
# -----------------------------------------------------------------------------

# 3. Создание пользователя sshuser
echo "3. Создание пользователя sshuser..."
useradd sshuser -u 1010
if [ $? -ne 0 ]; then handle_error "useradd sshuser -u 1010" $?; fi

# 4. Установка пароля для sshuser
echo "4. Установка пароля для sshuser..."
echo "sshuser:P@ssw0rd" | chpasswd
if [ $? -ne 0 ]; then handle_error "echo \"sshuser:P@ssw0rd\" | chpasswd" $?; fi
echo "Пароль для sshuser P@ssw0rd"  # Предупреждение о пароле (удалите в production)

# 5. Разрешение sudo для группы wheel
echo "5. Разрешение sudo для группы wheel..."
sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
if [ $? -ne 0 ]; then handle_error "sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers" $?; fi

# 6. Добавление пользователя sshuser в группу wheel
echo "6. Добавление пользователя sshuser в группу wheel..."
usermod -aG wheel sshuser
if [ $? -ne 0 ]; then handle_error "usermod -aG wheel sshuser" $?; fi

# -----------------------------------------------------------------------------
# Настройка сети
# -----------------------------------------------------------------------------

# 7. Настройка статического IP-адреса для ens19
echo "7. Настройка статического IP-адреса для ens19..."
cat <<EOF > /etc/net/ifaces/ens19/options
BOOTPROTO=static
TYPE=eth
CONFIG_IPV4=yes
DISABLED=no
NM_CONTROLLED=no
EOF
if [ $? -ne 0 ]; then handle_error "cat <<EOF > /etc/network/interfaces" $?; fi

# 8. Настройка IP-адреса и маршрута по умолчанию
echo "8. Настройка IP-адреса и маршрута по умолчанию..."
echo "address 192.168.4.2/27" >> /etc/net/ifaces/ens19/options
if [ $? -ne 0 ]; then handle_error "echo \"address 192.168.4.2/27\" >> /etc/network/interfaces" $?; fi
echo "gateway 192.168.4.1" >> /etc/net/ifaces/ens19/options
if [ $? -ne 0 ]; then handle_error "echo \"gateway 192.168.4.1\" >> /etc/network/interfaces" $?; fi

# 9. Перезапуск сетевой службы
echo "9. Перезапуск сетевой службы..."
systemctl restart networking
if [ $? -ne 0 ]; then handle_error "systemctl restart networking" $?; fi

# 10. Вывод информации об IP-адресе
echo "10. Вывод информации об IP-адресе..."
ip -c a
if [ $? -ne 0 ]; then handle_error "ip -c a" $?; fi

# -----------------------------------------------------------------------------
# Настройка SSH
# -----------------------------------------------------------------------------

# 11. Установка openssh-server
echo "11. Установка openssh-server..."
apt update
if [ $? -ne 0 ]; then handle_error "apt update" $?; fi

apt install openssh-server -y
if [ $? -ne 0 ]; then handle_error "apt install openssh-server -y" $?; fi

# 12. Настройка sshd_config
echo "12. Настройка sshd_config..."
cat << EOF > /etc/ssh/sshd_config
Port 2024
MaxAuthTries 2
AllowUsers sshuser
PermitRootLogin no
Banner /root/banner
EOF
if [ $? -ne 0 ]; then handle_error "cat << EOF > /etc/ssh/sshd_config" $?; fi

# 13. Создание баннера
echo "13. Создание баннера..."
echo "Authorized access only" > /root/banner
if [ $? -ne 0 ]; then handle_error "echo \"Authorized access only\" > /root/banner" $?; fi

# 14. Перезапуск службы SSH
echo "14. Перезапуск службы SSH..."
systemctl restart sshd.service
if [ $? -ne 0 ]; then handle_error "systemctl restart sshd.service" $?; fi
systemctl enable --now sshd.service
if [ $? -ne 0 ]; then handle_error "systemctl enable --now sshd.service" $?; fi

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