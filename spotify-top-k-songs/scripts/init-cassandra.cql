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
