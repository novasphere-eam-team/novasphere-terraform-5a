#!/bin/bash
apt-get update -y
apt-get install -y nginx awscli
echo "<h1>NovaSphere - $(hostname)</h1>" > /var/www/html/index.html
mkdir -p /etc/novasphere
aws ssm get-parameter --name /novasphere/prod/db_password --with-decryption --query Parameter.Value --output text --region us-east-1 > /etc/novasphere/app.conf
chmod 0640 /etc/novasphere/app.conf
systemctl enable nginx
systemctl start nginx
