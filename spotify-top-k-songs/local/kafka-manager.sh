#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BOOTSTRAP_SERVER="localhost:9092"
DEFAULT_TOPIC="songs-listened-topic"
CONSUMER_GROUP="kafka-app-consumer-group"
MOCK_SONGS_FILE="mock-songs.json"

# Print colored output
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Check if Kafka is ready
wait_for_kafka() {
    print_status "Waiting for Kafka..."
    for i in {1..30}; do
        if docker-compose exec kafka kafka-topics --list --bootstrap-server $BOOTSTRAP_SERVER > /dev/null 2>&1; then
            print_success "Kafka ready!"
            return 0
        fi
        [ $i -eq 1 ] && print_status "Kafka not ready, waiting..."
        sleep 2
    done
    print_error "Kafka failed to start"
    return 1
}

# Check if jq is installed
check_jq() {
    command -v jq &> /dev/null || {
        print_error "Install jq: apt-get install jq / brew install jq"
        return 1
    }
}

# Generate random song ID
random_song_id() {
    cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 16 | head -n 1
}

# Generate random UUID
random_uuid() {
    uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "fallback-$(date +%s)-$RANDOM"
}

# Create song event JSON
create_song_json() {
    cat <<EOF
{
  "song_id": "$1",
  "song_name": "$2",
  "artist": "$3",
  "user_id": "$4",
  "timestamp": "$5"
}
EOF
}

# ========== MAIN COMMANDS ========== #

# Produce song events with keys using temp file
produce_songs() {
    local count=${1:-3}

    check_jq || return 1
    [ ! -f "$MOCK_SONGS_FILE" ] && { print_error "$MOCK_SONGS_FILE not found"; return 1; }

    print_status "Producing $count song events with keys..."
    local total_songs=$(jq length "$MOCK_SONGS_FILE")
    local temp_file=$(mktemp)

    for ((i=0; i<count; i++)); do
        local song_index=$(( RANDOM % total_songs ))
        local song=$(jq -r ".[$song_index] | @base64" "$MOCK_SONGS_FILE" | base64 --decode)
        local name=$(echo "$song" | jq -r '.song_name')
        local artist=$(echo "$song" | jq -r '.artist')
        local song_id=$(random_song_id)
        local user_id=$(random_uuid)
        local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")

        # Create compact JSON value
        local value=$(jq -c -n \
            --arg song_id "$song_id" \
            --arg song_name "$name" \
            --arg artist "$artist" \
            --arg user_id "$user_id" \
            --arg timestamp "$timestamp" \
            '{
                song_id: $song_id,
                song_name: $song_name,
                artist: $artist,
                user_id: $user_id,
                timestamp: $timestamp
            }')

        # Write to temp file
        echo "$song_id:$value" >> "$temp_file"
    done

    # Produce from temp file
    docker-compose exec -T kafka kafka-console-producer \
        --bootstrap-server $BOOTSTRAP_SERVER --topic $DEFAULT_TOPIC \
        --property "parse.key=true" --property "key.separator=:" < "$temp_file"

    # Debug: show what was produced
    print_status "Produced messages:"
    cat "$temp_file"

    rm "$temp_file"
    print_success "Produced $count songs with keys"
}

# Produce batch songs
produce_batch() {
    print_status "Producing 30 songs in 3 batches..."
    for i in 1 2 3; do
        print_status "Batch $i/3 (10 songs)..."
        produce_songs 10
        [ $i -lt 3 ] && sleep 1
    done
    print_success "Batch production complete: 30 songs"
}

# Consume messages
consume() {
    local count=${1:-5}
    print_status "Consuming $count messages..."
    docker-compose exec kafka kafka-console-consumer \
        --bootstrap-server $BOOTSTRAP_SERVER --topic $DEFAULT_TOPIC \
        --group $CONSUMER_GROUP --from-beginning --max-messages $count --timeout-ms 10000
    print_success "Consumed $count messages"
}

# Create topic
create_topic() {
    print_status "Creating topic..."
    docker-compose exec kafka kafka-topics --create \
        --bootstrap-server $BOOTSTRAP_SERVER --topic $DEFAULT_TOPIC \
        --partitions 1 --replication-factor 1 && print_success "Topic created" || print_warning "Topic may exist"
}

# List topics
list_topics() {
    print_status "Topics:"
    docker-compose exec kafka kafka-topics --list --bootstrap-server $BOOTSTRAP_SERVER
}

# Health check
health_check() {
    print_status "Health check..."
    list_topics > /dev/null && print_success "Kafka healthy" || print_error "Kafka unavailable"
}

# Reset offsets
reset_offsets() {
    print_status "Resetting offsets..."
    docker-compose exec kafka kafka-consumer-groups --bootstrap-server $BOOTSTRAP_SERVER \
        --group $CONSUMER_GROUP --reset-offsets --to-earliest --execute --topic $DEFAULT_TOPIC
    print_success "Offsets reset"
}

# Delete messages
delete_messages() {
    print_status "Deleting all messages..."
    docker-compose exec kafka kafka-topics --delete --topic $DEFAULT_TOPIC --bootstrap-server $BOOTSTRAP_SERVER
    sleep 2
    create_topic
    print_success "All messages deleted"
}

# ========== USAGE ========== #

show_help() {
    echo -e "${BLUE}Kafka Manager - Essential Commands${NC}"
    echo ""
    echo -e "${GREEN}Most Used:${NC}"
    echo "  produce-songs [n]    - Produce n song events (default: 3)"
    echo "  produce-batch        - Produce 30 songs in batches"
    echo "  consume [n]          - Consume n messages (default: 5)"
    echo "  create-topic         - Create songs topic"
    echo "  health-check         - Check Kafka health"
    echo ""
    echo -e "${YELLOW}Maintenance:${NC}"
    echo "  reset-offsets        - Reset consumer offsets"
    echo "  delete-messages      - Delete all messages"
    echo "  list-topics          - List all topics"
    echo ""
    echo -e "${BLUE}Examples:${NC}"
    echo "  $0 produce-songs      # Produce 3 songs"
    echo "  $0 produce-songs 10   # Produce 10 songs"
    echo "  $0 produce-batch      # Produce 30 songs"
    echo "  $0 consume 20         # Consume 20 messages"
    echo "  $0 health-check       # Check system"
}

# ========== MAIN ========== #

COMMAND="${1:-help}"
COUNT="$2"

case "$COMMAND" in
    "produce-songs")    produce_songs "$COUNT" ;;
    "produce-batch")    produce_batch ;;
    "consume")          consume "$COUNT" ;;
    "create-topic")     create_topic ;;
    "health-check")     health_check ;;
    "reset-offsets")    reset_offsets ;;
    "delete-messages")  delete_messages ;;
    "list-topics")      list_topics ;;
    "help"|"-h"|"--help") show_help ;;
    *)                  print_error "Unknown: $COMMAND"; show_help; exit 1 ;;
esac