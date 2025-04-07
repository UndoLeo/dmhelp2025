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
hostnamectl set-hostname br-rtr.au-team.irpo
if [ $? -ne 0 ]; then handle_error "hostnamectl set-hostname br-rtr.au-team.irpo" $?; fi
exec bash
if [ $? -ne 0 ]; then handle_error "exec bash" $?; fi

# 2. Настройка временной зоны
echo "2. Настройка временной зоны..."
timedatectl set-timezone Asia/Vladivostok
if [ $? -ne 0 ]; then handle_error "timedatectl set-timezone Asia/Vladivostok" $?; fi

# -----------------------------------------------------------------------------
# Настройка пользователя net_admin
# -----------------------------------------------------------------------------

# 3. Создание пользователя net_admin
echo "3. Создание пользователя net_admin..."
useradd -m net_admin
if [ $? -ne 0 ]; then handle_error "useradd -m net_admin" $?; fi

# 4. Установка пароля для net_admin
echo "4. Установка пароля для net_admin..."
echo "net_admin:P@ssw0rd" | chpasswd
if [ $? -ne 0 ]; then handle_error "echo \"net_admin:P@ssw0rd\" | chpasswd" $?; fi
echo "Пароль для net_admin P@ssw0rd"  # Предупреждение о пароле (удалите в production)

# 5. Разрешение sudo для пользователя net_admin
echo "5. Разрешение sudo для пользователя net_admin..."
echo "net_admin ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/net_admin
if [ $? -ne 0 ]; then handle_error "echo \"net_admin ALL=(ALL:ALL) NOPASSWD: ALL\" > /etc/sudoers.d/net_admin" $?; fi
chmod 0440 /etc/sudoers.d/net_admin
if [ $? -ne 0 ]; then handle_error "chmod 0440 /etc/sudoers.d/net_admin" $?; fi

# -----------------------------------------------------------------------------
# Настройка сети
# -----------------------------------------------------------------------------

# 6. Настройка сети
echo "6. Настройка сети..."
cat <<EOF > /etc/network/interfaces
auto lo
iface lo inet loopback

auto ens19
iface ens19 inet static
    address 172.16.5.2/28
    gateway 172.16.5.1

auto ens20
iface ens20 inet static
    address 192.168.4.1/27

auto gre1
iface gre1 inet tunnel
    address 10.10.10.2 pointopoint 10.10.10.1
    netmask 255.255.255.252
    ttl 255
    endpoint 172.16.4.2
    local 172.16.5.2
EOF
if [ $? -ne 0 ]; then handle_error "cat <<EOF > /etc/network/interfaces" $?; fi

# 7. Перезапуск сетевой службы
echo "7. Перезапуск сетевой службы..."
systemctl restart networking
if [ $? -ne 0 ]; then handle_error "systemctl restart networking" $?; fi

# 8. Вывод информации об IP-адресе
echo "8. Вывод информации об IP-адресе..."
ip -c a
if [ $? -ne 0 ]; then handle_error "ip -c a" $?; fi

# -----------------------------------------------------------------------------
# Включаем ip-forwarding
# -----------------------------------------------------------------------------

# 9. Включаем ip-forwarding
echo "9. Включаем ip-forwarding..."
sysctl -w net.ipv4.ip_forward=1
if [ $? -ne 0 ]; then handle_error "sysctl -w net.ipv4.ip_forward=1" $?; fi
sysctl -p
if [ $? -ne 0 ]; then handle_error "sysctl -p" $?; fi

# -----------------------------------------------------------------------------
# Настройка NAT
# -----------------------------------------------------------------------------

# 10. Настройка NAT
echo "10. Настройка NAT..."
iptables -t nat -A POSTROUTING -s 192.168.4.0/27 -o ens19 -j MASQUERADE
if [ $? -ne 0 ]; then handle_error "iptables -t nat -A POSTROUTING -s 192.168.4.0/27 -o ens19 -j MASQUERADE" $?; fi
iptables-save > /root/rules
if [ $? -ne 0 ]; then handle_error "iptables-save > /root/rules" $?; fi

# 11. Настройка автозагрузки правил iptables (CRON)
echo "11. Настройка автозагрузки правил iptables (CRON)..."
echo "Запишите в файл следующие @reboot /sbin/iptables-restore < /root/rules"
sleep 10

export EDITOR=nano
crontab -e
if [ $? -ne 0 ]; then handle_error "crontab -e" $?; fi
# записать в файл следующие
# @reboot /sbin/iptables-restore < /root/rules
Echo "проверите iptables -t nat -L"

# -----------------------------------------------------------------------------
# Настройка OSPF
# -----------------------------------------------------------------------------

# 12. Настройка OSPF
echo "12. Настройка OSPF..."

# Закомментируем исходные репозитории
sed -i 's/^deb/#deb/' /etc/apt/sources.list
if [ $? -ne 0 ]; then handle_error "sed -i 's/^deb/#deb/' /etc/apt/sources.list" $?; fi

# Добавим репозиторий buster
echo "deb [trusted=yes] http://deb.debian.org/debian buster main" >> /etc/apt/sources.list
if [ $? -ne 0 ]; then handle_error "echo \"deb [trusted=yes] http://deb.debian.org/debian buster main\" >> /etc/apt/sources.list" $?; fi

# Настройка DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
if [ $? -ne 0 ]; then handle_error "echo \"nameserver 8.8.8.8\" > /etc/resolv.conf" $?; fi

# Обновление списков пакетов
apt update
if [ $? -ne 0 ]; then handle_error "apt update" $?; fi

# Установка FRR
apt install frr -y
if [ $? -ne 0 ]; then handle_error "apt install frr -y" $?; fi

# Включение OSPFd
sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons
if [ $? -ne 0 ]; then handle_error "sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons" $?; fi

# Перезапуск FRR
systemctl restart frr
if [ $? -ne 0 ]; then handle_error "systemctl restart frr" $?; fi

# Настройка OSPF через vtysh
echo "Настройка OSPF через vtysh..."
vtysh -c "configure terminal" \
      -c "router ospf" \
      -c "network 10.10.10.0/30 area 0" \
      -c "network 192.168.4.0/27 area 0" \
      -c "interface gre1" \
      -c "ip ospf authentication message-digest" \
      -c "ip ospf message-digest-key 1 md5 P@ssw0rd" \
      -c "end" \
      -c "write memory"
if [ $? -ne 0 ]; then handle_error "vtysh OSPF configuration" $?; fi

# Откат изменений в репозиториях
sed -i 's/^deb [trusted=yes] http:\/\/deb.debian.org\/debian buster main/#deb [trusted=yes] http:\/\/deb.debian.org\/debian buster main/' /etc/apt/sources.list
if [ $? -ne 0 ]; then handle_error "sed -i 's/^deb [trusted=yes] http:\/\/deb.debian.org\/debian buster main/#deb [trusted=yes] http:\/\/deb.debian.org\/debian buster main/' /etc/apt/sources.list" $?; fi
sed -i 's/^#deb/deb/' /etc/apt/sources.list
if [ $? -ne 0 ]; then handle_error "sed -i 's/^#deb/deb/' /etc/apt/sources.list" $?; fi

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