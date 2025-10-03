#!/bin/bash

# ====================================================================
# PASSO 1: INTERAÇÃO COM O USUÁRIO (PRIMEIRO E MAIS IMPORTANTE)
# ====================================================================

# Define cores para melhor visualização
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}--- Configuração Dinâmica de Hostname ---${NC}"

# Pergunta e armazena a entrada na variável PRX_HOSTNAME
echo -e "${GREEN}Digite o nome do Proxy/Hostname seguindo o exemplo (Ex: Proxy-Nome):${NC}"
read PRX_HOSTNAME

# Adiciona uma verificação para garantir que algo foi digitado
if [ -z "$PRX_HOSTNAME" ]; then
    echo -e "${RED}ERRO: O nome do Hostname não pode ser vazio. Saindo.${NC}"
    exit 1
fi

echo -e "${GREEN}Hostname configurado para uso: ${PRX_HOSTNAME}${NC}"
echo "----------------------------------------------------"

# ====================================================================
# PASSO 2: EXECUÇÃO E CONFIGURAÇÃO
# ====================================================================

echo "Iniciando configuração de fuso horário e pacotes..."

timedatectl set-timezone America/Sao_Paulo
#
timedatectl status
#
date
#
# A variável é usada DIRETAMENTE aqui, pois o valor já está na memória
hostnamectl set-hostname $PRX_HOSTNAME
#
dnf install -y net-tools vim nano wget curl tcpdump telnet net-snmp-utils traceroute
#
echo "Instalando e configurando Docker..."

sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
yum update
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
#
echo '{
  "bip": "10.192.168.1/24",
  "default-address-pools": [
    { 
	"base": "10.192.176.0/18", 
	"size": 24
    }
  ]
}' | sudo tee /etc/docker/daemon.json
#

sudo iptables -t nat -F
systemctl restart docker
systemctl restart NetworkManager
docker swarm init
#
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
#
echo "Configurando Firewall..."
firewall-cmd --permanent --add-port=10050/tcp
firewall-cmd --permanent --add-port=10051/tcp
firewall-cmd --reload
#
echo "Criando usuário rootprx..."
useradd rootprx
usermod -a -G wheel rootprx
#
echo -e "${GREEN}Por favor, defina a senha para o usuário rootprx:${NC}"
passwd rootprx
#
echo "Instalando repositório Zabbix..."
rpm -Uvh https://repo.zabbix.com/zabbix/7.0/oracle/9/x86_64/zabbix-release-latest-7.0.el9.noarch.rpm
dnf clean all
#
echo "Baixando e configurando Docker-Compose para Zabbix..."
#
cd /tmp
wget https://raw.githubusercontent.com/msmello96/Docker/refs/heads/main/Proxy/docker-compose-ol.yml
mkdir -p /home/rootprx/docker
mv /tmp/docker-compose-ol.yml /var/opt/zabbix/docker-compose.yml
cd /var/opt/zabbix
#
echo "ZBX_SERVER_HOST=cmzabbix.gruponagix.com.br
ZBX_HOSTNAME=$PRX_HOSTNAME
ZBX_TLSCONNECT=psk
ZBX_TLSACCEPT=psk
ZBX_TLSPSKIDENTITY=zabbix-key
ZBX_TLSPSKFILE=/etc/zabbix/.zabbix-key.psk" > .env
#
sed -i 's/user: /user: root/' docker-compose.yml
sed -i 's#/home#/var/opt/zabbix/.zabbix-key.psk:/etc/zabbix/.zabbix-key.psk:ro#' docker-compose.yml
#
echo "Fazendo deploy do stack Docker Swarm..."
docker stack deploy -c /var/opt/zabbix/docker-compose.yml zabbix

echo -e "\n${GREEN}--- INSTALAÇÃO FINALIZADA COM SUCESSO! ---${NC}"
