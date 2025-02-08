#!/bin/bash

YC_ZONE="ru-central1-a"              # Зона доступности
YC_NETWORK_NAME="my-network"         # Имя облачной сети
YC_SUBNET_NAME="my-subnet"           # Имя подсети
YC_SUBNET_CIDR="192.168.1.0/24"      # CIDR подсети
YC_VM_NAME="my-vm"                   # Имя виртуальной машины
YC_VM_CORES="2"                      # Количество ядер
YC_VM_MEMORY="4GB"                   # Объем памяти
YC_VM_DISK_SIZE="20GB"               # Размер диска
SSH_KEY_NAME="my-ssh-key"            # Имя SSH-ключа
SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"  # Путь для сохранения SSH-ключей
DOCKER_IMAGE="nginx"                 # Docker-образ для веб-приложения
DOCKER_PORT="80"                     # Порт, который будет открыт на виртуальной машине

echo "Создание облачной сети $YC_NETWORK_NAME..."
yc vpc network create --name $YC_NETWORK_NAME

echo "Создание подсети $YC_SUBNET_NAME в сети $YC_NETWORK_NAME..."
yc vpc subnet create \
  --name $YC_SUBNET_NAME \
  --zone $YC_ZONE \
  --range $YC_SUBNET_CIDR \
  --network-name $YC_NETWORK_NAME

echo "Генерация SSH-ключей..."
ssh-keygen -t rsa -b 2048 -f $SSH_KEY_PATH -N "" -C "yc-user"
SSH_PUBLIC_KEY=$(cat "${SSH_KEY_PATH}.pub")

echo "Создание виртуальной машины $YC_VM_NAME..."
yc compute instance create \
  --name $YC_VM_NAME \
  --zone $YC_ZONE \
  --network-interface subnet-name=$YC_SUBNET_NAME,nat-ip-version=ipv4 \
  --create-boot-disk size=$YC_VM_DISK_SIZE \
  --cores $YC_VM_CORES \
  --memory $YC_VM_MEMORY \
  --ssh-key "${SSH_KEY_PATH}.pub"

VM_IP=$(yc compute instance get $YC_VM_NAME --format json | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address')
echo "Виртуальная машина создана. Публичный IP: $VM_IP"

echo "Установка Docker и запуск контейнера с веб-приложением на виртуальной машине..."
ssh -i $SSH_KEY_PATH yc-user@$VM_IP << EOF
  sudo apt-get update
  sudo apt-get install -y docker.io
  sudo docker run -d -p $DOCKER_PORT:80 --name my-web-app $DOCKER_IMAGE
EOF

echo -e "\nДля подключения к виртуальной машине по SSH выполните команду:"
echo "ssh -i $SSH_KEY_PATH yc-user@$VM_IP"

echo -e "\nВеб-приложение доступно по адресу:"
echo "http://$VM_IP"