#!/bin/bash

echo "========== APP BLUE LOGS =========="
docker logs --tail 20 app_blue

echo ""
echo "========== APP GREEN LOGS =========="
docker logs --tail 20 app_green

echo ""
echo "========== NGINX LOGS =========="
docker logs --tail 20 nginx