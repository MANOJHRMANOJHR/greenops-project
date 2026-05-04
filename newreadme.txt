greenops-project\.github\workflows\deploy.yml
name: GreenOps Production CI/CD

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: self-hosted

    steps:
    - uses: actions/checkout@v3

    - name: Blue-Green Deploy
      run: bash scripts/deploy-bluegreen.sh

    - name: Resource Optimization Cleanup
      run: bash scripts/cleanup.sh

greenops-project\app\templates\index.html
<!DOCTYPE html>
<html>
<head>
<title>GreenOps</title>
<style>
body { background:#111; color:#fff; text-align:center; font-family:sans-serif; }
button { padding:10px; margin-top:20px; }
</style>
</head>
<body>
<h1>🚀 GreenOps Production System</h1>
<h2 id="status">Checking...</h2>
<button onclick="check()">Check Health</button>

<script>
async function check(){
 let r=await fetch('/health');
 let d=await r.json();
 document.getElementById("status").innerText =
 d.status==="healthy"?"✅ Healthy":"❌ Failed";
}

</script>
</body>
</html>

greenops-project\app\app.py
from flask import Flask, jsonify, render_template
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

REQUESTS = Counter('requests_total', 'Total Requests')

@app.route("/")
def home():
    REQUESTS.inc()
    return render_template("index.html")

@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200

@app.route("/metrics")
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=3000)

greenops-project\app\Dockerfile
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python","app.py"]

greenops-project\app\requirements.txt
flask
prometheus_client

greenops-project\monitoring\prometheus.yml
global:
  scrape_interval: 5s

scrape_configs:
  - job_name: 'app'
    static_configs:
      - targets: ['app_blue:3000','app_green:3000']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

greenops-project\nginx\blue.conf
server {
    listen 80;
    location / {
        proxy_pass http://app_blue:3000;
    }
}

greenops-project\nginx\green.conf
server {
    listen 80;
    location / {
        proxy_pass http://app_green:3000;
    }
}

greenops-project\nginx\nginx.conf
events {}

http {
    include /etc/nginx/conf.d/*.conf;
}

greenops-project\scripts\cleanup.sh
#!/bin/bash

echo ""
echo "Removing stopped containers..."
docker container prune -f

echo ""
echo "Removing unused Docker images..."
docker image prune -f

echo ""
echo "Removing unused Docker volumes..."
docker volume prune -f

echo ""
echo "Removing unused Docker networks..."
docker network prune -f

echo ""
echo "Resource optimization completed successfully."

greenops-project\scripts\deploy-bluegreen.sh
#!/bin/bash

set -e

echo "Detecting current live container..."

CURRENT=$(docker exec nginx cat /etc/nginx/conf.d/default.conf | grep -o "app_blue\|app_green" | head -1)

echo "Current live container: $CURRENT"

if [ "$CURRENT" = "app_blue" ]; then
  TARGET="app_green"
  TARGET_PORT="3002"
  TARGET_CONF="nginx/green.conf"
else
  TARGET="app_blue"
  TARGET_PORT="3001"
  TARGET_CONF="nginx/blue.conf"
fi

echo "New deployment target: $TARGET"

echo "Building new Docker image..."
docker build -t myapp ./app

echo "Stopping old inactive container if exists..."
docker stop $TARGET || true
docker rm $TARGET || true

echo "Starting new $TARGET container..."
docker run -d --name $TARGET -p $TARGET_PORT:3000 myapp

echo "Waiting for application to start..."
sleep 10

echo "Checking health..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$TARGET_PORT/health)

echo "Health status: $STATUS"

if [ "$STATUS" != "200" ]; then
  echo "Health check failed. Rolling back..."
  docker stop $TARGET || true
  docker rm $TARGET || true
  exit 1
fi

echo "Health check passed. Switching Nginx traffic..."
docker cp $TARGET_CONF nginx:/etc/nginx/conf.d/default.conf
docker exec nginx nginx -s reload

echo "Deployment successful. Traffic switched to $TARGET"

greenops-project\docker-compose.yml
services:
  app_blue:
    build: ./app
    container_name: app_blue
    ports:
      - "3001:3000"

  app_green:
    build: ./app
    container_name: app_green
    ports:
      - "3002:3000"

  nginx:
    image: nginx
    container_name: nginx
    ports:
      - "3000:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/blue.conf:/etc/nginx/conf.d/default.conf

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro

  prometheus:
    image: prom/prometheus
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana
    ports:
      - "3003:3000"