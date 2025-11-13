#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BOOTSTRAP_SERVER="localhost:9092"
DEFAULT_TOPIC="my-topic"
CONSUMER_GROUP="kafka-manager-group"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if Kafka is ready
wait_for_kafka() {
    print_status "Waiting for Kafka to be ready..."
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if docker-compose exec kafka kafka-topics --list --bootstrap-server $BOOTSTRAP_SERVER > /dev/null 2>&1; then
            print_success "Kafka is ready!"
            return 0
        fi
        print_status "Attempt $attempt/$max_attempts: Kafka not ready yet, waiting 5 seconds..."
        sleep 5
        ((attempt++))
    done

    print_error "Kafka failed to become ready within $max_attempts attempts"
    return 1
}

# Function to create a topic
create_topic() {
    local topic_name=$DEFAULT_TOPIC

    print_status "Creating topic: $topic_name (partitions: 1, replication: 1)"

    if docker-compose exec kafka kafka-topics --create \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --topic $topic_name \
        --partitions 1 \
        --replication-factor 1; then
        print_success "Topic '$topic_name' created successfully"
    else
        print_warning "Topic may already exist (this is OK)"
    fi
}

# Function to list topics
list_topics() {
    print_status "Listing all topics:"
    docker-compose exec kafka kafka-topics --list --bootstrap-server $BOOTSTRAP_SERVER
}

# Function to describe a topic
describe_topic() {
    print_status "Describing topic: $DEFAULT_TOPIC"
    docker-compose exec kafka kafka-topics --describe --topic $DEFAULT_TOPIC --bootstrap-server $BOOTSTRAP_SERVER
}

# Function to produce test messages
produce_messages() {
    local message_count=3

    print_status "Producing $message_count test messages to topic: $DEFAULT_TOPIC"

    # Create test messages
    local messages=()
    for i in $(seq 1 $message_count); do
        messages+=("Test message $i at $(date '+%Y-%m-%d %H:%M:%S')")
    done

    # Produce messages using printf to handle newlines properly
    printf "%s\n" "${messages[@]}" | docker-compose exec -T kafka kafka-console-producer \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --topic $DEFAULT_TOPIC

    print_success "Produced $message_count messages to '$DEFAULT_TOPIC'"
}

# Function to consume messages (with consumer group to mark as consumed)
consume_messages() {
    local max_messages=10

    print_status "Consuming up to $max_messages messages from topic: $DEFAULT_TOPIC"
    print_status "Using consumer group: $CONSUMER_GROUP (messages will be marked as consumed)"

    # Consume messages with a consumer group to commit offsets
    docker-compose exec kafka kafka-console-consumer \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --topic $DEFAULT_TOPIC \
        --group $CONSUMER_GROUP \
        --from-beginning \
        --max-messages $max_messages \
        --timeout-ms 10000

    print_success "Consumed messages and committed offsets (messages are marked as consumed)"
}

# Function to reset consumer offsets (effectively "re-enable" consumed messages)
reset_offsets() {
    print_status "Resetting consumer offsets for group: $CONSUMER_GROUP"
    print_warning "This will make previously consumed messages available again"

    docker-compose exec kafka kafka-consumer-groups \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --group $CONSUMER_GROUP \
        --reset-offsets \
        --to-earliest \
        --execute \
        --topic $DEFAULT_TOPIC

    print_success "Consumer offsets reset - all messages are available again"
}

# Function to show consumer groups
list_consumer_groups() {
    print_status "Listing consumer groups:"
    docker-compose exec kafka kafka-consumer-groups --list --bootstrap-server $BOOTSTRAP_SERVER
}

# Function to describe consumer group
describe_consumer_group() {
    print_status "Describing consumer group: $CONSUMER_GROUP"
    docker-compose exec kafka kafka-consumer-groups \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --group $CONSUMER_GROUP \
        --describe
}

# Function to delete all messages from topic (by deleting and recreating)
delete_all_messages() {
    print_status "Deleting all messages from topic: $DEFAULT_TOPIC"
    print_warning "This will delete the topic and all its messages, then recreate it"

    # Delete the topic
    docker-compose exec kafka kafka-topics --delete \
        --topic $DEFAULT_TOPIC \
        --bootstrap-server $BOOTSTRAP_SERVER

    # Wait a moment
    sleep 2

    # Recreate the topic
    create_topic

    print_success "All messages deleted from '$DEFAULT_TOPIC'"
}

