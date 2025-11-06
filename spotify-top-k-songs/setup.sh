#!/bin/bash

# setup.sh - Initial setup for Spotify Top K Songs project

set -e  # Exit on any error

echo "🎵 Setting up Spotify Top K Songs..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first."
    exit 1
fi

# Check if Maven is installed
if ! command -v mvn &> /dev/null; then
    echo "❌ Maven not found. Please install Maven first."
    exit 1
fi

# Check if Java is installed
if ! command -v java &> /dev/null; then
    echo "❌ Java not found. Please install Java 21+ first."
    exit 1
fi

# Create scripts directory if it doesn't exist
mkdir -p scripts

# Create Cassandra initialization script
# TODO configure cassandra configs and database schemas
cat > scripts/init-cassandra.cql << 'EOF'
-- Create keyspace
CREATE KEYSPACE IF NOT EXISTS spotify_keyspace
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

-- Use keyspace
USE spotify_keyspace;

-- Table for top songs
CREATE TABLE IF NOT EXISTS top_songs (
    time_window timestamp,
    song_id text,
    play_count counter,
    PRIMARY KEY (time_window, song_id)
);

-- Table for play events
CREATE TABLE IF NOT EXISTS song_plays (
    event_id timeuuid,
    song_id text,
    user_id text,
    timestamp timestamp,
    PRIMARY KEY (song_id, timestamp)
) WITH CLUSTERING ORDER BY (timestamp DESC);
EOF

echo "✅ Cassandra initialization script created"

# Make all scripts executable
chmod +x scripts/*.sh 2>/dev/null || true

echo "🎉 Setup complete! Now use:"
echo "   ./scripts/start-infra.sh    - Start infrastructure"