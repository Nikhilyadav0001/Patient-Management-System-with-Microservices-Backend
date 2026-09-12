package com.pm.patientservice.exception;

import java.util.HashMap;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalEceptionHandler {
	
	private static final Logger log = LoggerFactory.getLogger(GlobalEceptionHandler.class);
	
	
	//handle the validation exception and return a map of field errors
	 @ExceptionHandler(MethodArgumentNotValidException.class)
	 public ResponseEntity<Map<String, String>> handleValidationException(
		 MethodArgumentNotValidException ex) {
		
		Map<String, String> errors = new HashMap<>();

		//get all the field errors and put them in the map
		ex.getBindingResult().getFieldErrors().forEach(
        error -> errors.put(error.getField(), error.getDefaultMessage()));

		return ResponseEntity.badRequest().body(errors);
	 }
	 
	 //handle the email already exists exception and return a map of error message
	 @ExceptionHandler(EmailAlreadyExistsException.class)
	  public ResponseEntity<Map<String, String>> handleEmailAlreadyExistsException(
	      EmailAlreadyExistsException ex) {

		 log.warn("email already exists exception: {}", ex.getMessage());
	    Map<String, String> errors = new HashMap<>();
	    errors.put("message", "Email address already exists");
	    return ResponseEntity.badRequest().body(errors);
	  }
	 
	 //handle the patient not found exception and return a map of error message
	 @ExceptionHandler(PatientNotFoundException.class)
	  public ResponseEntity<Map<String, String>> handlePatientNotFoundException(
	      PatientNotFoundException ex) {
	    log.warn("Patient not found {}", ex.getMessage());

	    Map<String, String> errors = new HashMap<>();
	    errors.put("message", "Patient not found");
	    return ResponseEntity.badRequest().body(errors);
	  }

}
