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

# Настройка файлового хранилища и Chrony на HQ-SRV

# 1. Настройка RAID5 (если необходимо, убедитесь, что диски /dev/sdb, /dev/sdc, /dev/sdd не содержат важные данные)
echo "Настройка RAID5..."
lsblk
if [ $? -ne 0 ]; then handle_error "lsblk" $?; fi
mdadm --create /dev/md0 --level=5 --raid-devices=3 /dev/sd[b-d]
if [ $? -ne 0 ]; then handle_error "mdadm --create /dev/md0 --level=5 --raid-devices=3 /dev/sd[b-d]" $?; fi
cat /proc/mdstat
if [ $? -ne 0 ]; then handle_error "cat /proc/mdstat" $?; fi

# 2. Сохранение конфигурации RAID
echo "Сохранение конфигурации RAID..."
mdadm --detail --scan > /etc/mdadm.conf
if [ $? -ne 0 ]; then handle_error "mdadm --detail --scan > /etc/mdadm.conf" $?; fi

# 3. Создание раздела на RAID-массиве
echo "Создание раздела на RAID-массиве..."
fdisk /dev/md0 <<EOF
n
p
1


w
EOF
if [ $? -ne 0 ]; then handle_error "fdisk /dev/md0" $?; fi
# ВАЖНО:  Убедитесь, что правильно выбрали параметры для раздела.
#После команды fdisk /dev/md0 вводим команды указанные выше поочереди

# 4. Создание файловой системы
echo "Создание файловой системы..."
mkfs.ext4 /dev/md0p1
if [ $? -ne 0 ]; then handle_error "mkfs.ext4 /dev/md0p1" $?; fi

# 5. Добавление записи в /etc/fstab для автоматического монтирования
echo "Добавление записи в /etc/fstab..."
vim /etc/fstab <<EOF
/dev/md0p1	/raid5	ext4	defaults	0	0
EOF
if [ $? -ne 0 ]; then handle_error "vim /etc/fstab" $?; fi

# 6. Создание точки монтирования и монтирование файловой системы
echo "Создание точки монтирования и монтирование файловой системы..."
mkdir /raid5
if [ $? -ne 0 ]; then handle_error "mkdir /raid5" $?; fi
mount -a
if [ $? -ne 0 ]; then handle_error "mount -a" $?; fi

# 7. Установка NFS-server
echo "Установка NFS-server..."
apt-get update
if [ $? -ne 0 ]; then handle_error "apt-get update" $?; fi
apt-get install nfs-kernel-server -y
if [ $? -ne 0 ]; then handle_error "apt-get install nfs-kernel-server -y" $?; fi

# 8. Создание директории NFS и настройка прав
echo "Создание директории NFS и настройка прав..."
mkdir /raid5/nfs
if [ $? -ne 0 ]; then handle_error "mkdir /raid5/nfs" $?; fi
chown 99:99 /raid5/nfs
if [ $? -ne 0 ]; then handle_error "chown 99:99 /raid5/nfs" $?; fi
chmod 777 /raid5/nfs
if [ $? -ne 0 ]; then handle_error "chmod 777 /raid5/nfs" $?; fi

# 9. Настройка /etc/exports
echo "Настройка /etc/exports..."
vim /etc/exports <<EOF
/raid5/nfs 192.168.2.0/28(rw,sync,no_subtree_check)
EOF
if [ $? -ne 0 ]; then handle_error "vim /etc/exports" $?; fi

# 10. Экспорт файловой системы NFS
echo "Экспорт файловой системы NFS..."
exportfs -a
if [ $? -ne 0 ]; then handle_error "exportfs -a" $?; fi
exportfs -v
if [ $? -ne 0 ]; then handle_error "exportfs -v" $?; fi

# 11. Включение и перезапуск NFS
echo "Включение и перезапуск NFS..."
systemctl enable nfs-kernel-server
if [ $? -ne 0 ]; then handle_error "systemctl enable nfs-kernel-server" $?; fi
systemctl restart nfs-kernel-server
if [ $? -ne 0 ]; then handle_error "systemctl restart nfs-kernel-server" $?; fi

# 12. Настройка Chrony
echo "Настройка Chrony..."
apt-get update
if [ $? -ne 0 ]; then handle_error "apt-get update" $?; fi
apt-get install chrony -y
if [ $? -ne 0 ]; then handle_error "apt-get install chrony -y" $?; fi
systemctl status chrony
if [ $? -ne 0 ]; then handle_error "systemctl status chrony" $?; fi
timedatectl
if [ $? -ne 0 ]; then handle_error "timedatectl" $?; fi

# 13. Редактирование chrony.conf
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

# 14. Включение и перезапуск Chrony
echo "Включение и перезапуск Chrony..."
systemctl enable --now chrony
if [ $? -ne 0 ]; then handle_error "systemctl enable --now chrony" $?; fi
systemctl restart chrony
if [ $? -ne 0 ]; then handle_error "systemctl restart chrony" $?; fi

# 15. Отключение NTP
echo "Отключение NTP..."
timedatectl set-ntp 0
if [ $? -ne 0 ]; then handle_error "timedatectl set-ntp 0" $?; fi
timedatectl
if [ $? -ne 0 ]; then handle_error "timedatectl" $?; fi

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