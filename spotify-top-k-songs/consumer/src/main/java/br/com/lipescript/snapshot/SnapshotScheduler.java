package br.com.lipescript.snapshot;

import java.time.Instant;
import java.util.logging.Logger;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class SnapshotScheduler {

  private static final Logger logger = Logger.getLogger(SnapshotScheduler.class.getName());
  private final SnapshotService snapshotService;
  public static final String THREE_AM_DAILY_CRON = "0 0 3 * * *";
  public static final String EVERY_MINUTE_ON_ZERO_SECONDS_CRON = "0 * * * * *";

  public SnapshotScheduler(SnapshotService snapshotService) {
    this.snapshotService = snapshotService;
  }

  @Scheduled(cron = EVERY_MINUTE_ON_ZERO_SECONDS_CRON)
  public void createMinuteSnapshot() {
    try {
      Instant now = Instant.now();
      logger.info(
          new StringBuilder().append("Creating minute snapshot for: ").append(now).toString());

      snapshotService.createMinuteSnapshot(now);

    } catch (Exception e) {
      logger.severe("Failed to execute minute snapshot: " + e.getMessage());
    }
  }

  @Scheduled(cron = THREE_AM_DAILY_CRON)
  public void cleanupData() {
    logger.info("Starting cleanup of old Redis data");
    // TODO cleanup old data
  }
}
