# Weather Dashboard Deployment

This repository contains a single‐script deployment of the Weather Dashboard (backend + frontend) on a fresh Ubuntu/Raspbian server, secured via HTTPS with a self‐signed CA.

## Contents

- `secure-weather-deploy.sh` — all-in-one interactive deploy script  
- _(this README)_

## Usage

1. **Clone** or copy the repo onto your target server.  
2. **Make executable**:  
   ```bash
   chmod +x secure-weather-deploy.sh
   ```  
3. **Run** the script as root:  
   ```bash
   sudo ./secure-weather-deploy.sh
   ```  
   You’ll be prompted for your WeatherLink **API Key**, **Secret**, and **Station ID**.  
4. After completion, the script will display the path to the generated CA cert (e.g. `/etc/ssl/certs/weather-dashboard-ca.crt`).  
   - **Install** this CA certificate on any client machine to trust `https://weather.lan`.

## What it does

1. Installs required packages (Node.js, build tools, OpenSSL, etc.).  
2. Prompts for WeatherLink credentials and writes them to `.env`.  
3. Generates a self‐signed CA and a server certificate (with SAN `weather.lan`).  
4. Scaffolds & installs the Express backend, serving both HTTP→HTTPS redirect and the HTTPS API + SPA.  
5. Scaffolds, builds, and deploys the React/Tailwind frontend (Vite).  
6. Registers and starts a systemd service on ports **80** and **443**.

## Access

- **Dashboard**: `https://weather.lan`  
- **CA certificate**: as printed by the script (install in your OS/browser)

## License

MIT © Will Curtis
