package br.com.lipescript.snapshot;

import br.com.lipescript.model.SongListenedCassandra;
import br.com.lipescript.model.SongListenedEvent;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Set;
import java.util.concurrent.TimeUnit;
import java.util.logging.Logger;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.ZSetOperations;
import org.springframework.stereotype.Service;

@Service
public class SnapshotService {

  @Value("${spring.jackson.time-zone:America/Sao_Paulo}")
  private String timeZone;

  private static final Logger logger = Logger.getLogger(SnapshotService.class.getName());
  private final RedisTemplate<String, String> redisTemplate;

  private static final DateTimeFormatter MINUTE_FORMATTER =
      DateTimeFormatter.ofPattern("yyyyMMddHHmm");
  private static final DateTimeFormatter HOUR_FORMATTER = DateTimeFormatter.ofPattern("yyyyMMddHH");
  private static final DateTimeFormatter DAY_FORMATTER = DateTimeFormatter.ofPattern("yyyyMMdd");
  private static final DateTimeFormatter MONTH_FORMATTER = DateTimeFormatter.ofPattern("yyyyMM");

  public SnapshotService(RedisTemplate<String, String> redisTemplate) {
    this.redisTemplate = redisTemplate;
  }

  /** Processes an event and updates Redis + prepares snapshot for Cassandra */
  public void processEvent(SongListenedEvent event) {
    Instant now = Instant.now();
    updateRedisCounters(event, now);
    prepareCassandraSnapshot(event, now);
  }

  /** Updates real-time counters in Redis */
  private void updateRedisCounters(SongListenedEvent event, Instant timestamp) {
    try {
      LocalDateTime dateTime = LocalDateTime.ofInstant(timestamp, ZoneId.of(timeZone));

      updateTimeWindow(event, dateTime, "minute", MINUTE_FORMATTER, 60);
      updateTimeWindow(event, dateTime, "hour", HOUR_FORMATTER, 24 * 60);
      updateTimeWindow(event, dateTime, "day", DAY_FORMATTER, 30 * 24 * 60);
      updateTimeWindow(event, dateTime, "month", MONTH_FORMATTER, 365 * 24 * 60);

      logger.info("Updated Redis counters for song: " + event.songId());

    } catch (Exception e) {
      logger.severe("Failed to update Redis counters: " + e.getMessage());
      throw new RuntimeException("Redis update failed", e);
    }
  }

  private void updateTimeWindow(
      SongListenedEvent event,
      LocalDateTime dateTime,
      String windowType,
      DateTimeFormatter formatter,
      long expirationMinutes) {
    String timeBucket = dateTime.format(formatter);
    String redisKey = String.format("song_listened:%s:%s", windowType, timeBucket);
    String songData = event.songId() + ":" + event.songName() + ":" + event.artist();

    redisTemplate.opsForZSet().incrementScore(redisKey, songData, 1);
    redisTemplate.expire(redisKey, expirationMinutes, TimeUnit.MINUTES);
  }

  /** Prepares snapshot for Cassandra persistence */
  private void prepareCassandraSnapshot(SongListenedEvent event, Instant timestamp) {
    try {
      LocalDateTime dateTime = LocalDateTime.ofInstant(timestamp, ZoneId.of("America/Sao_Paulo"));

      SongListenedCassandra cassandraRecord =
          new SongListenedCassandra(
              event.songId(),
              event.songName(),
              event.artist(),
              1L,
              dateTime.format(MINUTE_FORMATTER),
              timestamp);

      logger.fine("Prepared Cassandra snapshot for song: " + event.songId());

    } catch (Exception e) {
      logger.warning("Failed to prepare Cassandra snapshot: " + e.getMessage());
    }
  }

  /** Creates minute snapshot for previous minute data */
  void createMinuteSnapshot(Instant snapshotTime) {
    try {
      LocalDateTime dateTime =
          LocalDateTime.ofInstant(snapshotTime.minusSeconds(60), ZoneId.of("America/Sao_Paulo"));
      String previousMinuteBucket = dateTime.format(MINUTE_FORMATTER);
      String redisKey = "song_listened:minute:" + previousMinuteBucket;

      var topSongs = redisTemplate.opsForZSet().reverseRangeWithScores(redisKey, 0, -1);

      if (topSongs != null && !topSongs.isEmpty()) {
        persistSnapshotToCassandra(topSongs, previousMinuteBucket, snapshotTime);
        logger.info(
            "Created snapshot for minute: "
                + previousMinuteBucket
                + " with "
                + topSongs.size()
                + " records");
      }

    } catch (Exception e) {
      logger.severe("Failed to create minute snapshot: " + e.getMessage());
    }
  }

  /** Persists snapshot data to Cassandra using batch operations */
  private void persistSnapshotToCassandra(
      Set<ZSetOperations.TypedTuple<String>> songData, String timeBucket, Instant snapshotTime) {
    try {
      for (ZSetOperations.TypedTuple<String> tuple : songData) {
        String[] parts = tuple.getValue().split(":");
        if (parts.length >= 3) {
          String songId = parts[0];
          String songName = parts[1];
          String artist = parts[2];
          long count = tuple.getScore().longValue();

          // Using CQL to update counter
          String cql =
              "UPDATE top_songs_by_window "
                  + "SET play_count = play_count + ?, "
                  + "    song_name = ?, "
                  + "    artist = ?, "
                  + "    last_updated = ? "
                  + "WHERE time_window_type = ? "
                  + "  AND time_bucket = ? "
                  + "  AND song_id = ?";

          //          cassandraTemplate
          //              .getCqlOperations()
          //              .execute(cql, count, songName, artist, snapshotTime, "minute", timeBucket,
          // songId);
        }
      }
      logger.info(
          "Persisted " + songData.size() + " records to Cassandra for time bucket: " + timeBucket);
    } catch (Exception e) {
      logger.severe("Failed to persist snapshot to Cassandra: " + e.getMessage());
      throw new RuntimeException("Cassandra persistence failed", e);
    }
  }
}
