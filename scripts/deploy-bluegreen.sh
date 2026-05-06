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
cp $TARGET_CONF nginx/active.conf
docker exec nginx nginx -s reload

echo "Deployment successful. Traffic switched to $TARGET"