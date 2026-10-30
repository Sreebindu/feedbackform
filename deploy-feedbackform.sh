#!/bin/bash
set -e

APP_NAME="feedbackform"
IMAGE_NAME="feedbackform:v1"
APP_DIR="$HOME/feedbackform"

echo "========================================"
echo " Step 1: Navigate to Application Directory"
echo "========================================"

cd "$APP_DIR" || {
    echo "ERROR: Application directory not found!"
    exit 1
}

echo "========================================"
echo " Step 2: Build Docker Image"
echo "========================================"

sudo docker build -t "$IMAGE_NAME" .

echo "========================================"
echo " Step 3: Verify Docker Image"
echo "========================================"

sudo docker images

echo "========================================"
echo " Step 4: Remove Existing Container (if any)"
echo "========================================"

if sudo docker ps -aq -f "name=^${APP_NAME}$" | grep -q .; then
    sudo docker rm -f "$APP_NAME"
fi

echo "========================================"
echo " Step 5: Launch Docker Container"
echo "========================================"

sudo docker run -d --name "$APP_NAME" --restart unless-stopped -p 80:80 "$IMAGE_NAME"

echo "========================================"
echo " Step 6: Verify Running Container"
echo "========================================"

sudo docker ps

echo "========================================"
echo " Step 7: Check Container Logs"
echo "========================================"

sudo docker logs "$APP_NAME"

echo "========================================"
echo " Step 8: Test Application Locally"
echo "========================================"

curl --fail --silent --show-error --retry 5 \
    --retry-delay 2 -I http://localhost

echo "========================================"
echo " Deployment Completed Successfully!"
echo "========================================"

echo "Application URL: http://localhost"
echo "For AWS EC2: http://<EC2-PUBLIC-IP>"
