#!/bin/bash

echo "Starting GreenOps Runtime Watchdog..."

COOLDOWN_FILE="/tmp/greenops_runtime_rollback_done"

while true; do
  CURRENT=$(docker exec nginx cat /etc/nginx/conf.d/default.conf | grep -o "app_blue\|app_green" | head -1)

  if [ "$CURRENT" = "app_blue" ]; then
    CURRENT_PORT="3001"
    PREVIOUS="app_green"
    PREVIOUS_PORT="3002"
    PREVIOUS_CONF="nginx/green.conf"
  else
    CURRENT_PORT="3002"
    PREVIOUS="app_blue"
    PREVIOUS_PORT="3001"
    PREVIOUS_CONF="nginx/blue.conf"
  fi

  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$CURRENT_PORT/health)

  if [ "$STATUS" != "200" ]; then
    echo "Runtime failure detected in active container: $CURRENT"

    if [ -f "$COOLDOWN_FILE" ]; then
      echo "Rollback already performed for this failure. Skipping to avoid loop."
      sleep 5
      continue
    fi

    echo "Trying to start previous stable container: $PREVIOUS"
    docker start $PREVIOUS || true

    sleep 5

    PREVIOUS_RUNNING=$(docker ps --format '{{.Names}}' | grep -w "$PREVIOUS" || true)

    if [ -n "$PREVIOUS_RUNNING" ]; then
      PREVIOUS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PREVIOUS_PORT/health)

      if [ "$PREVIOUS_STATUS" = "200" ]; then
        echo "Previous stable container $PREVIOUS is healthy. Rolling back..."

        cp $PREVIOUS_CONF nginx/active.conf
        docker exec nginx nginx -s reload

        echo "Stopping failed active container $CURRENT without removing it..."
        docker stop $CURRENT || true

        touch "$COOLDOWN_FILE"

        echo "Runtime rollback completed. Traffic switched to $PREVIOUS"
      else
        echo "Previous container $PREVIOUS is running but unhealthy. No rollback performed."
      fi
    else
      echo "Previous stable container $PREVIOUS is not available. No rollback performed."
    fi
  else
    rm -f "$COOLDOWN_FILE"
  fi

  sleep 5
done