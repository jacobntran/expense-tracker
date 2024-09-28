#!/bin/bash

apt update

apt install apache2 nodejs npm git unzip -y

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

unzip awscliv2.zip

./aws/install

rm -rf aws awscliv2.zip

mkdir /opt/expense-tracker

cd /opt/expense-tracker

GIT_TOKEN=$(aws ssm get-parameter --name "/expense-tracker/git-token" --with-decryption --query "Parameter.Value" --output text)

git init

git remote add origin https://github.com/jacobntran/expense-tracker.git

git config core.sparseCheckout true

echo "code/" >> .git/info/sparse-checkout

git pull origin main

cd code

mv index.html script.js style.css /var/www/html

LB_DNS_NAME=$(aws elbv2 describe-load-balancers --names "expense-tracker-lb" --query "LoadBalancers[0].DNSName" --output text)

sed -i "s|<INSERT_LB_DNS_NAME}>|$LB_DNS_NAME|g" /var/www/html/script.js

RDS_USER=$(aws ssm get-parameter --name "/expense-tracker/rds-user" --with-decryption --query "Parameter.Value" --output text)

RDS_PASSWORD=$(aws ssm get-parameter --name "/expense-tracker/rds-password" --with-decryption --query "Parameter.Value" --output text)

RDS_DB_NAME=$(aws ssm get-parameter --name "/expense-tracker/rds-db-name" --with-decryption --query "Parameter.Value" --output text)

RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier expense-tracker-rds-instance --query "DBInstances[0].Endpoint.Address" --output text)

sed -i "s|yourUsername|$RDS_USER|g" server.js

sed -i "s|yourPassword|$RDS_PASSWORD|g" server.js

sed -i "s|yourDatabaseName|$RDS_DB_NAME|g" server.js

sed -i "s|yourRDSHost|$RDS_ENDPOINT|g" server.js

npm install express body-parser cors pg

node server.js &