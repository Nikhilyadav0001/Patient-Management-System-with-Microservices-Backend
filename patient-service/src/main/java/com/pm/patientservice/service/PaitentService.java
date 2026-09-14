package com.pm.patientservice.service;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import com.pm.patientservice.grpc.BillingServiceGrpcClient;
import com.pm.patientservice.kafka.KafkaProducer;
import org.springframework.stereotype.Service;

import com.pm.patientservice.dto.PatientRequestDTO;
import com.pm.patientservice.dto.PatientResponseDTO;
import com.pm.patientservice.exception.EmailAlreadyExistsException;
import com.pm.patientservice.exception.PatientNotFoundException;
import com.pm.patientservice.mapper.PatientMapper;
import com.pm.patientservice.model.Patient;
import com.pm.patientservice.repository.PatientRepository;

@Service
public class PaitentService {

	private final PatientRepository patientRepository;
	private final BillingServiceGrpcClient billingServiceGrpcClient;
	private final KafkaProducer kafkaProducer;



	PaitentService(PatientRepository patientRepository, BillingServiceGrpcClient billingServiceGrpcClient, KafkaProducer kafkaProducer) {

		this.patientRepository = patientRepository;
        this.billingServiceGrpcClient = billingServiceGrpcClient;
		this.kafkaProducer = kafkaProducer;
	}
	
	//get paitents
	public List<PatientResponseDTO> getPatients(){
		List<Patient> patients = patientRepository.findAll();
		
		return patients.stream()
				.map(PatientMapper::toDTO).toList();
	}
	
	//create patient
	public PatientResponseDTO createPatient(PatientRequestDTO patientRequestDTO) {
		
		if (patientRepository.existsByEmail(patientRequestDTO.getEmail())) {
		      throw new EmailAlreadyExistsException(
		          "A patient with this email " + "already exists"
		              + patientRequestDTO.getEmail());
		    }
		
		
		Patient newPatient = patientRepository.save(
				PatientMapper.toModel(patientRequestDTO));

		billingServiceGrpcClient.createBillingAccount(newPatient.getId().toString(),
				newPatient.getName(),newPatient.getEmail());

		kafkaProducer.sendEvent(newPatient);

		return PatientMapper.toDTO(newPatient);
	
	}
	
	//update patient
	public PatientResponseDTO updatePatient(
			UUID id , PatientRequestDTO patientRequestDTO) {
		
		Patient patient = patientRepository.findById(id).orElseThrow(
		        () -> new PatientNotFoundException("Patient not found with ID: " + id));
		
		// Check if the email already exists for patient with a different ID
		if (patientRepository.existsByEmailAndIdNot(patientRequestDTO.getEmail(),
		        id)) {
		      throw new EmailAlreadyExistsException(
		          "A patient with this email " + "already exists"
		              + patientRequestDTO.getEmail());
		    }
		
		patient.setName(patientRequestDTO.getName());
		patient.setEmail(patientRequestDTO.getEmail());
		patient.setAddress(patientRequestDTO.getAddress());
		patient.setDateOfBirth(LocalDate.parse(patientRequestDTO.getDateOfBirth()));
		
		Patient  updatedPatient = patientRepository.save(patient);
		return PatientMapper.toDTO(updatedPatient);
	}
	
	//delete patient
	public void deletePatient(UUID id) {
		patientRepository.deleteById(id);
	  }
	
}