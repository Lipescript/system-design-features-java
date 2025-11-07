package br.com.lipescript.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.Setter;

import java.util.List;

@Builder
@Getter
@Setter
@AllArgsConstructor
public class TopKResponse {
  private List<SongRank> songs;
  private String nextCursor;
  private boolean hasNext;
  private String timeRange;

    @Builder
    @Getter
    @Setter
    @AllArgsConstructor
    public class SongRank {
        private String songId;
        private String songName;
        private String artist;
        private long playCount;
        private int rank;
        private String cursor;
    }
}


