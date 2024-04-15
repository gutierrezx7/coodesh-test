#!/bin/bash

# Atualizar o sistema
echo "Atualizando o sistema..."
apt update && apt upgrade -y || { echo "Falha ao atualizar o sistema."; exit 1; }

# Instalar o Nginx
echo "Instalando o Nginx..."
apt install -y nginx || { echo "Falha ao instalar o Nginx."; exit 1; }

# Substituir a página padrão do Nginx pela sua página estática
echo "Substituindo a página padrão do Nginx..."
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html lang="pt-br">
<head>
    <meta charset="UTF-8">
    <title>Desafio Coodesh</title>
</head>
<body>
    <h1>Bem-vindo ao Desafio Coodesh!</h1>
    <p>Esta é uma página estática servida pelo Nginx em uma instância AWS EC2.</p>
</body>
</html>
EOF

# Instalar dependências necessárias e o Webmin
echo "Instalando o Webmin..."
cd /root || { echo "Falha ao mudar para o diretório /root."; exit 1; }
wget http://prdownloads.sourceforge.net/webadmin/webmin_1.979_all.deb || { echo "Falha ao baixar o Webmin."; exit 1; }
dpkg --install webmin_1.979_all.deb || apt-get install -f -y || { echo "Falha ao instalar o Webmin."; exit 1; }

# Configurar o firewall para permitir tráfego Web e Webmin
echo "Configurando o firewall..."
ufw allow 'Nginx Full' || { echo "Falha ao permitir o Nginx Full."; exit 1; }
ufw allow 10000 || { echo "Falha ao permitir a porta 10000."; exit 1; }
ufw --force enable || { echo "Falha ao habilitar o firewall."; exit 1; }

# Reiniciar o Nginx para aplicar as alterações
echo "Reiniciando o Nginx..."
systemctl restart nginx || { echo "Falha ao reiniciar o Nginx."; exit 1; }

# Instalar o agente CloudWatch
echo "Instalando o agente CloudWatch..."
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -O amazon-cloudwatch-agent.deb || { echo "Falha ao baixar o agente CloudWatch."; exit 1; }
dpkg -i -E ./amazon-cloudwatch-agent.deb || { echo "Falha ao instalar o agente CloudWatch."; exit 1; }

# Configurar o agente CloudWatch para coletar métricas e logs
echo "Configurando o agente CloudWatch..."
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "coodesh-syslog",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/auth.log",
            "log_group_name": "coodesh-authlog",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

# Iniciar o agente CloudWatch
echo "Iniciando o agente CloudWatch..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json || { echo "Falha ao iniciar o agente CloudWatch."; exit 1; }

echo "Script de configuração concluído com sucesso."
