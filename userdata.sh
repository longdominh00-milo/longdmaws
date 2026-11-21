#!/bin/bash
set -e

# Update system
dnf update -y

# Install Node.js 22, and Git
dnf install -y nodejs22 git

# Clone application
cd /home/ec2-user
git clone -b lab14-cicd https://github.com/longdominh00-milo/longdmaws.git
cd longdmaws/app
# mv -f index-base.js index.js

# Create .env file (update DB_HOST with your database endpoint)
cat > .env <<EOF
PORT=3001
EOF

# Install dependencies
npm install

# Set permissions
chown -R ec2-user:ec2-user /home/ec2-user/longdmaws

# Create systemd service
cat > /etc/systemd/system/demo-app.service <<'EOFS'
[Unit]
Description=AWS Architecting Demo Application - LongDM
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/longdmaws/app
EnvironmentFile=/home/ec2-user/longdmaws/app/.env
ExecStart=/usr/bin/node index.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=demo-app

[Install]
WantedBy=multi-user.target
EOFS

# Install CodeDeploy agent
dnf install -y ruby wget nodejs22 npm git
cd /tmp
wget https://aws-codedeploy-ap-southeast-2.s3.ap-southeast-2.amazonaws.com/latest/install
chmod +x ./install
./install auto
systemctl enable codedeploy-agent
systemctl start codedeploy-agent

# Start service
systemctl daemon-reload
systemctl enable demo-app
systemctl start demo-app
systemctl status demo-app --no-pager