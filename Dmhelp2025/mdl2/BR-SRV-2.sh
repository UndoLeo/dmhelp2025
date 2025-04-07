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

# Настройка доменного контроллера Samba на BR-SRV

# 1. Настройка DNS
echo "Настройка DNS..."
vim /etc/resolv.conf <<EOF
nameserver 8.8.8.8
EOF
if [ $? -ne 0 ]; then handle_error "vim /etc/resolv.conf" $?; fi
# Изменение файла /etc/resolv.conf для указания DNS-сервера Google. Временное решение.

# 2. Обновление списка пакетов и установка Samba DC
echo "Обновление списка пакетов и установка Samba DC..."
apt-get update
if [ $? -ne 0 ]; then handle_error "apt-get update" $?; fi
apt-get install task-samba-dc -y
if [ $? -ne 0 ]; then handle_error "apt-get install task-samba-dc -y" $?; fi

# 3. Настройка DNS (снова, указываем на локальный контроллер после установки)
echo "Настройка DNS (указываем на локальный контроллер)..."
vim /etc/resolv.conf <<EOF
nameserver 192.168.1.2
EOF
if [ $? -ne 0 ]; then handle_error "vim /etc/resolv.conf" $?; fi
# Изменение файла /etc/resolv.conf для указания локального DNS-сервера (после установки Samba DC).

# 4. Удаление существующего smb.conf и настройка имени хоста
echo "Удаление существующего smb.conf и настройка имени хоста..."
rm -rf /etc/samba/smb.conf
if [ $? -ne 0 ]; then handle_error "rm -rf /etc/samba/smb.conf" $?; fi
hostname -f
# Убедитесь, что имя хоста правильно установлено в системе перед выполнением следующей команды.
#hostnamectl set-hostname br-srv.au-team.irpo; exec bash
echo "Установка hostname"
hostnamectl set-hostname br-srv.au-team.irpo
if [ $? -ne 0 ]; then handle_error "hostnamectl set-hostname br-srv.au-team.irpo" $?; fi
echo "Exec bash"
exec bash

# 5. Редактирование /etc/hosts
echo "Редактирование /etc/hosts..."
vim /etc/hosts <<EOF
192.168.4.2	br-srv.au-team.irpo
EOF
if [ $? -ne 0 ]; then handle_error "vim /etc/hosts" $?; fi
# Добавление записи в /etc/hosts для разрешения имени хоста в локальной сети.

# 6. Provisioning Samba DC (ВНИМАНИЕ: ИНТЕРАКТИВНЫЙ ПРОЦЕСС)
echo "Provisioning Samba DC..."
samba-tool domain provision --realm=AU-TEAM.IRPO --domain=AU-TEAM --server-role=dc --dns-backend=SAMBA_INTERNAL --adminpass='P@ssw0rd'
if [ $? -ne 0 ]; then handle_error "samba-tool domain provision" $?; fi
# ВАЖНО: В процессе provisioning вам будет предложено ввести пароль администратора.  Укажите сложный пароль.

# 7. Копирование krb5.conf и включение Samba
echo "Копирование krb5.conf и включение Samba..."
mv -f /var/lib/samba/private/krb5.conf /etc/krb5.conf
if [ $? -ne 0 ]; then handle_error "mv -f /var/lib/samba/private/krb5.conf /etc/krb5.conf" $?; fi
systemctl enable samba
if [ $? -ne 0 ]; then handle_error "systemctl enable samba" $?; fi

# 8. Настройка cron (ВНИМАНИЕ: ОТКРОЕТСЯ РЕДАКТОР CRONTAB)
echo "Настройка cron..."
export EDITOR=vim
crontab -e
if [ $? -ne 0 ]; then handle_error "crontab -e" $?; fi
#  Добавьте следующие строки в crontab:
#  @reboot /bin/systemctl restart network
#  @reboot /bin/systemctl restart samba

# 9. Перезагрузка сервера
echo "Перезагрузка сервера..."
reboot
if [ $? -ne 0 ]; then handle_error "reboot" $?; fi

# 10. Проверка информации о домене
echo "Проверка информации о домене..."
samba-tool domain info 127.0.0.1
if [ $? -ne 0 ]; then handle_error "samba-tool domain info 127.0.0.1" $?; fi

