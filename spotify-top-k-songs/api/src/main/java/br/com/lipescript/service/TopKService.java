package br.com.lipescript.service;

import static br.com.lipescript.service.TimeConstants.*;

import br.com.lipescript.model.SongRank;
import br.com.lipescript.model.TopKResponse;
import java.util.*;
import java.util.logging.Logger;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.cassandra.core.CassandraTemplate;
import org.springframework.data.cassandra.core.cql.CqlTemplate;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.ZSetOperations;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;

/**
 * Service for retrieving top-K most played songs using Redis for real-time data and Cassandra for
 * historical data with cursor-based pagination.
 */
@Service
public class TopKService {

  public static final String UNDERSCORE = "_";
  private final RedisTemplate<String, String> redisTemplate;
  private final CassandraTemplate cassandraTemplate;
  private final CqlTemplate cqlTemplate;

  private static final Set<String> SPECIAL_VALUES = Set.of("all", "max");
  private static final Pattern TIME_PATTERN = Pattern.compile(TIME_PATTERN_REGEX);
  private static final Logger logger = Logger.getLogger(TopKService.class.getName());

  @Autowired
  public TopKService(
      RedisTemplate<String, String> redisTemplate,
      CassandraTemplate cassandraTemplate,
      CqlTemplate cqlTemplate) {
    this.redisTemplate = redisTemplate;
    this.cassandraTemplate = cassandraTemplate;
    this.cqlTemplate = cqlTemplate;
  }

  /**
   * Retrieves top-K songs for the specified time range using cursor-based pagination.
   *
   * @param k Number of top songs to retrieve
   * @param time Time range specification (e.g., "1h", "7d", "30m")
   * @param cursor Cursor for pagination, representing the starting position
   * @return ResponseEntity containing top-K songs with pagination metadata
   * @throws IllegalArgumentException if time range format is invalid
   */
  public ResponseEntity<TopKResponse> getTopK(Integer k, String time, Integer cursor) {
    long timeInSeconds = literalTimeToSeconds(time);

    List<SongRank> redisResults = getTopKFromRedis(k + cursor, timeInSeconds);

    if (redisResults.size() >= k + cursor) {
      List<SongRank> paginatedResults = paginate(redisResults, cursor, k);
      String nextCursor = calculateNextCursor(paginatedResults, cursor, k);

      return ResponseEntity.ok(
          buildResponse(paginatedResults, time, nextCursor != null, nextCursor));
    }

    List<SongRank> cassandraResults =
        getTopKFromCassandra(k + cursor - redisResults.size(), timeInSeconds);
    List<SongRank> mergedResults = mergeResults(redisResults, cassandraResults, k, cursor);
    String nextCursor = calculateNextCursor(mergedResults, cursor, k);

    return ResponseEntity.ok(buildResponse(mergedResults, time, nextCursor != null, nextCursor));
  }

  /**
   * Builds TopKResponse from song list and pagination metadata.
   *
   * @param songs List of song rankings
   * @param timeRange Requested time range
   * @param hasNext Whether more results are available
   * @param nextCursor Cursor for retrieving next page
   * @return Configured TopKResponse instance
   */
  private TopKResponse buildResponse(
      List<SongRank> songs, String timeRange, boolean hasNext, String nextCursor) {
    return new TopKResponse(songs, timeRange, hasNext, nextCursor);
  }

  /**
   * Calculates next cursor for pagination based on current results.
   *
   * @param results Current page of results
   * @param currentCursor Current cursor position
   * @param k Number of items per page
   * @return Next cursor value, or null if no more results
   */
  private String calculateNextCursor(List<SongRank> results, int currentCursor, int k) {
    if (results.size() < k) {
      return null;
    }
    SongRank lastSong = results.get(results.size() - 1);
    return lastSong.cursor() + UNDERSCORE + (currentCursor + k);
  }

  /**
   * Retrieves top-K songs from Redis sorted sets using cursor-based range queries.
   *
   * @param limit Maximum number of songs to retrieve
   * @param timeInSeconds Time range converted to seconds
   * @return List of song rankings from Redis
   */
  private List<SongRank> getTopKFromRedis(int limit, long timeInSeconds) {
    try {
      String redisKey = buildRedisKey(timeInSeconds);
      Set<ZSetOperations.TypedTuple<String>> topSongs =
          redisTemplate.opsForZSet().reverseRangeWithScores(redisKey, 0, limit - 1);

      return convertRedisResults(topSongs != null ? topSongs : Collections.emptySet());
    } catch (Exception e) {
      logger.warning("Redis error: " + e.getMessage());
      return Collections.emptyList();
    }
  }

  /**
   * Retrieves top-K songs from Cassandra using cursor-based CQL queries.
   *
   * @param limit Maximum number of songs to retrieve
   * @param timeInSeconds Time range converted to seconds
   * @return List of song rankings from Cassandra
   */
  private List<SongRank> getTopKFromCassandra(int limit, long timeInSeconds) {
    try {
      String cql =
          "SELECT song_id, song_name, artist, play_count "
              + "FROM song_plays WHERE time_bucket = ? "
              + "ORDER BY play_count DESC LIMIT ?";

      return cqlTemplate.query(
          cql,
          (row, rowNum) ->
              new SongRank(
                  row.getString("song_id"),
                  row.getString("song_name"),
                  row.getString("artist"),
                  row.getLong("play_count"),
                  rowNum + 1,
                  generateCursor(row.getString("song_id"), row.getLong("play_count"))),
          getCassandraTimeBucket(timeInSeconds),
          limit);
    } catch (Exception e) {
      logger.warning("Cassandra error: " + e.getMessage());
      return Collections.emptyList();
    }
  }

