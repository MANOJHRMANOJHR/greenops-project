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

echo "Building latest application image through Docker Compose..."
docker compose build $TARGET

echo "Starting/recreating inactive target container: $TARGET"
docker compose up -d --no-deps --force-recreate $TARGET

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

echo "Health check passed. Switching Nginx traffic to $TARGET..."

cp $TARGET_CONF nginx/active.conf
docker exec nginx nginx -t
docker exec nginx nginx -s reload

echo "Traffic switched to $TARGET"

echo "Stopping previous live container $CURRENT without removing it..."
docker stop $CURRENT || true

echo "Deployment successful."
echo "Active container: $TARGET"
echo "Stopped previous container retained: $CURRENT"