package com.pm.patientservice.exception;

@SuppressWarnings("serial")
public class PatientNotFoundException extends RuntimeException {

  public PatientNotFoundException(String message) {
    super(message);
  }
}