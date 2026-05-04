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