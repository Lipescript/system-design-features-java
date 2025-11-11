package br.com.lipescript.consumer;

import br.com.lipescript.exception.InvalidEventDataException;
import br.com.lipescript.model.SongListenedEvent;
import java.util.logging.Logger;

import br.com.lipescript.snapshot.SnapshotService;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.kafka.support.KafkaHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Service;

@Service
public class SongListennedConsumer {

  private static final Logger logger = Logger.getLogger(SongListennedConsumer.class.getName());
  private final SnapshotService snapshot;

  public SongListennedConsumer(SnapshotService snapshotService) {
    this.snapshot = snapshotService;
  }

  @KafkaListener(
      topics = "${kafka.topics.songs-listened:songs-listened-topic}",
      containerFactory = "kafkaListenerContainerFactory")
  public void consumeSongPlayEvent(
      @Payload SongListenedEvent event,
      @Header(KafkaHeaders.RECEIVED_KEY) String key,
      Acknowledgment ack) {

    try {
      logger.info(
          String.format(
              "Processing Song Played [Key: %s, Song: %s - %s] at %s",
              key, event.artist(), event.songName(), event.timestamp()));

        snapshot.processEvent(new SongListenedEvent(
                event.songId(), event.songName(), event.artist(), event.userId(), event.timestamp()));

      ack.acknowledge();

    } catch (InvalidEventDataException e) {
      logger.info(String.format("Data validation failure for event %s ", event) + e.getMessage());
      ack.acknowledge(); // Don't retry - it's a data issue

    } catch (Exception e) {
      logger.severe("Processing error: " + e.getMessage());
      throw new RuntimeException(
          String.format("Processing failure for event %s", event) + e.getMessage()); // Retryable
    }
  }
}
