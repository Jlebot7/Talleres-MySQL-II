-- =====================================================
-- CASO 2: NORMALIZACIÓN Y MIGRACIÓN
-- Base de datos hospitalaria
-- Resultado: 6 tablas
-- =====================================================

CREATE DATABASE IF NOT EXISTS RegistroHospital;
USE RegistroHospital;

-- -----------------------------------------------------
-- 1. TABLA ESPECIALIDADES
-- -----------------------------------------------------
CREATE TABLE Especialidades (
    EspecialidadID INT AUTO_INCREMENT PRIMARY KEY,
    NombreEspecialidad VARCHAR(100) NOT NULL UNIQUE
);

-- -----------------------------------------------------
-- 2. TABLA MEDICOS
-- -----------------------------------------------------
CREATE TABLE Medicos (
    MedicoID INT PRIMARY KEY,
    NombreMedico VARCHAR(100) NOT NULL,
    EspecialidadID INT NOT NULL,
    CONSTRAINT FK_Medicos_Especialidades
        FOREIGN KEY (EspecialidadID)
        REFERENCES Especialidades(EspecialidadID)
);

-- -----------------------------------------------------
-- 3. TABLA PACIENTES
-- -----------------------------------------------------
CREATE TABLE Pacientes (
    PacienteID INT PRIMARY KEY,
    NombrePaciente VARCHAR(100) NOT NULL,
    FechaNacimiento DATE NOT NULL
);

-- -----------------------------------------------------
-- 4. TABLA VISITAS
-- -----------------------------------------------------
CREATE TABLE Visitas (
    VisitaID INT AUTO_INCREMENT PRIMARY KEY,
    PacienteID INT NOT NULL,
    MedicoID INT NOT NULL,
    FechaVisita DATETIME NOT NULL,

    CONSTRAINT FK_Visitas_Pacientes
        FOREIGN KEY (PacienteID)
        REFERENCES Pacientes(PacienteID),

    CONSTRAINT FK_Visitas_Medicos
        FOREIGN KEY (MedicoID)
        REFERENCES Medicos(MedicoID)
);

-- -----------------------------------------------------
-- 5. TABLA MEDICAMENTOS
-- -----------------------------------------------------
CREATE TABLE Medicamentos (
    MedicamentoID INT AUTO_INCREMENT PRIMARY KEY,
    NombreMedicamento VARCHAR(100) NOT NULL UNIQUE
);

-- -----------------------------------------------------
-- 6. TABLA TRATAMIENTOS
-- -----------------------------------------------------
CREATE TABLE Tratamientos (
    TratamientoID INT AUTO_INCREMENT PRIMARY KEY,
    VisitaID INT NOT NULL,
    DescripcionTratamiento VARCHAR(255) NOT NULL,
    MedicamentoID INT NOT NULL,
    Dosis VARCHAR(50) NOT NULL,

    CONSTRAINT FK_Tratamientos_Visitas
        FOREIGN KEY (VisitaID)
        REFERENCES Visitas(VisitaID),

    CONSTRAINT FK_Tratamientos_Medicamentos
        FOREIGN KEY (MedicamentoID)
        REFERENCES Medicamentos(MedicamentoID)
);