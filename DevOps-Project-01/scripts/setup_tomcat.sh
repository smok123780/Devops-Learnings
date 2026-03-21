#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset
set -o xtrace

# Install and configure Apache Tomcat on Debian/Ubuntu.
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