# 11. Добавление пользователей (примеры)
echo "Добавление пользователей..."
samba-tool user add user1.hq P@ssw0rd
if [ $? -ne 0 ]; then handle_error "samba-tool user add user1.hq P@ssw0rd" $?; fi
samba-tool user add user2.hq P@ssw0rd
if [ $? -ne 0 ]; then handle_error "samba-tool user add user2.hq P@ssw0rd" $?; fi
samba-tool user add user3.hq P@ssw0rd
if [ $? -ne 0 ]; then handle_error "samba-tool user add user3.hq P@ssw0rd" $?; fi
samba-tool user add user4.hq P@ssw0rd
if [ $? -ne 0 ]; then handle_error "samba-tool user add user4.hq P@ssw0rd" $?; fi
samba-tool user add user5.hq P@ssw0rd
if [ $? -ne 0 ]; then handle_error "samba-tool user add user5.hq P@ssw0rd" $?; fi

# 12. Добавление группы hq
echo "Добавление группы hq..."
samba-tool group add hq
if [ $? -ne 0 ]; then handle_error "samba-tool group add hq" $?; fi

# 13. Добавление пользователей в группу hq
echo "Добавление пользователей в группу hq..."
samba-tool group addmembers hq user1.hq,user2.hq,user3.hq,user4.hq,user5.hq
if [ $? -ne 0 ]; then handle_error "samba-tool group addmembers hq user1.hq,user2.hq,user3.hq,user4.hq,user5.hq" $?; fi

# 14. Подключение репозитория ALT Linux и установка sudo-samba-schema
echo "Подключение репозитория ALT Linux и установка sudo-samba-schema..."
#apt-repo add rpm http://altrepo.ru/local-p10 noarch local-p10  #  Эта команда может потребовать ручной установки apt-repo
apt-get update
if [ $? -ne 0 ]; then handle_error "apt-get update" $?; fi
apt-get install sudo-samba-schema -y
if [ $? -ne 0 ]; then handle_error "apt-get install sudo-samba-schema -y" $?; fi

# 15. Применение схемы sudo (ВНИМАНИЕ: ИНТЕРАКТИВНЫЙ ПРОЦЕСС)
echo "Применение схемы sudo..."
sudo-schema-apply
if [ $? -ne 0 ]; then handle_error "sudo-schema-apply" $?; fi
# В процессе применения схемы вам будет предложено ввести пароль администратора Samba.

# 16. Создание правила sudo
echo "Создание правила sudo..."
create-sudo-rule
if [ $? -ne 0 ]; then handle_error "create-sudo-rule" $?; fi
# В процессе создания правила вам будет предложено ввести параметры правила.
# Имя правила    : prava_hq
# sudoHost       : ALL
# sudoCommand    : /bin/cat
# sudoUser       : %hq

# 17. Загрузка пользователей из CSV
echo "Загрузка пользователей из CSV..."
curl -L https://bit.ly/3C1nEYz > /root/users.zip
if [ $? -ne 0 ]; then handle_error "curl -L https://bit.ly/3C1nEYz > /root/users.zip" $?; fi
unzip /root/users.zip
if [ $? -ne 0 ]; then handle_error "unzip /root/users.zip" $?; fi
mv /root/Users.csv /opt/Users.csv
if [ $? -ne 0 ]; then handle_error "mv /root/Users.csv /opt/Users.csv" $?; fi

# 18. Импорт пользователей
echo "Импорт пользователей..."
vim /root/import <<EOF
#!/bin/bash
csv_file="/opt/Users.csv"
while IFS=";" read -r firstName lastName role phone ou street zip city country password; do
  if [ "\$firstName" == "First Name" ]; then
    continue
  fi
  username="\${firstName,,}.\${lastName,,}"
  sudo samba-tool user add "\$username" 123qweR%
done < "\$csv_file"
EOF
if [ $? -ne 0 ]; then handle_error "vim /root/import" $?; fi
chmod +x /root/import
if [ $? -ne 0 ]; then handle_error "chmod +x /root/import" $?; fi
bash /root/import
if [ $? -ne 0 ]; then handle_error "bash /root/import" $?; fi

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