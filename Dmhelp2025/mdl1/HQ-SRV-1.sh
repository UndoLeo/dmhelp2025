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
hostnamectl set-hostname hq-srv.au-team.irpo
if [ $? -ne 0 ]; then handle_error "hostnamectl set-hostname hq-srv.au-team.irpo" $?; fi
exec bash
if [ $? -ne 0 ]; then handle_error "exec bash" $?; fi

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
# Настройка VLAN
# -----------------------------------------------------------------------------

# 7. Создание директории для VLAN ens20.100
echo "7. Создание директории для VLAN ens20.100..."
mkdir -p /etc/net/ifaces/ens20.100
if [ $? -ne 0 ]; then handle_error "mkdir -p /etc/net/ifaces/ens20.100" $?; fi

# 8. Создание файла options для VLAN
echo "8. Создание файла options для VLAN..."
touch /etc/net/ifaces/ens20.100/options
if [ $? -ne 0 ]; then handle_error "touch /etc/net/ifaces/ens20.100/options" $?; fi

# 9. Настройка VLAN ens20.100
echo "9. Настройка VLAN ens20.100..."
cat <<EOF > /etc/net/ifaces/ens20.100/options
TYPE=vlan
HOST=ens19
VID=100
DISABLED=no
EOF
if [ $? -ne 0 ]; then handle_error "cat <<EOF > /etc/net/ifaces/ens20.100/options" $?; fi

# 10. Настройка IP-адреса и маршрута для VLAN
echo "10. Настройка IP-адреса и маршрута для VLAN..."

echo "address 192.168.1.2/26" >  /etc/net/ifaces/ens20.100/options
if [ $? -ne 0 ]; then handle_error "echo \"address 192.168.1.2/26\" >  /etc/net/ifaces/ens20.100/options" $?; fi

echo "gateway 192.168.1.1" >> /etc/net/ifaces/ens20.100/options
if [ $? -ne 0 ]; then handle_error "echo \"gateway 192.168.1.1\" >> /etc/net/ifaces/ens20.100/options" $?; fi

# -----------------------------------------------------------------------------
# Настройка DNS
# -----------------------------------------------------------------------------

# 11. Отключение bind
echo "11. Отключение bind..."
systemctl disable --now bind
if [ $? -ne 0 ]; then handle_error "systemctl disable --now bind" $?; fi

# 12. Настройка DNS
echo "12. Настройка DNS..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf
if [ $? -ne 0 ]; then handle_error "echo nameserver 8.8.8.8 > /etc/resolv.conf" $?; fi

# 13. Установка и включение dnsmasq
echo "13. Установка и включение dnsmasq..."
apt-get update
if [ $? -ne 0 ]; then handle_error "apt-get update" $?; fi
apt-get install dnsmasq -y
if [ $? -ne 0 ]; then handle_error "apt-get install dnsmasq -y" $?; fi
systemctl enable --now dnsmasq.service
if [ $? -ne 0 ]; then handle_error "systemctl enable --now dnsmasq.service" $?; fi

# 14. Настройка dnsmasq.conf
echo "14. Настройка dnsmasq.conf..."
cat <<EOF > /etc/dnsmasq.conf
no-resolv
domain=au-team.irpo
server=8.8.8.8
interface=*
address=/hq-rtr.au-team.irpo/192.168.1.1
ptr-record=1.1.168.192.in-addr.arpa,hq-rtr.au-team.irpo
cname=moodle.au-team.irpo,hq-rtr.au-team.irpo
cname=wiki.au-team.irpo,hq-rtr.au-team.irpo

address=/br-rtr.au-team.irpo/192.168.4.1

address=/hq-srv.au-team.irpo/192.168.1.2
ptr-record=2.1.168.192.in-addr.arpa,hq-srv.au-team.irpo

address=/hq-cli.au-team.irpo/192.168.2.11
ptr-record=11.2.168.192.in-addr.arpa,hq-cli.au-team.irpo

address=/br-srv.au-team.irpo/192.168.4.2
EOF
if [ $? -ne 0 ]; then handle_error "cat <<EOF > /etc/dnsmasq.conf" $?; fi

# 15. Добавление записи в /etc/hosts
echo "15. Добавление записи в /etc/hosts..."
echo "192.168.1.1 hq-rtr.au-team.irpo" >> /etc/hosts
if [ $? -ne 0 ]; then handle_error "echo \"192.168.1.1 hq-rtr.au-team.irpo\" >> /etc/hosts" $?; fi

# 16. Перезапуск dnsmasq
echo "16. Перезапуск dnsmasq..."
systemctl restart dnsmasq.service
if [ $? -ne 0 ]; then handle_error "systemctl restart dnsmasq.service" $?; fi

# -----------------------------------------------------------------------------
# Настройка SSH
# -----------------------------------------------------------------------------

# 17. Установка openssh-server
echo "17. Установка openssh-server..."
apt install openssh-server -y
if [ $? -ne 0 ]; then handle_error "apt install openssh-server -y" $?; fi

# 18. Настройка sshd_config
echo "18. Настройка sshd_config..."
cat << EOF > /etc/ssh/sshd_config
Port 2024
MaxAuthTries 2
AllowUsers sshuser
PermitRootLogin no
Banner /root/banner
EOF
if [ $? -ne 0 ]; then handle_error "cat << EOF > /etc/ssh/sshd_config" $?; fi

# 19. Создание баннера
echo "19. Создание баннера..."
echo "Authorized access only" > /root/banner
if [ $? -ne 0 ]; then handle_error "echo \"Authorized access only\" > /root/banner" $?; fi

# 20. Перезапуск службы SSH
echo "20. Перезапуск службы SSH..."
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