#!/bin/bash

echo "Starting safe resource cleanup..."

echo "Removing stopped containers except app_blue and app_green..."

for container in $(docker ps -a --filter "status=exited" --format "{{.Names}}"); do
  if [ "$container" != "app_blue" ] && [ "$container" != "app_green" ]; then
    echo "Removing stopped container: $container"
    docker rm "$container" || true
  else
    echo "Keeping blue-green rollback container: $container"
  fi
done

echo "Removing dangling images..."
docker image prune -f

echo "Removing unused networks..."
docker network prune -f

echo "Safe cleanup completed."