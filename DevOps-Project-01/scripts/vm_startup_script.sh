#!/bin/bash
set -o errexit  # make your script exit when a command fails
set -o pipefail # to exit when the status of the last command that threw a non-zero exit code is returned
set -o nounset  # to exit when your script tries to use undeclared variables
set -o xtrace   # to trace what gets executed. Useful for debugging

# Install and configure Nginx

METADATA_BACKEND_UPSTREAM="$(curl -fs -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/BACKEND_UPSTREAM" || true)"
BACKEND_UPSTREAM="${BACKEND_UPSTREAM:-${METADATA_BACKEND_UPSTREAM:-127.0.0.1:8080}}"
SERVER_NAME="${SERVER_NAME:-_}"

echo "Installing Nginx"
sudo apt-get update
sudo apt-get install -y nginx

echo "Disabling stock nginx default site (otherwise default_server serves Welcome to nginx)"
sudo rm -f /etc/nginx/sites-enabled/default

echo "Creating Nginx application config"
sudo tee /etc/nginx/conf.d/app.conf > /dev/null <<EOF
upstream backend {
    server ${BACKEND_UPSTREAM};
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name ${SERVER_NAME};

    # Used by GCP HTTP health checks — must not depend on backend being up
    location = /health {
        access_log off;
        default_type text/plain;
        return 200 'ok\n';
    }

    # Backend deploys the WAR as ROOT.war — app is at / on Tomcat
    location / {
        proxy_pass http://backend/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /static/ {
        proxy_pass http://backend/static/;
    }
}
EOF

echo "Validating and restarting Nginx"
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx
sudo systemctl --no-pager --full status nginx
