package com.pm.patientservice.controller;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.pm.patientservice.dto.PatientRequestDTO;
import com.pm.patientservice.dto.PatientResponseDTO;
import com.pm.patientservice.dto.validators.CreatePatientValidationGroup;
import com.pm.patientservice.service.PaitentService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.groups.Default;

@RestController
@RequestMapping("/patients") // http://localhost:4000/patients
@Tag(name = "Patient", description = "API for managing Patients")
public class PatientController {

	private final PaitentService patientService;
	
	public PatientController(PaitentService patientService) {
		this.patientService = patientService;
	}
		
	@GetMapping
	@Operation(summary = "Get Patients")
	public ResponseEntity<List<PatientResponseDTO>> getPatients(){
		List<PatientResponseDTO> patients = patientService.getPatients();
		return ResponseEntity.ok().body(patients);
	}
	
	@PostMapping
	@Operation(summary = "Create a new Patient")
	public ResponseEntity<PatientResponseDTO> createPatient(
			@Validated({Default.class ,CreatePatientValidationGroup.class}) @RequestBody 
			PatientRequestDTO patientRequestDTO){
		
		PatientResponseDTO newPatient = patientService.createPatient(patientRequestDTO);
		
		return ResponseEntity.ok().body(newPatient);
	}
	
	@PutMapping("/{id}")
	@Operation(summary = "Update a new Patient")
	public ResponseEntity<PatientResponseDTO> updatePatient(
			@PathVariable UUID id,
			//validation group for update operation
			@Validated({Default.class}) @RequestBody
			PatientRequestDTO patientRequestDTO){
		
		PatientResponseDTO patientResponseDTO = patientService.updatePatient(id, patientRequestDTO);
		
		return ResponseEntity.ok().body(patientResponseDTO);
	}
	
	@DeleteMapping("/{id}")
	@Operation(summary = "Delete a Patient")
	public ResponseEntity<Map<String, String>> deletePatient(@PathVariable UUID id) {
	    patientService.deletePatient(id);
	    return ResponseEntity.ok(Map.of("message", "Patient deleted successfully"));
	}
	
	
}