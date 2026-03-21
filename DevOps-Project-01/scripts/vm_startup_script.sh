#!/bin/bash
set -o errexit  # make your script exit when a command fails
set -o pipefail # to exit when the status of the last command that threw a non-zero exit code is returned
set -o nounset  # to exit when your script tries to use undeclared variables
set -o xtrace   # to trace what gets executed. Useful for debugging

# Install and configure Nginx

METADATA_BACKEND_UPSTREAM="$(curl -fs -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/BACKEND_UPSTREAM" || true)"
BACKEND_UPSTREAM="${BACKEND_UPSTREAM:-${METADATA_BACKEND_UPSTREAM:-127.0.0.1:8080}}"
SERVER_NAME="${SERVER_NAME:-_}"
STATIC_ASSETS_URL="${STATIC_ASSETS_URL:-https://storage.googleapis.com/your-static-assets-bucket}"

echo "Installing Nginx"
sudo apt-get update
sudo apt-get install -y nginx

echo "Creating Nginx application config"
sudo tee /etc/nginx/conf.d/app.conf > /dev/null <<EOF
upstream backend {
    server ${BACKEND_UPSTREAM};
}

server {
    listen 80;
    server_name ${SERVER_NAME};

    location / {
        proxy_pass http://backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /static/ {
        proxy_pass ${STATIC_ASSETS_URL};
    }
}
EOF

echo "Validating and restarting Nginx"
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx
sudo systemctl --no-pager --full status nginx


# Install and configure Apache Tomcat

TOMCAT_VERSION="${TOMCAT_VERSION:-9.0.95}"
TOMCAT_INSTALL_DIR="${TOMCAT_INSTALL_DIR:-/opt/tomcat}"
JAVA_HOME_PATH="${JAVA_HOME_PATH:-/usr/lib/jvm/java-11-openjdk-amd64}"

echo "Installing Java runtime and required tools"
sudo apt-get update
sudo apt-get install -y openjdk-11-jdk curl

echo "Creating tomcat user if missing"
if ! id -u tomcat >/dev/null 2>&1; then
    sudo useradd -m -d "$TOMCAT_INSTALL_DIR" -U -s /bin/false tomcat
fi

echo "Installing Tomcat $TOMCAT_VERSION"
TMP_TARBALL="/tmp/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
curl -fsSL "https://dlcdn.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz" -o "$TMP_TARBALL"
sudo mkdir -p "$TOMCAT_INSTALL_DIR"
sudo tar -xzf "$TMP_TARBALL" -C "$TOMCAT_INSTALL_DIR" --strip-components=1
sudo chown -R tomcat:tomcat "$TOMCAT_INSTALL_DIR"
sudo chmod +x "$TOMCAT_INSTALL_DIR"/bin/*.sh
rm -f "$TMP_TARBALL"

echo "Configuring systemd service"
sudo tee /etc/systemd/system/tomcat.service > /dev/null <<EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
Environment=JAVA_HOME=$JAVA_HOME_PATH
Environment=CATALINA_PID=$TOMCAT_INSTALL_DIR/temp/tomcat.pid
Environment=CATALINA_HOME=$TOMCAT_INSTALL_DIR
Environment=CATALINA_BASE=$TOMCAT_INSTALL_DIR
Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'
Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'
ExecStart=$TOMCAT_INSTALL_DIR/bin/startup.sh
ExecStop=$TOMCAT_INSTALL_DIR/bin/shutdown.sh
User=tomcat
Group=tomcat
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "Starting and enabling Tomcat service"
sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl restart tomcat
sudo systemctl --no-pager --full status tomcat
