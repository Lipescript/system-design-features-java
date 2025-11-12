-- Create keyspace
CREATE KEYSPACE IF NOT EXISTS spotify_keyspace
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

-- Use keyspace
USE spotify_keyspace;

-- Table for storing top songs by time window
CREATE TABLE IF NOT EXISTS top_songs_by_window (
    time_window_type text,        -- 'minute', 'hour', 'day', 'month'
    time_bucket text,             -- Formatted time bucket (e.g., '202311121445')
    song_id text,
    song_name text,
    artist text,
    play_count counter,
    last_updated timestamp,
    PRIMARY KEY ((time_window_type, time_bucket), song_id)
) WITH CLUSTERING ORDER BY (song_id ASC);

-- Table for individual song plays (if needed for detailed analytics)
CREATE TABLE IF NOT EXISTS song_plays (
    song_id text,
    event_time timestamp,
    user_id text,
    song_name text,
    artist text,
    PRIMARY KEY (song_id, event_time)
) WITH CLUSTERING ORDER BY (event_time DESC);
