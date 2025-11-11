package br.com.lipescript.model;

import java.time.Instant;

public record SongListenedRedis(
    String songId,
    String songName,
    String artist,
    Long playCount,
    Instant windowStart,
    Instant windowEnd,
    String timeBucket) {}
