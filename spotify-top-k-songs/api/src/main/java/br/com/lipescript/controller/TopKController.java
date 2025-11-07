package br.com.lipescript.controller;

import br.com.lipescript.model.TopKResponse;
import br.com.lipescript.service.TopKService;
import jakarta.validation.constraints.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/top-k")
public class TopKController {

  @Autowired private TopKService topKService;

  public static final String TIME_PATTERN_STRING = "^(\\d+)([smhdwMy])$";
  public static final String VALIDATION_MESSAGE =
      "Time range must be like: 30s, 5m, 2h, 7d, 1w, 1M, 1y, all";

  @GetMapping
  public ResponseEntity<TopKResponse> getTopK(
      @RequestParam(value = "k", required = true) @NotBlank @Min(100) @Max(1000) final Integer k,
      @RequestParam(value = "time", defaultValue = "all", required = false)
          @jakarta.validation.constraints.Pattern(
              regexp = TIME_PATTERN_STRING,
              message = VALIDATION_MESSAGE)
          final String time,
      @RequestParam(value = "cursor", defaultValue = "0", required = false) @Min(0) @NotNull
          final Integer cursor) {
    return topKService.getTopK(k, time, cursor);
  }
}
