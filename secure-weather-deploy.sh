#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# deploy_pi_secure.sh
# Interactive, SSL-enabled full deploy (self-signed CA & cert) for Weather Dashboard
# -----------------------------------------------------------------------------
set -euo pipefail

log(){ printf "\e[1;32m▶ %s\e[0m\n" "$*"; }
fail(){ printf "\e[1;31m❌ %s\e[0m\n" "$*"; exit 1; }

# Ask for WeatherLink credentials interactively
read -p "WeatherLink API Key: " WL_API_KEY
read -p "WeatherLink API Secret: " WL_API_SECRET
read -p "WeatherLink Station ID: "  WL_STATION_ID

# --- Paths & Names ---
BACKEND_DIR="/opt/weather-dashboard"
FRONTEND_DIR="/opt/weather-dash-frontend"
SERVICE="weather-dashboard-secure"

CA_KEY="/etc/ssl/private/weather-dashboard-ca.key"
CA_CERT="/etc/ssl/certs/weather-dashboard-ca.crt"
SSL_KEY="/etc/ssl/private/weather-dashboard.key"
SSL_CSR="/etc/ssl/certs/weather-dashboard.csr"
SSL_CERT="/etc/ssl/certs/weather-dashboard.crt"

# 1) System packages
log "Installing prerequisites..."
apt-get update -y
apt-get install -y curl build-essential jq openssl

# 2) Node.js 20 LTS
if ! command -v node >/dev/null || ! node -v | grep -q "v20\."; then
  log "Installing Node.js 20.x..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
else
  log "Node $(node -v) already installed"
fi

# 3) Self-signed CA
log "Creating self-signed CA..."
mkdir -p "$(dirname "$CA_KEY")" "$(dirname "$CA_CERT")"
openssl genrsa -out "$CA_KEY" 4096
openssl req -x509 -new -nodes -key "$CA_KEY" -sha256 -days 3650 \
  -subj "/CN=WeatherDashboard-CA" \
  -out "$CA_CERT"

# 4) Server cert with SAN for weather.lan
log "Generating server certificate..."
openssl genrsa -out "$SSL_KEY" 2048
cat > /tmp/ssl.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = weather.lan
EOF
openssl req -new -key "$SSL_KEY" \
  -subj "/CN=weather.lan" \
  -out "$SSL_CSR" \
  -config /tmp/ssl.cnf
openssl x509 -req -in "$SSL_CSR" -CA "$CA_CERT" -CAkey "$CA_KEY" -CAcreateserial \
  -out "$SSL_CERT" -days 3650 -sha256 \
  -extensions v3_req -extfile /tmp/ssl.cnf
rm /tmp/ssl.cnf

# 5) Scaffold backend
log "Scaffolding backend..."
rm -rf "$BACKEND_DIR"
mkdir -p "$BACKEND_DIR"
cd "$BACKEND_DIR"

# server.js (omitted for brevity – identical to prior, reads env & SSL vars)
cat > server.js <<'EOF'
<...server.js content as before, unchanged except it reads process.env.WL_API_KEY etc...>
EOF

cat > package.json <<'EOF'
{"name":"weather-dashboard-backend","version":"1.0.0","type":"module",
 "dependencies":{"express":"^4.18.2","node-fetch":"^3.3.2","node-cache":"^5.1.2","dotenv":"^16.4.1"}}
EOF

# Write .env
cat > .env <<EOF
WL_API_KEY=$WL_API_KEY
WL_API_SECRET=$WL_API_SECRET
WL_STATION_ID=$WL_STATION_ID
SSL_KEY=$SSL_KEY
SSL_CERT=$SSL_CERT
EOF

npm install

# 6) Scaffold & build frontend
log "Scaffolding frontend..."
rm -rf "$FRONTEND_DIR"
mkdir -p "$FRONTEND_DIR/src/components"
cd "$FRONTEND_DIR"

# package.json, vite.config.ts, tailwind.config.js, etc.
cat > package.json <<'EOF'
<...as before...>
EOF

# Copy your Dashboard.tsx inline (omitted here)

npm install
npm run build

# 7) Deploy dist
log "Deploying frontend build..."
rm -rf "$BACKEND_DIR/dist"
cp -r "$FRONTEND_DIR/dist" "$BACKEND_DIR/dist"

# 8) systemd service
cat > /etc/systemd/system/${SERVICE}.service <<EOF
[Unit]
Description=Secure Weather Dashboard HTTPS Backend & SPA
After=network.target

[Service]
Type=simple
WorkingDirectory=$BACKEND_DIR
EnvironmentFile=$BACKEND_DIR/.env
ExecStart=$(which node) server.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

log "Starting service..."
systemctl daemon-reload
systemctl enable --now $SERVICE
systemctl status $SERVICE --no-pager

log "CA certificate available at: $CA_CERT"
log "✅ Secure deployment complete! Visit https://weather.lan"
