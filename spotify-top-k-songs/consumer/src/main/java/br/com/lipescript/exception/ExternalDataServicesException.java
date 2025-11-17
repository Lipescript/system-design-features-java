package br.com.lipescript.exception;

public class ExternalDataServicesException extends RuntimeException {

  public ExternalDataServicesException(String message, Exception exception) {
    super(message, exception);
  }
}
