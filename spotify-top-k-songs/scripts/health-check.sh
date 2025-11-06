#!/bin/bash
# health-check.sh - Check optimized infrastructure health

echo "🔍 Health Check - Optimized Infrastructure"

echo ""
echo "📦 Container Status:"
docker-compose ps

echo ""
echo "💾 Memory Usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.PIDs}}"

echo ""
echo "📈 Kafka Topics:"
KAFKA_CONTAINER=$(docker-compose ps -q kafka)
if [ -n "$KAFKA_CONTAINER" ]; then
    docker exec $KAFKA_CONTAINER kafka-topics --list --bootstrap-server localhost:9092 2>/dev/null || echo "⚠️  Kafka not ready"
else
    echo "❌ Kafka container not running"
fi

echo ""
echo "🔴 Redis Ping:"
REDIS_CONTAINER=$(docker-compose ps -q redis)
if [ -n "$REDIS_CONTAINER" ]; then
    docker exec $REDIS_CONTAINER redis-cli ping || echo "⚠️  Redis not ready"
else
    echo "❌ Redis container not running"
fi

echo ""
echo "💾 Cassandra Status:"
CASSANDRA_CONTAINER=$(docker-compose ps -q cassandra)
if [ -n "$CASSANDRA_CONTAINER" ]; then
    docker exec $CASSANDRA_CONTAINER nodetool status 2>/dev/null || echo "⚠️  Cassandra not ready"
else
    echo "💡 Cassandra not running (minimal mode)"
fi

echo "🔍 Application Health Check"
echo "==========================="

# Check API
echo -n "📡 API (8083): "
if curl -f -s http://localhost:8083/actuator/health > /dev/null 2>&1; then
    echo "✅ HEALTHY"
else
    echo "❌ UNHEALTHY"
fi

# Check Consumer
echo -n "📥 Consumer (8084): "
if curl -f -s http://localhost:8084/actuator/health > /dev/null 2>&1; then
    echo "✅ HEALTHY"
else
    echo "❌ UNHEALTHY"
fi

echo ""
echo "✅ Check completed at $(date +%H:%M:%S)"