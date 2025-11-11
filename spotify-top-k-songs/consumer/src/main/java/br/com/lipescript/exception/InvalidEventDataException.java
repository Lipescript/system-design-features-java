package br.com.lipescript.exception;

public class InvalidEventDataException extends RuntimeException {

  public InvalidEventDataException(String message) {
    super(message);
  }
}
