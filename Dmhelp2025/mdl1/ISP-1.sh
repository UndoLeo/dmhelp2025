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
hostnamectl set-hostname ISP
if [ $? -ne 0 ]; then handle_error "hostnamectl set-hostname ISP" $?; fi
exec bash
if [ $? -ne 0 ]; then handle_error "exec bash" $?; fi

# 2. Настройка временной зоны
echo "2. Настройка временной зоны..."
timedatectl set-timezone Asia/Vladivostok
if [ $? -ne 0 ]; then handle_error "timedatectl set-timezone Asia/Vladivostok" $?; fi

# -----------------------------------------------------------------------------
# Настройка сети и маршрутизации
# -----------------------------------------------------------------------------

# 3. Настройка сети
echo "3. Настройка сети..."
cat <<EOF > /etc/network/interfaces
auto lo
iface lo inet loopback

auto ens19
iface ens19 inet dhcp

auto ens20
iface ens20 inet static
    address 172.16.4.1/28

auto ens21
iface ens21 inet static
    address 172.16.5.1/28
EOF
if [ $? -ne 0 ]; then handle_error "cat <<EOF > /etc/network/interfaces" $?; fi

# 4. Перезапуск сетевой службы
echo "4. Перезапуск сетевой службы..."
systemctl restart networking
if [ $? -ne 0 ]; then handle_error "systemctl restart networking" $?; fi

# 5. Вывод информации об IP-адресе
echo "5. Вывод информации об IP-адресе..."
ip -c a
if [ $? -ne 0 ]; then handle_error "ip -c a" $?; fi

# -----------------------------------------------------------------------------
# Настройка ip-forwarding
# -----------------------------------------------------------------------------

# 6. Настройка ip-forwarding
echo "6. Настройка ip-forwarding..."
sysctl -w net.ipv4.ip_forward=1
if [ $? -ne 0 ]; then handle_error "sysctl -w net.ipv4.ip_forward=1" $?; fi
sysctl -p
if [ $? -ne 0 ]; then handle_error "sysctl -p" $?; fi

# -----------------------------------------------------------------------------
# Настройка iptables
# -----------------------------------------------------------------------------

# 7. Проверка наличия iptables
echo "7. Проверка наличия iptables..."
iptables -V
if [ $? -ne 0 ]; then
  echo "iptables не установлен. Пожалуйста, установите iptables."
  errors+=("iptables не установлен")
else
  # 8. Настройка NAT
  echo "8. Настройка NAT..."
  iptables -t nat -A POSTROUTING -s 172.16.4.0/28 -o ens19 -j MASQUERADE
  if [ $? -ne 0 ]; then handle_error "iptables -t nat -A POSTROUTING -s 172.16.4.0/28 -o ens19 -j MASQUERADE" $?; fi
  iptables -t nat -A POSTROUTING -s 172.16.5.0/28 -o ens19 -j MASQUERADE
  if [ $? -ne 0 ]; then handle_error "iptables -t nat -A POSTROUTING -s 172.16.5.0/28 -o ens19 -j MASQUERADE" $?; fi
  iptables-save > /root/rules
  if [ $? -ne 0 ]; then handle_error "iptables-save > /root/rules" $?; fi

  # 9. Настройка автозагрузки правил iptables (CRON)
  echo "9. Настройка автозагрузки правил iptables (CRON)..."
  echo "Запишите в файл следующие @reboot /sbin/iptables-restore < /root/rules"
  sleep 10

  export EDITOR=nano
  crontab -e
  if [ $? -ne 0 ]; then handle_error "crontab -e" $?; fi
  # записать в файл следующие
  # @reboot /sbin/iptables-restore < /root/rules
  Echo "проверите iptables -t nat -L"
fi
# -----------------------------------------------------------------------------
# Завершение
# -----------------------------------------------------------------------------

# 10. Перезагрузка системы
echo "10. Перезагрузка системы..."
Echo "Перезагрзка будет выполнена через 5 секунд"
sleep 5
reboot
if [ $? -ne 0 ]; then handle_error "reboot" $?; fi

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