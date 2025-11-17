package br.com.lipescript.consumer;

import br.com.lipescript.exception.InvalidEventDataException;
import br.com.lipescript.model.SongListenedEvent;
import br.com.lipescript.snapshot.SnapshotService;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import java.util.logging.Logger;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.annotation.RetryableTopic;
import org.springframework.kafka.listener.ListenerExecutionFailedException;
import org.springframework.kafka.retrytopic.DltStrategy;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.kafka.support.KafkaHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.retry.annotation.Backoff;
import org.springframework.stereotype.Service;

@Service
public class SongListennedConsumer {

  private final SnapshotService snapshot;
  private final ObjectMapper objectMapper;
  private static final Logger logger = Logger.getLogger(SongListennedConsumer.class.getName());

  public SongListennedConsumer(SnapshotService snapshotService, ObjectMapper objectMapper) {
    this.snapshot = snapshotService;
    this.objectMapper = objectMapper;
    objectMapper.registerModule(new JavaTimeModule());
  }

  @KafkaListener(
      topics = "${kafka.topics.songs-listened:songs-listened-topic}",
      containerFactory = "kafkaListenerContainerFactory",
      concurrency = "3") // todo evaluate this value
  @RetryableTopic(
      backoff = @Backoff(delay = 1000, multiplier = 2, maxDelay = 10000),
      dltStrategy = DltStrategy.FAIL_ON_ERROR)
  public void consumeSongPlayEvent(
      @Payload String jsonEvent,
      @Header(KafkaHeaders.RECEIVED_KEY) String key,
      Acknowledgment ack) {

    try {
      SongListenedEvent event = objectMapper.readValue(jsonEvent, SongListenedEvent.class);

      logger.info(
          String.format(
              "Processing Song Played [Key: %s, Song: %s - %s] at %s",
              key, event.artist(), event.songName(), event.timestamp()));

      //TODO Redis block
      snapshot.processEvent(event);
      ack.acknowledge();

    } catch (ListenerExecutionFailedException | InvalidEventDataException e) {
      logger.info(String.format("Data validation failure: %s", e.getMessage()));
      ack.acknowledge();
    } catch (Exception e) {
      logger.severe("Processing error for key " + key + ": " + e.getMessage());
      throw new RuntimeException("Processing failure for key " + key + ": " + e.getMessage());
    }
  }
}
