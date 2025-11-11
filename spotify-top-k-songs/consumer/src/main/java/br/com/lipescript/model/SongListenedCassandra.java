package br.com.lipescript.model;

import java.time.Instant;

public record SongListenedCassandra(
    String songId,
    String songName,
    String artist,
    Long playCount,
    String timeBucket,
    Instant snapshotTimestamp) {}
