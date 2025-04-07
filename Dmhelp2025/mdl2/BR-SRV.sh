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

# Настройка Ansible и Docker на BR-SRV

# 1. Удаление репозитория ALT Linux
echo "Удаление репозитория ALT Linux..."
#apt-repo rm rpm http://altrepo.ru/local-p10   #  Эта команда может потребовать ручной установки apt-repo
#apt-get update

# 2. Установка Ansible
echo "Установка Ansible..."
apt-get update
if [ $? -ne 0 ]; then handle_error "apt-get update" $?; fi
apt-get install ansible -y
if [ $? -ne 0 ]; then handle_error "apt-get install ansible -y" $?; fi

# 3. Редактирование /etc/ansible/hosts
echo "Редактирование /etc/ansible/hosts..."
vim /etc/ansible/hosts <<EOF
[all]
hq-srv ansible_host=192.168.1.2 ansible_port=2024
hq-cli ansible_host=192.168.2.11 ansible_port=2024
hq-rtr ansible_host=192.168.1.1 ansible_port=22
br-rtr ansible_host=192.168.4.1 ansible_port=22

[all:vars]
ansible_user=sshuser
ansible_ssh_pass=P@ssw0rd
ansible_connection=ssh
ansible_ssh_private_key_file=/home/sshuser/.ssh/id_rsa
EOF
if [ $? -ne 0 ]; then handle_error "vim /etc/ansible/hosts" $?; fi
# Добавьте записи для ваших серверов, замените IP-адреса и порты на ваши значения.

# 4. Редактирование ansible.cfg
echo "Редактирование ansible.cfg..."
vim /etc/ansible/ansible.cfg <<EOF
[defaults]
interpreter_python=auto_silent
ansible_python_interpreter=/usr/bin/python3
host_key_checking = False
EOF
if [ $? -ne 0 ]; then handle_error "vim /etc/ansible/ansible.cfg" $?; fi

# 5. Установка Docker
echo "Установка Docker..."
apt-get update
if [ $? -ne 0 ]; then handle_error "apt-get update" $?; fi
apt-get install docker.io docker-compose-plugin -y
if [ $? -ne 0 ]; then handle_error "apt-get install docker.io docker-compose-plugin -y" $?; fi
systemctl enable --now docker
if [ $? -ne 0 ]; then handle_error "systemctl enable --now docker" $?; fi
systemctl status docker
if [ $? -ne 0 ]; then handle_error "systemctl status docker" $?; fi

# 6. Загрузка образов Docker
echo "Загрузка образов Docker..."
docker pull mediawiki
if [ $? -ne 0 ]; then handle_error "docker pull mediawiki" $?; fi
docker pull mariadb
if [ $? -ne 0 ]; then handle_error "docker pull mariadb" $?; fi

# 7. Создание docker-compose.yml
echo "Создание docker-compose.yml..."
vim /root/wiki.yml <<EOF
services:
  mariadb:
    image: mariadb
    container_name: mariadb
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: P@ssw0rd
      MYSQL_DATABASE: mediawiki
      MYSQL_USER: wiki
      MYSQL_PASSWORD: P@ssw0rd
    volumes: [ mariadb_data:/var/lib/mysql ]
  wiki:
    image: mediawiki
    container_name: wiki
    restart: always
    environment:
      MEDIAWIKI_DB_HOST: mariadb
      MEDIAWIKI_DB_USER: wiki
      MEDIAWIKI_DB_PASSWORD: P@ssw0rd
      MEDIAWIKI_DB_NAME: mediawiki
    ports:
      - "8080:80"
    #volumes: [ /root/mediawiki/LocalSettings.php:/var/www/html/LocalSettings.php ]
volumes:
  mariadb_data:
EOF
if [ $? -ne 0 ]; then handle_error "vim /root/wiki.yml" $?; fi

# 8. Запуск Docker Compose
echo "Запуск Docker Compose..."
docker compose -f /root/wiki.yml up -d
if [ $? -ne 0 ]; then handle_error "docker compose -f /root/wiki.yml up -d" $?; fi

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