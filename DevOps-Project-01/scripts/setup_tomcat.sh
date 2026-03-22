#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset
set -o xtrace

# Install and configure Apache Tomcat on Debian/Ubuntu.
TOMCAT_VERSION="${TOMCAT_VERSION:-9.0.116}"
TOMCAT_INSTALL_DIR="${TOMCAT_INSTALL_DIR:-/opt/tomcat}"
JAVA_HOME_PATH="${JAVA_HOME_PATH:-/usr/lib/jvm/java-17-openjdk-amd64}"

MD_BASE="http://metadata.google.internal/computeMetadata/v1"
MD_HDR=( -H "Metadata-Flavor: Google" )

read_metadata_or_env() {
  local key="$1"
  local env_fallback="$2"
  local from_meta=""
  from_meta="$(curl -fs "${MD_HDR[@]}" "${MD_BASE}/instance/attributes/${key}" 2>/dev/null || true)"
  if [[ -n "$from_meta" ]]; then
    printf '%s' "$from_meta"
    return
  fi
  local v
  v="$(eval "printf '%s' \"\${${key}:-}\"")"
  if [[ -n "$v" ]]; then
    printf '%s' "$v"
    return
  fi
  printf '%s' "$env_fallback"
}

echo "Installing Java runtime and required tools"
sudo apt-get update
sudo apt-get install -y openjdk-17-jdk curl python3

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

AR_PROJECT_ID="$(read_metadata_or_env AR_PROJECT_ID "")"
AR_LOCATION="$(read_metadata_or_env AR_LOCATION "")"
AR_REPOSITORY="$(read_metadata_or_env AR_REPOSITORY "")"
APP_MAVEN_GROUP_ID="$(read_metadata_or_env APP_MAVEN_GROUP_ID "com.devopsrealtime")"
APP_MAVEN_ARTIFACT_ID="$(read_metadata_or_env APP_MAVEN_ARTIFACT_ID "dptweb")"
APP_MAVEN_VERSION="$(read_metadata_or_env APP_MAVEN_VERSION "1.0")"

if [[ -n "$AR_PROJECT_ID" && -n "$AR_LOCATION" && -n "$AR_REPOSITORY" ]]; then
  GROUP_PATH="${APP_MAVEN_GROUP_ID//.//}"
  WAR_FILE="${APP_MAVEN_ARTIFACT_ID}-${APP_MAVEN_VERSION}.war"
  WAR_URL="https://${AR_LOCATION}-maven.pkg.dev/${AR_PROJECT_ID}/${AR_REPOSITORY}/${GROUP_PATH}/${APP_MAVEN_ARTIFACT_ID}/${APP_MAVEN_VERSION}/${WAR_FILE}"

  echo "Fetching OAuth token for Artifact Registry"
  ACCESS_TOKEN="$(
    curl -fs "${MD_HDR[@]}" \
      "${MD_BASE}/instance/service-accounts/default/token?scopes=https://www.googleapis.com/auth/cloud-platform" \
      | python3 -c 'import sys, json; print(json.load(sys.stdin)["access_token"])'
  )"

  echo "Downloading WAR from Artifact Registry (Maven coordinates ${APP_MAVEN_GROUP_ID}:${APP_MAVEN_ARTIFACT_ID}:${APP_MAVEN_VERSION})"
  TMP_WAR="/tmp/${WAR_FILE}"
  rm -f "$TMP_WAR"
  download_ok=0
  for attempt in 1 2 3; do
    if curl -fSL --connect-timeout 30 \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -o "$TMP_WAR" \
      "$WAR_URL"; then
      download_ok=1
      break
    fi
    echo "Download attempt $attempt failed, retrying..."
    sleep "$((attempt * 5))"
    ACCESS_TOKEN="$(
      curl -fs "${MD_HDR[@]}" \
        "${MD_BASE}/instance/service-accounts/default/token?scopes=https://www.googleapis.com/auth/cloud-platform" \
        | python3 -c 'import sys, json; print(json.load(sys.stdin)["access_token"])'
    )"
  done
  if [[ "$download_ok" -ne 1 ]] || [[ ! -f "$TMP_WAR" ]]; then
    cat >&2 <<EOF
ERROR: WAR not found (HTTP 404 or download failed): ${WAR_URL}
Tomcat is running but the app was not deployed. Publish the WAR to Artifact Registry, then redeploy backends or copy the file into /opt/tomcat/webapps/ on each VM.

  From repo root:  ./scripts/build_app.sh
  Or:             cd Java-Login-App && mvn deploy

Verify the artifact exists:
  gcloud artifacts packages list --repository=${AR_REPOSITORY} --location=${AR_LOCATION} --project=${AR_PROJECT_ID}
EOF
  else
  # Deploy as ROOT.war so the app is at "/" (matches nginx proxy_pass http://backend/;)
  sudo rm -rf "${TOMCAT_INSTALL_DIR}/webapps/ROOT" "${TOMCAT_INSTALL_DIR}/webapps/ROOT.war" \
    "${TOMCAT_INSTALL_DIR}/webapps/${WAR_FILE}" \
    "${TOMCAT_INSTALL_DIR}/webapps/${APP_MAVEN_ARTIFACT_ID}-${APP_MAVEN_VERSION}"
  sudo mv "$TMP_WAR" "${TOMCAT_INSTALL_DIR}/webapps/ROOT.war"
  sudo chown tomcat:tomcat "${TOMCAT_INSTALL_DIR}/webapps/ROOT.war"
  echo "Deployed WAR as webapps/ROOT.war (context path /)"
  fi
else
  echo "Skipping WAR download: AR_PROJECT_ID, AR_LOCATION, and AR_REPOSITORY must be set (instance metadata or environment)."
fi
