#!/bin/bash

set -e

echo "🐳 Starting OPTIMIZED infrastructure..."

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml not found!"
    exit 1
fi

# Stop existing services
echo "🛑 Stopping existing services..."
docker-compose down

# Clean up Docker resources
echo "🧹 Cleaning up Docker resources..."
docker system prune -f

# Start infrastructure with optimized services
echo "🚀 Starting optimized Kafka, Redis, Cassandra..."
docker-compose up -d zookeeper kafka redis cassandra kafka-ui

# Initialize Cassandra
echo "📊 Initializing Cassandra..."
if [ -f "init-cassandra.cql" ]; then
    MAX_WAIT=180
    INTERVAL=5
    elapsed=0

    # Get the container id for the cassandra service
    CID=$(docker-compose ps -q cassandra)

    echo "🔎 Waiting for cassandra container to appear..."
    while [ -z "$CID" ]; do
        sleep $INTERVAL
        elapsed=$((elapsed + INTERVAL))
        CID=$(docker-compose ps -q cassandra)
        if [ $elapsed -ge $MAX_WAIT ]; then
            echo "❌ Timeout waiting for cassandra container to start"
            echo "📊 Current container status:"
            docker-compose ps
            echo "🔍 Cassandra logs:"
            docker-compose logs cassandra | tail -n 50
            exit 1
        fi
    done
    echo "✅ Found cassandra container: $CID"

    echo "⏳ Waiting for Cassandra to accept CQL connections (timeout ${MAX_WAIT}s)..."
    elapsed=0
    until docker exec -i "$CID" cqlsh -e "describe keyspaces" >/dev/null 2>&1; do
        echo "⏳ Waiting for Cassandra to be ready... (elapsed: ${elapsed}s) (optimized wait: ~30-60s)"
        sleep $INTERVAL
        elapsed=$((elapsed + INTERVAL))

        if [ $elapsed -ge $MAX_WAIT ]; then
            echo "❌ Timeout waiting for Cassandra to be ready. Last logs:"
            docker logs "$CID" 2>&1 | tail -n 100
            echo "💡 Tip: Try increasing MAX_WAIT or check Cassandra configuration"
            exit 1
        fi
    done

    echo "➡️ Applying CQL from init-cassandra.cql..."
    if ! docker exec -i "$CID" cqlsh < init-cassandra.cql >/dev/null 2>&1; then
        echo "❌ Failed applying CQL. Last cassandra logs:"
        docker logs "$CID" 2>&1 | tail -n 100
        exit 1
    fi
    echo "✅ Cassandra initialized successfully"
else
    echo "⚠️  Cassandra initialization script not found (init-cassandra.cql)"
    echo "💡 Creating basic keyspace for testing..."

    CID=$(docker-compose ps -q cassandra)
    if [ -n "$CID" ]; then
        sleep 10
        docker exec -i "$CID" cqlsh -e "CREATE KEYSPACE IF NOT EXISTS my_keyspace WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};"
        echo "✅ Created basic keyspace: my_keyspace"
    fi
fi

# Check service health
echo "🔍 Checking service health..."
sleep 5

echo "📋 Service status:"
docker-compose ps

echo "📊 Resource usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | head -n 6

echo ""
echo "🎉 OPTIMIZED INFRASTRUCTURE READY!"
echo "   📊 Kafka:        localhost:9092"
echo "   🔴 Redis:        localhost:6379"
echo "   💾 Cassandra:    localhost:9042"
echo "   🌐 Kafka UI:     http://localhost:8080"
echo ""
echo "🚀 Services should start faster with reduced resource limits"