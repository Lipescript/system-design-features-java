#!/bin/bash

# logs.sh - View logs for services

SERVICE="$1"

case "${SERVICE}" in
    "api")
        echo "📋 API logs:"
        lsof -Pi :8083 -sTCP:LISTEN -t | xargs -I {} ps -p {} -o pid,command
        ;;
    "consumer")
        echo "📋 Consumer logs:"
        lsof -Pi :8084 -sTCP:LISTEN -t | xargs -I {} ps -p {} -o pid,command
        ;;
    "kafka")
        echo "📋 Kafka logs:"
        docker-compose logs kafka
        ;;
    "cassandra")
        echo "📋 Cassandra logs:"
        docker-compose logs cassandra
        ;;
    "redis")
        echo "📋 Redis logs:"
        docker-compose logs redis
        ;;
    *)
        echo "Usage: ./scripts/logs.sh [api|consumer|kafka|cassandra|redis]"
        echo ""
        echo "Examples:"
        echo "  ./scripts/logs.sh api        # Show APP-API process info"
        echo "  ./scripts/logs.sh consumer        # Show APP-CONSUMER process info"
        echo "  ./scripts/logs.sh kafka      # Show Kafka logs"
        echo "  ./scripts/logs.sh cassandra  # Show Cassandra logs"
        ;;
esac