  /**
   * Builds Redis key based on time range for efficient data partitioning.
   *
   * @param timeInSeconds Time range in seconds
   * @return Redis key for the specified time range
   */
  private String buildRedisKey(long timeInSeconds) {
    if (timeInSeconds == Long.MAX_VALUE) {
      return REDIS_ALL_TIME_KEY;
    }

    long currentTime = System.currentTimeMillis();

    if (timeInSeconds <= HOUR) {
      return REDIS_REALTIME_KEY_PREFIX + "current";
    } else if (timeInSeconds <= DAY) {
      return REDIS_HOURLY_KEY_PREFIX + (currentTime / (HOUR * 1000L));
    } else {
      return REDIS_DAILY_KEY_PREFIX + (currentTime / (DAY * 1000L));
    }
  }

  /**
   * Determines Cassandra time bucket for efficient historical data querying.
   *
   * @param timeInSeconds Time range in seconds
   * @return Cassandra time bucket identifier
   */
  private String getCassandraTimeBucket(long timeInSeconds) {
    if (timeInSeconds == Long.MAX_VALUE) {
      return CASSANDRA_ALL_TIME_BUCKET;
    }

    long currentTime = System.currentTimeMillis() / 1000;
    long startTime = currentTime - timeInSeconds;

    if (timeInSeconds <= DAY) {
      return CASSANDRA_HOURLY_BUCKET_PREFIX + (startTime / HOUR);
    } else if (timeInSeconds <= MONTH_30_DAYS) {
      return CASSANDRA_DAILY_BUCKET_PREFIX + (startTime / DAY);
    } else {
      return CASSANDRA_MONTHLY_BUCKET_PREFIX + (startTime / MONTH_30_DAYS);
    }
  }

  /**
   * Converts Redis ZSet results to SongRank objects with cursor generation.
   *
   * @param redisResults Redis sorted set results
   * @return List of SongRank objects with generated cursors
   */
  private List<SongRank> convertRedisResults(Set<ZSetOperations.TypedTuple<String>> redisResults) {
    List<SongRank> songs = new ArrayList<>();
    int rank = 1;

    for (ZSetOperations.TypedTuple<String> tuple : redisResults) {
      String songData = tuple.getValue();
      Double score = tuple.getScore();

      if (songData != null && score != null) {
        String[] parts = songData.split(":", 3);
        if (parts.length >= 3) {
          songs.add(
              new SongRank(
                  parts[0],
                  parts[1],
                  parts[2],
                  score.longValue(),
                  rank++,
                  generateCursor(parts[0], score.longValue())));
        }
      }
    }
    return songs;
  }

  /**
   * Generates unique cursor for a song based on song ID and play count.
   *
   * @param songId Unique song identifier
   * @param playCount Current play count for the song
   * @return Generated cursor string for pagination
   */
  private String generateCursor(String songId, long playCount) {
    return songId + UNDERSCORE + playCount;
  }

  /**
   * Merges Redis and Cassandra results while removing duplicates and maintaining order.
   *
   * @param redisResults Real-time results from Redis
   * @param cassandraResults Historical results from Cassandra
   * @param k Number of items to return
   * @param cursor Current cursor position
   * @return Merged and sorted list of song rankings
   */
  private List<SongRank> mergeResults(
      List<SongRank> redisResults, List<SongRank> cassandraResults, int k, int cursor) {
    Map<String, SongRank> uniqueSongs = new LinkedHashMap<>();

    for (SongRank song : redisResults) {
      uniqueSongs.putIfAbsent(song.songId(), song);
    }

    for (SongRank song : cassandraResults) {
      uniqueSongs.putIfAbsent(song.songId(), song);
    }

    List<SongRank> merged = new ArrayList<>(uniqueSongs.values());
    merged.sort((a, b) -> Long.compare(b.playCount(), a.playCount()));

    return paginate(merged, cursor, k);
  }

  /**
   * Paginates results based on cursor position and limit.
   *
   * @param results Full list of results to paginate
   * @param cursor Starting position for pagination
   * @param limit Maximum number of items to return
   * @return Paginated sublist of results
   */
  private List<SongRank> paginate(List<SongRank> results, int cursor, int limit) {
    int fromIndex = Math.min(cursor, results.size());
    int toIndex = Math.min(cursor + limit, results.size());

    if (fromIndex >= toIndex) {
      return Collections.emptyList();
    }

    return results.subList(fromIndex, toIndex);
  }

  /**
   * Converts literal time range to seconds for database queries.
   *
   * @param timeRange Time range string (e.g., "30s", "2h", "7d")
   * @return Time range in seconds
   * @throws IllegalArgumentException if time range format is invalid
   */
  private Long literalTimeToSeconds(String timeRange) {
    if (SPECIAL_VALUES.contains(timeRange.toLowerCase())) {
      return Long.MAX_VALUE;
    }

    Matcher matcher = TIME_PATTERN.matcher(timeRange.toLowerCase());
    if (!matcher.matches()) {
      throw new IllegalArgumentException("Invalid time range format: " + timeRange);
    }

    long value = Long.parseLong(matcher.group(1));
    String unit = matcher.group(2);

    return switch (unit) {
      case "s" -> value * SECOND;
      case "m" -> value * MINUTE;
      case "h" -> value * HOUR;
      case "d" -> value * DAY;
      case "w" -> value * WEEK;
      case "M" -> value * MONTH_30_DAYS;
      case "y" -> value * YEAR;
      default -> throw new IllegalArgumentException("Unknown time unit: " + unit);
    };
  }
}
