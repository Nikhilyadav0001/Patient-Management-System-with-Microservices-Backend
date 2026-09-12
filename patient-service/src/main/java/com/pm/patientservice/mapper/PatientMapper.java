package com.pm.patientservice.mapper;

import java.time.LocalDate;

import com.pm.patientservice.dto.PatientRequestDTO;
import com.pm.patientservice.dto.PatientResponseDTO;
import com.pm.patientservice.model.Patient;

public class PatientMapper {

	public static PatientResponseDTO toDTO(Patient patient) {
		
		PatientResponseDTO patientDTO = new PatientResponseDTO();
		
		patientDTO.setId(patient.getId().toString());
		patientDTO.setName(patient.getName().toString());
		patientDTO.setAddress(patient.getAddress().toString());
		patientDTO.setEmail(patient.getEmail().toString());
		patientDTO.setDateOfBirth(patient.getDateOfBirth().toString());
		
		return patientDTO;
	}
	
	public static Patient toModel(PatientRequestDTO patientDTO) {
		
		Patient patient = new Patient();
	
		patient.setName(patientDTO.getName());
		patient.setAddress(patientDTO.getAddress());
		patient.setEmail(patientDTO.getEmail());
		patient.setDateOfBirth(LocalDate.parse( patientDTO.getDateOfBirth()));
		patient.setRegisteredDate(LocalDate.parse(patientDTO.getRegisteredDate()));
		
		return patient;
	}
}
