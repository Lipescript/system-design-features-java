package br.com.lipescript.model;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

public record TopKResponse(
    @JsonProperty("songs") List<SongRank> songs,
    @JsonProperty("next_cursor") String nextCursor,
    @JsonProperty("has_next") Boolean hasNext,
    @JsonProperty("time_range") String timeRange) {}
