package br.com.lipescript.model;

import br.com.lipescript.exception.InvalidEventDataException;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.Instant;
import java.util.UUID;

public record SongListenedEvent(
    @JsonProperty("song_id") String songId,
    @JsonProperty("song_name") String songName,
    @JsonProperty("artist") String artist,
    @JsonProperty("user_id") UUID userId,
    @JsonProperty("timestamp") Instant timestamp) {

  public SongListenedEvent {
    if (songId == null || songId.trim().isEmpty()) {
      throw new InvalidEventDataException("Song ID required");
    }
    songId = songId.trim();

    if (songName == null || songName.trim().isEmpty()) {
      throw new InvalidEventDataException("Song name required");
    }
    songName = songName.trim();

    if (artist == null || artist.trim().isEmpty()) {
      throw new InvalidEventDataException("Artist name required");
    }
    artist = artist.trim();

    if (userId == null || userId.toString().trim().isEmpty()) {
      throw new InvalidEventDataException("User ID required");
    }

    if (timestamp == null) {
      throw new InvalidEventDataException("Timestamp required");
    }

    if (!songId.matches("^[A-Za-z0-9]{22}$")) {
      throw new InvalidEventDataException("Invalid Song ID format");
    }
  }
}
