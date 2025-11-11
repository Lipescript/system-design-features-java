package br.com.lipescript.model;

import com.fasterxml.jackson.annotation.JsonProperty;

public record SongRank(
    @JsonProperty("song_id") String songId,
    @JsonProperty("song_name") String songName,
    @JsonProperty("artist") String artist,
    @JsonProperty("play_count") Long playCount,
    @JsonProperty("rank") Integer rank,
    @JsonProperty("cursor") String cursor) {}
