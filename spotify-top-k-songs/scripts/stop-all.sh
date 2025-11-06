#!/bin/bash

# stop-all.sh - Stop all services

echo "🛑 Stopping Spotify Top K Songs..."

# Stop Spring applications (ports 8083 and 8084)
echo "📱 Stopping Spring applications..."
pkill -f "spring-boot:run -pl api" || true
pkill -f "spring-boot:run -pl consumer" || true

# Also kill any Java processes from this project
pkill -f "spotify-top-k-songs" || true

# Stop Docker infrastructure
echo "🐳 Stopping infrastructure..."
docker-compose down

echo "✅ All services stopped!"