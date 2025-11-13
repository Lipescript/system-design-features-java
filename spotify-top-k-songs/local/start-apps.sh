#!/bin/bash

echo "Cleaning previous builds..."
mvn clean

echo "Building both modules..."
mvn package -DskipTests

echo
echo "Starting API on port 8083..."
(cd api && java -jar target/*.jar --server.port=8083) > api.log 2>&1 &
API_PID=$!
echo "✅ API started with PID: $API_PID"

sleep 10

echo
echo "Starting Consumer on port 8084..."
# Use subshell to preserve directory context
(cd consumer && java -jar target/*.jar --server.port=8084) > consumer.log 2>&1 &
CONSUMER_PID=$!
echo "✅ Consumer started with PID: $CONSUMER_PID"

echo
echo "⏳ Waiting 25 seconds for services to start completely..."
sleep 25

echo
echo "=== Health Check ==="
echo -n "API (8083): "
curl -s http://localhost:8083/actuator/health >/dev/null && echo "✅ HEALTHY" || echo "❌ UNHEALTHY"

echo -n "Consumer (8084): "
curl -s http://localhost:8084/actuator/health >/dev/null && echo "✅ HEALTHY" || echo "❌ UNHEALTHY"

echo
echo "Services:"
echo "- API: http://localhost:8083"
echo "- Consumer: http://localhost:8084"
echo "- Logs: tail -f api.log or tail -f consumer.log"

# Function to cleanup on exit
cleanup() {
    echo
    echo "Stopping services..."
    kill $API_PID 2>/dev/null
    kill $CONSUMER_PID 2>/dev/null
    echo "Services stopped."
    exit 0
}

# Trap Ctrl+C
trap cleanup SIGINT

echo
echo "Press Ctrl+C to stop all services"
wait