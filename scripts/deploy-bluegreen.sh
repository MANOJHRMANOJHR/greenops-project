#!/bin/bash

set -e

echo "Detecting current live container..."

CURRENT=$(cat nginx/active.conf | grep -o "app_blue\|app_green" | head -1)

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

echo "Removing old inactive target container if it exists..."
docker rm -f $TARGET || true

echo "Building fresh image for $TARGET..."
docker compose build --no-cache $TARGET

echo "Starting fresh $TARGET container..."
docker compose up -d --no-deps $TARGET

echo "Waiting for $TARGET to start..."
sleep 10

echo "Checking health of $TARGET..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$TARGET_PORT/health)

echo "Health status: $STATUS"

if [ "$STATUS" != "200" ]; then
  echo "Health check failed. Stopping failed $TARGET container..."
  docker stop $TARGET || true
  echo "Rollback complete. Traffic remains on $CURRENT"
  exit 1
fi

echo "Updating host active nginx config to $TARGET..."
cp $TARGET_CONF nginx/active.conf

echo "Checking nginx mounted config..."
NGINX_CONF_TARGET=$(docker exec nginx cat /etc/nginx/conf.d/default.conf | grep -o "app_blue\|app_green" | head -1 || true)

echo "Nginx container currently sees: $NGINX_CONF_TARGET"

if [ "$NGINX_CONF_TARGET" != "$TARGET" ]; then
  echo "Nginx is not seeing updated active.conf. Recreating nginx container..."
  docker rm -f nginx || true
  docker compose up -d nginx
  sleep 5
fi

echo "Testing Nginx config after update..."
docker exec nginx nginx -t

echo "Reloading Nginx..."
docker exec nginx nginx -s reload

echo "Traffic switched to $TARGET"

echo "Stopping previous live container $CURRENT without removing it..."
docker stop $CURRENT || true

echo "Deployment successful."
echo "Active container: $TARGET"
echo "Stopped previous container retained: $CURRENT"