# Function to run health check
health_check() {
    print_status "Running Kafka health check..."

    # Check if Kafka is responsive
    if ! list_topics > /dev/null 2>&1; then
        print_error "Kafka is not responsive"
        return 1
    fi

    # Create test topic
    local test_topic="health-check-$(date +%s)"
    print_status "Creating test topic: $test_topic"
    if ! docker-compose exec kafka kafka-topics --create \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --topic $test_topic \
        --partitions 1 \
        --replication-factor 1; then
        print_error "Health check failed: cannot create topic"
        return 1
    fi

    # Produce test message
    print_status "Producing health check message..."
    if ! echo "Health check message $(date)" | docker-compose exec -T kafka kafka-console-producer \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --topic $test_topic; then
        print_error "Health check failed: cannot produce message"
        return 1
    fi

    # Consume test message with consumer group
    print_status "Consuming health check message..."
    local consumed_message=$(docker-compose exec kafka kafka-console-consumer \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --topic $test_topic \
        --group "health-check-group" \
        --from-beginning \
        --max-messages 1 \
        --timeout-ms 10000 2>/dev/null)

    if [ -n "$consumed_message" ]; then
        print_success "Health check passed: Produced and consumed message successfully"
        print_success "Message: $consumed_message"
    else
        print_error "Health check failed: Could not consume message"
        return 1
    fi

    # Cleanup test topic
    docker-compose exec kafka kafka-topics --delete --topic $test_topic --bootstrap-server $BOOTSTRAP_SERVER > /dev/null 2>&1

    return 0
}

# Function to run full test
test_full() {
    print_status "Running full integration test..."

    # Create topic
    create_topic || return 1

    # Produce messages
    produce_messages || return 1

    # Consume messages (with consumer group)
    consume_messages || return 1

    print_success "Full integration test completed successfully!"
}

# Function to show available commands
show_available_commands() {
    echo -e "${BLUE}Available commands:${NC}"
    echo ""
    echo -e "  ${GREEN}health-check${NC}    - Run complete Kafka health check"
    echo -e "  ${GREEN}create-topic${NC}    - Create default topic ($DEFAULT_TOPIC)"
    echo -e "  ${GREEN}list-topics${NC}     - List all topics"
    echo -e "  ${GREEN}describe-topic${NC}  - Describe default topic ($DEFAULT_TOPIC)"
    echo -e "  ${GREEN}produce${NC}         - Produce 3 test messages"
    echo -e "  ${GREEN}consume${NC}         - Consume up to 10 messages (marks as consumed)"
    echo -e "  ${GREEN}reset-offsets${NC}   - Reset consumer offsets (re-enable messages)"
    echo -e "  ${GREEN}delete-messages${NC} - Delete all messages (recreate topic)"
    echo -e "  ${GREEN}list-groups${NC}     - List consumer groups"
    echo -e "  ${GREEN}describe-group${NC}  - Describe consumer group"
    echo -e "  ${GREEN}test-full${NC}       - Create topic, produce and consume messages"
    echo -e "  ${GREEN}help${NC}            - Show this help message"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "  $0 <command>"
    echo ""
    echo -e "${YELLOW}Message Consumption:${NC}"
    echo "  - 'consume' uses consumer groups to mark messages as consumed"
    echo "  - Use 'reset-offsets' to make consumed messages available again"
    echo "  - Use 'delete-messages' to completely clear all messages"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 health-check"
    echo "  $0 produce"
    echo "  $0 consume"
    echo "  $0 reset-offsets"
}

# Function to show error for invalid command
show_invalid_command() {
    print_error "Invalid command: $1"
    echo ""
    show_available_commands
    exit 1
}

# Main script logic
COMMAND="${1:-help}"

case "$COMMAND" in
    "health-check")
        health_check
        ;;
    "create-topic")
        create_topic
        ;;
    "list-topics")
        list_topics
        ;;
    "describe-topic")
        describe_topic
        ;;
    "produce")
        produce_messages
        ;;
    "consume")
        consume_messages
        ;;
    "reset-offsets")
        reset_offsets
        ;;
    "delete-messages")
        delete_all_messages
        ;;
    "list-groups")
        list_consumer_groups
        ;;
    "describe-group")
        describe_consumer_group
        ;;
    "test-full")
        test_full
        ;;
    "help"|"-h"|"--help")
        show_available_commands
        ;;
    *)
        show_invalid_command "$COMMAND"
        ;;
esac