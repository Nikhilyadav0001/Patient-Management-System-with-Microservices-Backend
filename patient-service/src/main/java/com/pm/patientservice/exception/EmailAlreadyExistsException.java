package com.pm.patientservice.exception;

@SuppressWarnings("serial")
public class EmailAlreadyExistsException extends RuntimeException {

  public EmailAlreadyExistsException(String message) {
    super(message);
  }
}