/* Reiniciar base de laboratorio */
IF DB_ID('Academia2022') IS NOT NULL
BEGIN
    ALTER DATABASE Academia2022 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Academia2022;
END
GO

CREATE DATABASE Academia2022;
GO
USE Academia2022;
GO

/* Esquemas base */
CREATE SCHEMA Academico;  -- alumnos, cursos, carreras, matrículas
GO
CREATE SCHEMA Seguridad;  -- usuarios, roles, auditoría
GO
CREATE SCHEMA App;        -- vistas expuestas a la aplicación
GO
CREATE SCHEMA Lab;        -- objetos auxiliares de práctica
GO

--**Por qué:** Reiniciar garantiza **idempotencia**. 
--Separar en esquemas (Academico/Seguridad/App/Lab) aplica 
--**principio de responsabilidad** y prepara el terreno para DDL, DCL y transacciones.


------** CREAR TABLA CON PK,UNIQUE, CHECK Y DEFAULT**** ---

------**# Semana 5 — PK, FK, UNIQUE, CHECK (Integridad Referencial y de Dominio)**** ---

--**Ejercicio 5.1 — Crear tabla con PK, UNIQUE, CHECK y DEFAULT **--

--**Enunciado.** Crea `Academico.Alumnos` con:  
--`AlumnoID INT IDENTITY PK`, `Nombre NVARCHAR(60) NOT NULL`, 
--`Apellido NVARCHAR(60) NOT NULL`, `Email NVARCHAR(120) UNIQUE`,
--`Edad TINYINT CHECK (Edad >= 16)`, `Activo BIT DEFAULT (1)`.

CREATE TABLE Academico.Alumnos(
	AlumnoID INT IDENTITY(1,1) CONSTRAINT PK_Alumnos PRIMARY KEY,
	AlumnoNombre NVARCHAR(60) NOT NULL,
	AlumnoApellido NVARCHAR(60) NOT NULL,
	AlumnoEmail NVARCHAR(120) NULL CONSTRAINT UQ_Alumnos_Email UNIQUE,
	AlumnoEdad TINYINT NOT NULL CONSTRAINT CK_Alumno_Edad CHECK (AlumnoEdad >=16),
	AlumnoActivo BIT NOT NULL CONSTRAINT DF_Alumno_Activo DEFAULT (1)
);
GO

--POR QUE?: IDENTITY(1,1) AUTO INCREMENTABLE Y DEBE INICIAR EN 1 Y SUMAR 1
-- PK PRIMARY KEY, UNIQUE EMAIL EVITA DUPLICADOS, CHECK ASEGURA REGLA DE NEGOCIO
-- CON LA EDAD Y DEFAULT DA VALOR SEGURO ESTADO DEL ALUMNO.

--** Ejercicio 5.2 — Catálogo con UNIQUE natural y FK con regla de borrado

--**Enunciado.** Crea `Academico.Carreras(Nombre UNIQUE)`
--y agrega `CarreraID` como FK **SET NULL** en `Alumnos`.

CREATE TABLE Academico.Carreras(
	CarreraID INT IDENTITY(1,1) CONSTRAINT PK_Carreras PRIMARY KEY,
	CarreraNombre NVARCHAR(80) NOT NULL CONSTRAINT UQ_Carreras_Nombre UNIQUE
);
GO

ALTER TABLE Academico.Alumnos
ADD CarreraID INT NULL CONSTRAINT FK_Alumnos_Carreras
FOREIGN KEY (CarreraID) REFERENCES Academico.Carreras(CarreraID)
ON DELETE SET NULL ON UPDATE NO ACTION;
GO
--**Por qué:** El catálogo normaliza el dominio; `SET NULL` 
--evita eliminar accidentalmente alumnos al borrar carreras.


--** Ejercicio 5.3 — Tabla Cursos con CHECK de rango y UQ **--

--**Enunciado.** Crea `Academico.Cursos` con `Creditos BETWEEN 1 AND 10` y `Nombre UNIQUE`.

CREATE TABLE Academico.Cursos(
	CursoID INT IDENTITY(1,1) CONSTRAINT PK_Cursos PRIMARY KEY,
	CursoNombre NVARCHAR(100) NOT NULL CONSTRAINT UQ_Cursos_Nombre UNIQUE,
	CursoCreditos TINYINT NOT NULL CONSTRAINT CK_Cursos_Creditos CHECK (CursoCreditos BETWEEN 1 AND 10)
);
--Por qué: Valida el **rango** permitido de créditos y evita duplicidad de nombres.
--BETWEEN:  en SQL sirve para filtrar valores dentro de un rango inclusivo 
--(incluye los extremos).
-- Columna BETWEEN valor_inferior AND valor_superior equivalente = Columna >= valor_inferior AND columna <= valor_superior
--ejemplo: SELECT * FROM Products WHERE Precio BETWEEN 100 AND 200;

--** Ejercicio 5.4 — Tabla puente N:M con PK compuesta y FKs **--

--**Enunciado.** Crea `Academico.Matriculas(AlumnoID, CursoID, Periodo CHAR(6))` 
--con PK compuesta y FKs **CASCADE**.

CREATE TABLE Academico.Matriculas(
	AlumnoID INT NOT NULL,
	CursoID INT NOT NULL,
	MatriculaPeriodo CHAR(6) NOT NULL CONSTRAINT CK_Matriculas_Periodo
		CHECK (MatriculaPeriodo LIKE '[12][0-9][0-9][S][12]'),
	CONSTRAINT PK_Matriculas PRIMARY KEY (AlumnoID, CursoID, MatriculaPeriodo),
	CONSTRAINT FK_Matriculas_Alumnos FOREIGN KEY (AlumnoID)
		REFERENCES Academico.Alumnos(AlumnoID) ON DELETE CASCADE,
	CONSTRAINT FK_Matriculas_Cursos FOREIGN KEY (CursoID)
		REFERENCES Academico.Cursos(CursoID) ON DELETE CASCADE
);
GO

--Por qué: La PK compuesta Impide duplicados lógicos(Msmo alumno-curso-periodo) y 
-- las FK's mantienen consistencia al borrar tabla Maestra -> Tabla Hija.


--*** Semana 6 — DDL avanzado: ALTER, columnas calculadas, índices, secuencias, renombres ***---

--Ejercicio 6.1 — Columna calculada **PERSISTED** e índice de cobertura

--**Enunciado.** Agrega `NombreCompleto = Nombre + ' ' + Apellido PERSISTED` en `Alumnos` y créale índice.

ALTER TABLE Academico.Alumnos
ADD NombreCompleto AS (AlumnoNombre + N' ' + AlumnoApellido) PERSISTED;

CREATE INDEX IX_Alumnos_NombreCompleto ON Academico.Alumnos(NombreCompleto);

--**Por qué:** `PERSISTED` permite **indexar** y evitar recomputo; acelera búsquedas por nombre completo.

--** Ejercicio 6.2 — Renombrar columna **--

--nunciado.** Renombra `Creditos` de `Cursos` a `CreditosECTS` (sin recrear tabla).
--PARA hacer el cambio de la columna CursoCreditos a CursoCreditosECTS, es 
-- importante tomar en cuenta el CHECK
ALTER TABLE Academico.Cursos
DROP CONSTRAINT CK_Cursos_Creditos;
GO

--renombrar columna sin el check

EXEC sp_rename
	'Academico.Cursos.CursoCreditos', --OBJETO ACTUAL
	'CursoCreditosECTS', --NEW NAME
	'COLUMN';
GO

-- Volver el check 
ALTER TABLE Academico.Cursos
ADD CONSTRAINT CK_Cursos_Creditos CHECK (CursoCreditosECTS BETWEEN 1 AND 10);
GO

--**Por qué:** `sp_rename` es la vía soportada para cambios de nombre en metadatos.

--** Ejercicio 6.3 — Índice compuesto con columnas incluidas **--

--**Enunciado.** Sobre `Matriculas`, crea índice por `(CursoID, Periodo)` con `INCLUDE (AlumnoID)`.

CREATE INDEX IX_Matriculas_Cursos_MatriculaPeriodo	
	ON Academico.Matriculas(CursoID, MatriculaPeriodo)
	INCLUDE (AlumnoID);
GO

--**Por qué:** **Cobertura**: consultas por curso+periodo devuelven alumno sin ir a la tabla base.

--** Ejercicio 6.4 — `SEQUENCE` para código visible de curso **--

--**Enunciado.** Crea `Academico.SeqCodigoCurso` e insértalo como default en columna `Codigo` de `Cursos`.

CREATE SEQUENCE Academico.SeqCodigoCurso AS INT START WITH 1000 INCREMENT BY 1;
GO
ALTER TABLE Academico.Cursos
ADD CursoCodigo INT NOT NULL
	CONSTRAINT DF_Cursos_CursoCodigo DEFAULT (NEXT VALUE FOR Academico.SeqCodigoCurso);
GO
--**Por qué:** `SEQUENCE` es **reutilizable** y configurable (reinicio/salto), más flexible que `IDENTITY` cuando la misma secuencia se usa en varias tablas.

-- ---> ***** TAREA PARA ESTUDIAR EVALUACION PARCIAL II <--- ***** --

--** Semana 7 — Diseño normalizado con DDL (aplicación práctica) **--

--** Ejercicio 7.1 — Separar datos de contacto **--

--Diseño normalizado con DDL - 

--** Ejercicio 7.1 — Separar datos de contacto **--

 --**Enunciado.** Extrae datos de contacto a `Academico.Contactos(ContactoID PK, Email UNIQUE, Telefono)`. Agrega FK `ContactoID` en `Alumnos`.
 
	CREATE TABLE Academico.Contactos(
		ContactoID INT IDENTITY(1,1) CONSTRAINT PK_Contactos PRIMARY KEY,
		Email      NVARCHAR(120) NULL CONSTRAINT UQ_Contactos_Email UNIQUE,
		Telefono   VARCHAR(20)   NULL
);
GO

ALTER TABLE Academico.Alumnos
	ADD ContactoID INT NULL
  CONSTRAINT FK_Alumnos_Contactos
  FOREIGN KEY (ContactoID) REFERENCES Academico.Contactos(ContactoID);

--**Por qué:** Reduce **redundancia** y centraliza contacto reutilizable (normalización 3FN).

--**Ejercicio 7.2 — Descomponer atributo multivalor (N:M) **--

--**Enunciado.** Agrega `Academico.AlumnoIdiomas(AlumnoID, Idioma, Nivel)` con PK compuesta.
CREATE TABLE Academico.AlumnoIdiomas(
  AlumnoID INT NOT NULL,
  Idioma   NVARCHAR(40) NOT NULL,
  Nivel    NVARCHAR(20) NOT NULL,
  CONSTRAINT PK_AlumnoIdiomas PRIMARY KEY (AlumnoID, Idioma),
  CONSTRAINT FK_AI_Alumno FOREIGN KEY (AlumnoID)
    REFERENCES Academico.Alumnos(AlumnoID) ON DELETE CASCADE
);

--**Por qué:** Un alumno puede tener **varios idiomas** (multivalor) → tabla propia N:M.

--** Ejercicio 7.3 — Evitar dependencia transitiva --**

--**Enunciado.** Mueve la descripción de carrera a su catálogo `Carreras`; `Alumnos` solo referencia `CarreraID`.

--**Solución:** *(Ya cumplido en 5.2; revalida con SELECTs)*  
--**Por qué:** Los atributos de la carrera **dependen** de `CarreraID`, no del alumno → referencia por FK.


--** Ejercicio 7.4 — Restricción de unicidad compuesta **--

--**Enunciado.** Evita que un alumno se matricule dos veces al mismo curso en el **mismo periodo** usando índice UNIQUE.

CREATE UNIQUE INDEX UQ_Matriculas_Alumno_Curso_Periodo
ON Academico.Matriculas(AlumnoID, CursoID, MatriculaPeriodo);
GO


--**Por qué:** Aunque existe PK compuesta, este índice UNIQUE es equivalente y **mejora consulta** por ese patrón.

--** Semana 8 — Transacciones y ACID (COMMIT/ROLLBACK/aislamiento) sobre Academia2022 **--

--** Ejercicio 8.1 — Transacción controlada con validación **--

--**Enunciado.** Incrementa 3% `CreditosECTS` de cursos cuyo nombre contenga “Data”. Revierte si afectas > 10 filas.

-- ✅ CORRECTO
BEGIN TRAN;

UPDATE c
SET CursoCreditosECTS = CursoCreditosECTS + CEILING(CursoCreditosECTS * 0.03)
FROM Academico.Cursos c
WHERE c.CursoNombre LIKE N'%Data%';  -- ← Cambio aquí

IF @@ROWCOUNT > 10
BEGIN
  ROLLBACK TRAN;  -- demasiados cursos afectados
END
ELSE
BEGIN
  COMMIT TRAN;
END

--**Por qué:** Evita cambios masivos involuntarios con **control de tamaño**.

--** Ejercicio 8.2 — `READ COMMITTED SNAPSHOT` para lectores sin bloqueos --**

--*Enunciado.** Habilita **RCSI** y prueba lecturas consistentes mientras otra transacción mantiene cambios abiertos.
USE master;
ALTER DATABASE Academia2022 SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
USE Academia2022;

/* Sesión A: BEGIN TRAN; UPDATE ... (no commit)
   Sesión B: SELECT ... (no se bloquea; ve versión anterior) */

--**Por qué:** Mejora **concurrencia** evitando bloqueos de lectura/escritura.

--** Ejercicio 8.3 — SAVEPOINT y ROLLBACK parcial **--

--**Enunciado.** Aumenta créditos de un conjunto, marca SAVEPOINT, aplica otra operación y revierte solo la segunda.
BEGIN TRAN;
UPDATE Academico.Cursos SET CreditosECTS = CreditosECTS + 1 WHERE CursoID <= 3;
SAVE TRAN punto1;

UPDATE Academico.Cursos SET CreditosECTS = CreditosECTS + 1 WHERE CursoID BETWEEN 4 AND 6;
-- reconsideramos:
ROLLBACK TRAN punto1;
COMMIT TRAN;

--**Por qué:** `SAVEPOINT` da **granularidad** para revertir parcialmente.

--** Ejercicio 8.4 — TRY…CATCH con seguridad de transacción** --

--**Enunciado.** Envolver operación y garantizar rollback ante error.
BEGIN TRY
  BEGIN TRAN;
  UPDATE Academico.Alumnos 
  SET AlumnoEdad = AlumnoEdad + 1  -- ← Cambio aquí
  WHERE AlumnoID <= 5;
  COMMIT TRAN;
END TRY
BEGIN CATCH
  IF XACT_STATE() <> 0 ROLLBACK TRAN;
  PRINT 'Error detectado: ' + ERROR_MESSAGE();  -- ← Para mejor diagnóstico
  THROW;
END CATCH;

--**Por qué:** Previene transacciones abiertas y facilita **diagnóstico**.

--** Semana 9 — Arquitectura, catálogo del sistema y separación por capas **--

--**Ejercicio 9.1 — Objetos por esquema (catálogo) **--

--**Enunciado.** Lista cuántos objetos tiene cada esquema.
SELECT s.name AS Esquema, o.type, COUNT(*) AS Total
FROM sys.objects o
JOIN sys.schemas s ON s.schema_id = o.schema_id
GROUP BY s.name, o.type
ORDER BY s.name, o.type;

--**Por qué:** Conocer el **inventario** guía seguridad y mantenimiento.

--** Ejercicio 9.2 — Dependencias de objeto **--

--**Enunciado.** Muestra qué objetos dependen de `Academico.Matriculas`.
SELECT referencing_schema = SCHEMA_NAME(o.schema_id),
       referencing_object = o.name
FROM sys.sql_expression_dependencies d
JOIN sys.objects o ON d.referencing_id = o.object_id
WHERE d.referenced_id = OBJECT_ID('Academico.Matriculas');

--**Por qué:** Permite **análisis de impacto** antes de cambios DDL.

--** Ejercicio 9.3 — Capa App con vistas seguras **--

--**Enunciado.** Crea `App.vw_ResumenAlumno` con info no sensible.
CREATE VIEW App.vw_ResumenAlumno
AS
SELECT a.AlumnoID, a.NombreCompleto, a.AlumnoEdad AS Edad, a.CarreraID
FROM Academico.Alumnos a
WHERE a.AlumnoActivo = 1;  -- ← Cambio: AlumnoActivo
GO

--**Por qué:** Aísla datos sensibles en tabla base; expone **superficie mínima** a apps.

--** Ejercicio 9.4 — Vista con `SCHEMABINDING` e índice --**

--**Enunciado.** Crear vista  agregada de matrículas por curso y **indexarla**.

CREATE VIEW App.vw_MatriculasPorCurso
WITH SCHEMABINDING
AS
SELECT m.CursoID, COUNT_BIG(*) AS Total
FROM Academico.Matriculas AS m
GROUP BY m.CursoID;
GO
CREATE UNIQUE CLUSTERED INDEX IX_vw_MatriculasPorCurso
ON App.vw_MatriculasPorCurso(CursoID);

--**Por qué:** `SCHEMABINDING` habilita indexación de vistas materiales, acelerando **agregados** frecuentes.

--** Semana 10 — Tipos de datos y objetos (JSON, temporal, SPARSE, computed) **--

--**Enunciado.** Crea `Lab.Eventos(Id IDENTITY PK, Payload NVARCHAR(MAX) CHECK ISJSON=1)`.
CREATE TABLE Lab.Eventos(
  Id INT IDENTITY(1,1) CONSTRAINT PK_Eventos PRIMARY KEY,
  Payload NVARCHAR(MAX) NOT NULL,
  CONSTRAINT CK_Eventos_Payload CHECK (ISJSON(Payload) = 1)
);

--**Por qué:** Permite flexibilidad manteniendo **validez mínima** del JSON.

--## Ejercicio 10.2 — Extraer propiedades de JSON
--**Enunciado.** Inserta un evento y lee `$.tipo` y `$.origen`.

INSERT INTO Lab.Eventos(Payload)
VALUES (N'{"tipo":"audit","origen":"app","entidad":"Alumno","id":1}');

SELECT JSON_VALUE(Payload, '$.tipo')   AS Tipo,
       JSON_VALUE(Payload, '$.origen') AS Origen
FROM Lab.Eventos;

--**Por qué:** `JSON_VALUE` facilita **lectura puntual** sin desnormalizar tablas principales.

--** Ejercicio 10.3 — Sparse columns para atributos opcionales **--

--**Enunciado.** Crea `Lab.AlumnoRedes(AlumnoID INT, Twitter NVARCHAR(50) SPARSE, Instagram NVARCHAR(50) SPARSE)`.
CREATE TABLE Lab.AlumnoRedes(
  AlumnoID INT NOT NULL,
  Twitter  NVARCHAR(50) SPARSE NULL,
  Instagram NVARCHAR(50) SPARSE NULL,
  CONSTRAINT FK_Redes_Alumno FOREIGN KEY (AlumnoID)
    REFERENCES Academico.Alumnos(AlumnoID) ON DELETE CASCADE
);

--**Por qué:** `SPARSE` ahorra espacio cuando abundan **NULLs**.


--** Ejercicio 10.4 — Tabla temporal del sistema (histórico) **--
--**Enunciado.** Convierte `Lab.Eventos` en **System‑Versioned** para historial automático.
DELETE FROM Lab.Eventos;
PRINT 'Datos existentes eliminados para habilitar System-Versioning';

ALTER TABLE Lab.Eventos
ADD ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START HIDDEN NOT NULL
    CONSTRAINT DF_Eventos_From DEFAULT SYSUTCDATETIME(),
    ValidTo   DATETIME2 GENERATED ALWAYS AS ROW END   HIDDEN NOT NULL
    CONSTRAINT DF_Eventos_To   DEFAULT CONVERT(DATETIME2,'9999-12-31'),
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo);

ALTER TABLE Lab.Eventos
SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = Lab.Eventos_Hist));

--**Por qué:** Guarda **versiones** automáticamente → auditoría y recuperación de estado.

--** Semana 11 — DCL I (Usuarios, Roles, Esquemas, Menor Privilegio) **--

--** Ejercicio 11.1 — Login + User con esquema por defecto **--
--**Enunciado.** Crea login/usuario `app_ro` con `DEFAULT_SCHEMA = App` y solo lectura.

USE Academia2022;
-- Crear usuario de base de datos (sin login en Azure)
IF USER_ID('app_ro') IS NOT NULL DROP USER app_ro;
CREATE USER app_ro WITHOUT LOGIN WITH DEFAULT_SCHEMA = App;
EXEC sp_addrolemember N'db_datareader', N'app_ro';


--**Por qué:** Rol `db_datareader` otorga SELECT en la base; `DEFAULT_SCHEMA` simplifica nombres calificados


--** ## Ejercicio 11.2 — Rol personalizado con permisos a vistas
--**Enunciado.** Crea rol `rol_reportes` con `SELECT` sobre `App.vw_ResumenAlumno` y `App.vw_MatriculasPorCurso` y asócialo a `app_ro`. 
CREATE ROLE rol_reportes;
GRANT SELECT ON OBJECT::App.vw_ResumenAlumno    TO rol_reportes;
GRANT SELECT ON OBJECT::App.vw_MatriculasPorCurso TO rol_reportes;
EXEC sp_addrolemember 'rol_reportes', 'app_ro';

--**Por qué:** Agregar permisos a un **rol** centraliza la administración (asigna a muchos usuarios a la vez).

--** ## Ejercicio 11.3 — Denegar acceso directo a tablas base
--**Enunciado.** Deniega `SELECT` sobre `Academico.Alumnos` a `app_ro`.

DENY SELECT ON OBJECT::Academico.Alumnos TO app_ro;

--**Por qué:** Obliga a consumir datos vía **vistas de App**, reduciendo exposición.


--** ## Ejercicio 11.4 — Sinónimos para compatibilidad **--
--**Enunciado.** Crea sinónimo `dbo.Matriculas` → `Academico.Matriculas`

CREATE SYNONYM dbo.Matriculas FOR Academico.Matriculas;

--**Por qué:** Útil para **código legado** que asume esquema `dbo`.


--** Semana 12 — DCL II (GRANT/REVOKE/DENY, RLS, Auditoría) **--

--** Ejercicio 12.1 — GRANT por esquema **--
--**Enunciado.** Concede `SELECT` sobre todo el esquema `App` al rol `rol_reportes`.

GRANT SELECT ON SCHEMA::App TO rol_reportes;

--**Por qué:** Simplifica mantenimiento; no hace falta otorgar vista por vista.

--**## Ejercicio 12.2 — REVOKE fino **--
--**Enunciado.** Quita `SELECT` sobre `App.vw_ResumenAlumno` al rol (pero deja el del esquema).


REVOKE SELECT ON OBJECT::App.vw_ResumenAlumno FROM rol_reportes;

--**Por qué:** `REVOKE` retira concesiones; si sigue teniendo permiso por esquema, **prevalece** ese permiso (tenerlo en cuenta).


--## Ejercicio 12.3 — Row‑Level Security (RLS) básica **--
--**Enunciado.** Restringe a `app_ro` para ver solo alumnos **activos** en `App.vw_ResumenAlumno` aplicando filtro en tabla base.

--**Solución (mínima conceptual):**

-- **Ejercicio 12.3 CORREGIDO — RLS**

CREATE SCHEMA Sec;
GO

CREATE FUNCTION Sec.fn_AlumnosActivos(@AlumnoActivo bit)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 AS AllowRow WHERE @AlumnoActivo = 1;
GO

CREATE SECURITY POLICY Sec.Policy_Alumnos
ADD FILTER PREDICATE Sec.fn_AlumnosActivos(AlumnoActivo)  -- ← Cambio aquí
ON Academico.Alumnos
WITH (STATE = ON);
GO

PRINT 'RLS configurado correctamente - solo alumnos activos visibles';

--**Por qué:** La política impone filtro en **tabla base**; vistas heredan la restricción.

--## Ejercicio 12.4 — Auditoría de permisos y autenticación fallida
--**Enunciado.** Configura auditoría de servidor+DB (ruta de archivos existente) para cambios de permisos e inicios de sesión fallidos.

-- Crear esquema Security
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Security')
BEGIN
    EXEC('CREATE SCHEMA Security');
END
GO

-- Crear tabla de auditoría
IF OBJECT_ID('Security.Audit_Permissions', 'U') IS NOT NULL
    DROP TABLE Security.Audit_Permissions;
GO

CREATE TABLE Security.Audit_Permissions(
    AuditID INT IDENTITY(1,1) PRIMARY KEY,
    EventTime DATETIME2 DEFAULT SYSUTCDATETIME(),
    EventType NVARCHAR(50),
    LoginName SYSNAME DEFAULT SUSER_NAME(),
    DatabaseUser SYSNAME DEFAULT ORIGINAL_LOGIN(),
    ObjectName NVARCHAR(256),
    PermissionType NVARCHAR(100),
    Success BIT,
    Details NVARCHAR(MAX)
);
GO

-- Procedimiento para cambios de permisos
CREATE OR ALTER PROCEDURE Security.sp_AuditPermissionChange
    @ObjectName NVARCHAR(256),
    @PermissionType NVARCHAR(100),
    @Granted BIT,
    @Details NVARCHAR(MAX) = NULL
AS
BEGIN
    INSERT INTO Security.Audit_Permissions (EventType, ObjectName, PermissionType, Success, Details)
    VALUES ('PERMISSION_CHANGE', @ObjectName, @PermissionType, @Granted, @Details);
END
GO

-- Procedimiento para logins fallidos
CREATE OR ALTER PROCEDURE Security.sp_AuditFailedLogin
    @LoginName SYSNAME,
    @Details NVARCHAR(MAX) = NULL
AS
BEGIN
    INSERT INTO Security.Audit_Permissions (EventType, LoginName, Success, Details)
    VALUES ('LOGIN_FAILED', @LoginName, 0, @Details);
END
GO

-- Vista para reportes (SIN ORDER BY problemático)
CREATE OR ALTER VIEW Security.vw_AuditReport
AS
SELECT TOP (100) PERCENT
    EventTime,
    EventType,
    LoginName,
    DatabaseUser,
    ObjectName,
    PermissionType,
    CASE Success WHEN 1 THEN 'SÍ' ELSE 'NO' END AS Exito,
    Details
FROM Security.Audit_Permissions
WHERE EventTime >= DATEADD(HOUR, -24, SYSUTCDATETIME());
GO

-- Demostración
EXEC Security.sp_AuditPermissionChange 
    @ObjectName = 'Academico.Alumnos', 
    @PermissionType = 'SELECT', 
    @Granted = 1,
    @Details = 'GRANT ejecutado manualmente';
GO

EXEC Security.sp_AuditFailedLogin 
    @LoginName = 'app_ro',
    @Details = '3 intentos fallidos de login';
GO

-- Simular cambios de permisos reales
BEGIN TRY
    GRANT SELECT ON Academico.Cursos TO app_ro;
    EXEC Security.sp_AuditPermissionChange 
        @ObjectName = 'Academico.Cursos', 
        @PermissionType = 'SELECT', 
        @Granted = 1;
END TRY
BEGIN CATCH
    PRINT 'No se pudo hacer GRANT (permisos insuficientes)';
END CATCH
GO

BEGIN TRY
    REVOKE SELECT ON Academico.Cursos FROM app_ro;
    EXEC Security.sp_AuditPermissionChange 
        @ObjectName = 'Academico.Cursos', 
        @PermissionType = 'SELECT', 
        @Granted = 0;
END TRY
BEGIN CATCH
    PRINT 'No se pudo hacer REVOKE (permisos insuficientes)';
END CATCH
GO

-- PASO 7: Mostrar resultados
SELECT * FROM Security.vw_AuditReport;
GO

-- PASO 8: Resumen
SELECT 
    EventType,
    COUNT(*) AS TotalEventos,
    MIN(EventTime) AS PrimerEvento,
    MAX(EventTime) AS UltimoEvento
FROM Security.Audit_Permissions
GROUP BY EventType;
GO



-- Ver todo el sistema de auditoría
SELECT 
    'Resumen Auditoría' AS Informe,
    COUNT(*) AS TotalEventos
FROM Security.Audit_Permissions;


SELECT TOP 3 
    EventTime,
    EventType,
    CASE WHEN EventType = 'PERMISSION_CHANGE' THEN PermissionType ELSE LoginName END AS Detalle,
    CASE Success WHEN 1 THEN 'ÉXITO' ELSE 'FALLO' END AS Estado
FROM Security.vw_AuditReport
ORDER BY EventTime DESC;
GO


--ingreso

--** DATOS DE PRUEBA **

USE Academia2022;
GO

-- 1. ALUMNOS (10 registros variados)
IF NOT EXISTS (SELECT 1 FROM Academico.Alumnos WHERE AlumnoID = 1)
BEGIN
    INSERT INTO Academico.Alumnos (AlumnoNombre, AlumnoApellido, AlumnoEmail, AlumnoEdad, AlumnoActivo)
    VALUES 
        ('Juan', 'Pérez', 'juan.perez@academia.com', 20, 1),
        ('María', 'García', 'maria.garcia@academia.com', 22, 1),
        ('Carlos', 'López', 'carlos.lopez@academia.com', 19, 0), -- Inactivo para RLS
        ('Ana', 'Martínez', 'ana.martinez@academia.com', 21, 1),
        ('Luis', 'Rodríguez', 'luis.rodriguez@academia.com', 23, 1),
        ('Sofía', 'Hernández', 'sofia.hernandez@academia.com', 18, 1),
        ('Miguel', 'González', 'miguel.gonzalez@academia.com', 25, 0), -- Inactivo
        ('Laura', 'Sánchez', 'laura.sanchez@academia.com', 20, 1),
        ('Diego', 'Torres', 'diego.torres@academia.com', 22, 1),
        ('Elena', 'Ramírez', 'elena.ramirez@academia.com', 19, 1);
    
    PRINT '10 alumnos insertados (5 activos, 5 inactivos)';
END
GO

-- 2. CARRERAS (4 registros)
IF NOT EXISTS (SELECT 1 FROM Academico.Carreras WHERE CarreraID = 1)
BEGIN
    INSERT INTO Academico.Carreras (CarreraNombre)
    VALUES 
        ('Ingeniería de Software'),
        ('Administración de Empresas'),
        ('Diseño Gráfico'),
        ('Ciencias de Datos');
    
    PRINT '4 carreras insertadas';
END
GO

-- 3. CURSOS (8 registros)
IF NOT EXISTS (SELECT 1 FROM Academico.Cursos WHERE CursoID = 1)
BEGIN
    INSERT INTO Academico.Cursos (CursoNombre, CursoCreditosECTS)  -- ← Solo ECTS
    VALUES 
        ('Programación Web', 6),
        ('Base de Datos', 4),
        ('Análisis de Datos', 5),
        ('Marketing Digital', 3),
        ('Diseño UX/UI', 4),
        ('Machine Learning', 6),
        ('SQL Avanzado', 3),
        ('Big Data', 6);
    
    PRINT '8 cursos insertados CORRECTAMENTE';
END
GO
GO

-- 4. CONTACTOS (6 registros)
IF NOT EXISTS (SELECT 1 FROM Academico.Contactos WHERE ContactoID = 1)
BEGIN
    INSERT INTO Academico.Contactos (Email, Telefono)
    VALUES 
        ('juan.perez@academia.com', '+52-55-1234-5678'),
        ('maria.garcia@academia.com', '+52-55-8765-4321'),
        ('ana.martinez@academia.com', '+52-55-1111-2222'),
        ('luis.rodriguez@academia.com', '+52-55-3333-4444'),
        ('sofia.hernandez@academia.com', '+52-55-5555-6666'),
        ('laura.sanchez@academia.com', '+52-55-7777-8888');
    
    PRINT '6 contactos insertados';
END
GO

-- 5. ASIGNAR CONTACTOS A ALUMNOS
UPDATE Academico.Alumnos SET ContactoID = 1 WHERE AlumnoID = 1;
UPDATE Academico.Alumnos SET ContactoID = 2 WHERE AlumnoID = 2;
UPDATE Academico.Alumnos SET ContactoID = 3 WHERE AlumnoID = 4;
UPDATE Academico.Alumnos SET ContactoID = 4 WHERE AlumnoID = 5;
UPDATE Academico.Alumnos SET ContactoID = 5 WHERE AlumnoID = 6;
UPDATE Academico.Alumnos SET ContactoID = 6 WHERE AlumnoID = 8;

PRINT 'Contactos asignados a alumnos';
GO

-- 6. ASIGNAR CARRERAS A ALUMNOS
UPDATE Academico.Alumnos SET CarreraID = 1 WHERE AlumnoID IN (1, 4, 5);
UPDATE Academico.Alumnos SET CarreraID = 2 WHERE AlumnoID IN (2, 8, 9);
UPDATE Academico.Alumnos SET CarreraID = 3 WHERE AlumnoID IN (6, 10);
UPDATE Academico.Alumnos SET CarreraID = 4 WHERE AlumnoID = 3;

PRINT 'Carreras asignadas a alumnos';
GO

-- 7. IDIOMAS (N:M - 8 registros)
IF NOT EXISTS (SELECT 1 FROM Academico.AlumnoIdiomas)
BEGIN
    INSERT INTO Academico.AlumnoIdiomas (AlumnoID, Idioma, Nivel)
    VALUES 
        (1, 'Español', 'Nativo'),
        (1, 'Inglés', 'Avanzado'),
        (2, 'Español', 'Nativo'),
        (2, 'Inglés', 'Intermedio'),
        (4, 'Español', 'Nativo'),
        (4, 'Francés', 'Básico'),
        (5, 'Español', 'Nativo'),
        (5, 'Inglés', 'Avanzado');
    
    PRINT '8 registros de idiomas insertados';
END
GO

-- 8. MATRÍCULAS (12 registros)
IF NOT EXISTS (SELECT 1 FROM Academico.Matriculas WHERE AlumnoID = 1)
BEGIN
    INSERT INTO Academico.Matriculas (AlumnoID, CursoID, MatriculaPeriodo)
    VALUES 
        (1, 1, '2025S1'), (1, 2, '2025S1'), (1, 7, '2025S1'),
        (2, 3, '2025S1'), (2, 4, '2025S1'),
        (4, 1, '2025S1'), (4, 5, '2025S1'),
        (5, 2, '2025S1'), (5, 6, '2025S1'),
        (6, 3, '2025S1'), (6, 8, '2025S1'),
        (8, 7, '2025S1'), (8, 4, '2025S1');
    
    PRINT '12 matrículas insertadas - Formato 2025S1';
END
GO




-- 9. REDES SOCIALES (SPARSE - 4 registros)
INSERT INTO Lab.AlumnoRedes (AlumnoID, Twitter, Instagram)
VALUES 
    (1, '@juan_perez_dev', '@juanperezdesign'),
    (2, NULL, '@mariagarcia_mkt'),
    (4, '@ana_martinez_ux', NULL),
    (5, '@luis_dev', '@luisrodriguez_code');

PRINT '4 registros de redes sociales insertados';
GO

-- 10. EVENTOS JSON (3 registros)
INSERT INTO Lab.Eventos (Payload)
VALUES 
    (N'{"tipo":"login","usuario":"juan.perez","ip":"192.168.1.100","exito":true}'),
    (N'{"tipo":"matricula","alumno":1,"curso":"Programación Web","periodo":"2025S1"}'),
    (N'{"tipo":"update","entidad":"alumno","id":2,"campo":"edad","valor_anterior":22,"valor_nuevo":23}');

PRINT '3 eventos JSON insertados';
GO

-- 11. AUDITORÍA ADICIONAL (3 eventos más)
EXEC Security.sp_AuditPermissionChange 
    @ObjectName = 'Academico.Cursos', 
    @PermissionType = 'INSERT', 
    @Granted = 1,
    @Details = 'Nuevo permiso para app_ro';

EXEC Security.sp_AuditFailedLogin 
    @LoginName = 'admin_test',
    @Details = 'Acceso bloqueado por seguridad';

EXEC Security.sp_AuditPermissionChange 
    @ObjectName = 'App.vw_ResumenAlumno', 
    @PermissionType = 'SELECT', 
    @Granted = 0,
    @Details = 'Revocado acceso temporal';

PRINT '3 eventos adicionales de auditoría';
GO

-- Verificar matrículas
SELECT 
    m.AlumnoID,
    c.CursoNombre,
    m.MatriculaPeriodo,
    CASE 
        WHEN m.MatriculaPeriodo LIKE '%2025S1' THEN 'FORMATO CORRECTO'
        ELSE 'FORMATO INVÁLIDO'
    END AS Validacion
FROM Academico.Matriculas m
JOIN Academico.Cursos c ON m.CursoID = c.CursoID
ORDER BY m.AlumnoID, c.CursoNombre;
GO

-- Resumen general
SELECT 
    'RESUMEN FINAL' AS Informe,
    COUNT(*) AS TotalMatriculas
FROM Academico.Matriculas;
GO


--Examen:
--A1)
-- 1. Crear columna CarreraID 
IF NOT EXISTS (SELECT * FROM sys.columns 
               WHERE object_id = OBJECT_ID('Academico.Alumnos') 
               AND name = 'CarreraID')
BEGIN
    ALTER TABLE Academico.Alumnos
    ADD CarreraID INT NULL;
    
    PRINT 'Columna CarreraID agregada a Academico.Alumnos';
END
ELSE
BEGIN
    PRINT 'Columna CarreraID ya existe';
END
GO

-- 2. Crear FK con ON DELETE SET NULL
IF NOT EXISTS (SELECT * FROM sys.foreign_keys 
               WHERE name = 'FK_Alumnos_Carreras')
BEGIN
    ALTER TABLE Academico.Alumnos
    ADD CONSTRAINT FK_Alumnos_Carreras 
    FOREIGN KEY (CarreraID) REFERENCES Academico.Carreras(CarreraID)
    ON DELETE SET NULL
    ON UPDATE NO ACTION;
    
    PRINT 'FK FK_Alumnos_Carreras creada con ON DELETE SET NULL';
END
ELSE
BEGIN
    PRINT 'FK FK_Alumnos_Carreras ya existe';
END
GO

--DEMOSTRACIÓN A1
-- VERIFICACIÓN A1: 

BEGIN
  
    DECLARE @CarreraPruebaID INT;
    DECLARE @AlumnoPruebaID INT;
    
    PRINT 'Variables declaradas correctamente';
    
    -- 1. Crear carrera de prueba
    INSERT INTO Academico.Carreras (CarreraNombre)
    SELECT 'Carrera de Prueba SET NULL A1' 
    WHERE NOT EXISTS (SELECT 1 FROM Academico.Carreras WHERE CarreraNombre = 'Carrera de Prueba SET NULL A1');
    
    SET @CarreraPruebaID = SCOPE_IDENTITY();
    PRINT 'Carrera de prueba creada con ID: ' + CAST(@CarreraPruebaID AS VARCHAR(10));
    
    -- 2. Crear alumno y asignar la carrera
    INSERT INTO Academico.Alumnos (AlumnoNombre, AlumnoApellido, AlumnoEmail, AlumnoEdad, AlumnoActivo, CarreraID)
    SELECT 'Test', 'SETNULL_A1', 'test.setnull_a1@examen.com', 21, 1, @CarreraPruebaID
    WHERE NOT EXISTS (SELECT 1 FROM Academico.Alumnos WHERE AlumnoEmail = 'test.setnull_a1@examen.com');
    
    SET @AlumnoPruebaID = SCOPE_IDENTITY();
    PRINT 'Alumno de prueba creado con ID: ' + CAST(@AlumnoPruebaID AS VARCHAR(10));
    PRINT 'Alumno asignado a Carrera ID: ' + CAST(@CarreraPruebaID AS VARCHAR(10));
    
    -- 3. VER ESTADO ANTES DE ELIMINAR CARRERA
    PRINT '';
    PRINT '=== ESTADO ANTES DE ELIMINAR CARRERA ===';
    SELECT 
        a.AlumnoID,
        a.AlumnoNombre + ' ' + a.AlumnoApellido AS AlumnoCompleto,
        a.CarreraID,
        c.CarreraNombre,
        'ASIGNADA ✓' AS Estado
    FROM Academico.Alumnos a
    JOIN Academico.Carreras c ON a.CarreraID = c.CarreraID
    WHERE a.AlumnoID = @AlumnoPruebaID;
    
    -- 4. ELIMINAR LA CARRERA (SIN BORRAR AL ALUMNO)
    PRINT '';
    PRINT ' === ELIMINANDO CARRERA (ON DELETE SET NULL) ===';
    DELETE FROM Academico.Carreras WHERE CarreraID = @CarreraPruebaID;
    
    PRINT 'Carrera eliminada - ON DELETE SET NULL debería ejecutarse';
    
    -- 5. VER ESTADO DESPUÉS DE ELIMINAR CARRERA
    PRINT '';
    PRINT '=== ESTADO DESPUÉS DE ELIMINAR CARRERA ===';
    SELECT 
        a.AlumnoID,
        a.AlumnoNombre + ' ' + a.AlumnoApellido AS AlumnoCompleto,
        a.CarreraID,
        ISNULL(c.CarreraNombre, 'NULL (SET NULL ejecutado)') AS Carrera,
        CASE 
            WHEN a.CarreraID IS NULL THEN 'SET NULL FUNCIONANDO'
            ELSE 'SET NULL NO EJECUTÓ'
        END AS Verificacion
    FROM Academico.Alumnos a
    LEFT JOIN Academico.Carreras c ON a.CarreraID = c.CarreraID
    WHERE a.AlumnoID = @AlumnoPruebaID;
    
    -- 6. CONFIRMACIÓN FINAL
    PRINT '';
    PRINT '=== VERIFICACIÓN FINAL A1 ===';
    PRINT 'Resultado: El alumno mantiene su registro pero CarreraID = NULL';
    PRINT 'Demostrado: ON DELETE SET NULL funciona correctamente ✓';
    PRINT '====================================';
END

--A2:
-- LIMPIEZA COMPLETA PARA A2
USE Academia2022;
GO

-- 1. Eliminar vista que referencia la tabla
IF OBJECT_ID('App.vw_MatriculasPorCurso', 'V') IS NOT NULL
    DROP VIEW App.vw_MatriculasPorCurso;
GO

-- 2. Eliminar tabla existente 
IF OBJECT_ID('Academico.Matriculas', 'U') IS NOT NULL
    DROP TABLE Academico.Matriculas;
GO

-- 3. 
CREATE TABLE Academico.Matriculas (
    AlumnoID INT NOT NULL,
    CursoID INT NOT NULL,
    Periodo CHAR(6) NOT NULL,
    
    CONSTRAINT PK_Matriculas PRIMARY KEY (AlumnoID, CursoID, Periodo),
    CONSTRAINT FK_Matriculas_Alumnos FOREIGN KEY (AlumnoID) REFERENCES Academico.Alumnos(AlumnoID) ON DELETE CASCADE,
    CONSTRAINT FK_Matriculas_Cursos FOREIGN KEY (CursoID) REFERENCES Academico.Cursos(CursoID) ON DELETE CASCADE,
    CONSTRAINT CK_Matriculas_Periodo CHECK (Periodo LIKE '[12][0-9][0-9][0-9][S][12]')
);
GO

-- 4. Insertar matrícula válida
INSERT INTO Academico.Matriculas (AlumnoID, CursoID, Periodo)
VALUES (1, 1, '2025S1');
GO

-- 5. Verificar inserción
SELECT 
    AlumnoID,
    CursoID,
    Periodo
FROM Academico.Matriculas;
GO

--A3:
-- A3) Verificación de error FK con TRY/CATCH
BEGIN TRY
    INSERT INTO Academico.Alumnos (AlumnoNombre, AlumnoApellido, AlumnoEmail, AlumnoEdad, AlumnoActivo, CarreraID)
    VALUES ('Test', 'FK_ERROR', 'test.fk_error@examen.com', 20, 1, 999);
END TRY
BEGIN CATCH
    PRINT 'Error FK: ' + ERROR_MESSAGE();
    PRINT 'Número: ' + CAST(ERROR_NUMBER() AS VARCHAR(10));
END CATCH

-- Verificar que no se insertó
SELECT COUNT(*) AS IntentosFallidos 
FROM Academico.Alumnos 
WHERE AlumnoEmail = 'test.fk_error@examen.com';

--A4)
-- A4) Crear UNIQUE constraint en CursoNombre
IF NOT EXISTS (SELECT * FROM sys.indexes 
               WHERE object_id = OBJECT_ID('Academico.Cursos') 
               AND name = 'UQ_Cursos_Nombre')
BEGIN
    ALTER TABLE Academico.Cursos
    ADD CONSTRAINT UQ_Cursos_Nombre UNIQUE (CursoNombre);
    
    PRINT 'UNIQUE constraint creada en CursoNombre';
END

-- Verificación: Intentar insertar duplicado
BEGIN TRY
    INSERT INTO Academico.Cursos (CursoNombre, CursoCreditosECTS)
    VALUES ('Programación Web', 6);
END TRY
BEGIN CATCH
    PRINT 'Error UNIQUE: ' + ERROR_MESSAGE();
    PRINT 'Número: ' + CAST(ERROR_NUMBER() AS VARCHAR(10));
END CATCH

-- Verificar que no se insertó duplicado
SELECT COUNT(*) AS Cursos_Duplicados 
FROM Academico.Cursos 
WHERE CursoNombre = 'Programación Web';


-- A5) Verificación CHECK en Periodo
BEGIN TRY
    INSERT INTO Academico.Matriculas (AlumnoID, CursoID, Periodo)
    VALUES (1, 1, '25S3'); -- Invalido
END TRY
BEGIN CATCH
    PRINT 'Error CHECK (25S3): ' + ERROR_MESSAGE();
    PRINT 'Número: ' + CAST(ERROR_NUMBER() AS VARCHAR(10));
END CATCH

BEGIN TRY
    INSERT INTO Academico.Matriculas (AlumnoID, CursoID, Periodo)
    VALUES (1, 1, '202S1'); -- Invalido
END TRY
BEGIN CATCH
    PRINT 'Error CHECK (202S1): ' + ERROR_MESSAGE();
    PRINT 'Número: ' + CAST(ERROR_NUMBER() AS VARCHAR(10));
END CATCH

INSERT INTO Academico.Matriculas (AlumnoID, CursoID, Periodo)
VALUES (2, 2, '2025S1'); -- Valido y único

-- Verificar inserciones
SELECT AlumnoID, CursoID, Periodo 
FROM Academico.Matriculas 
WHERE Periodo IN ('25S3', '202S1', '2025S1');


-- A6) Demostración de ON DELETE CASCADE
-- Estado antes de eliminar
PRINT 'Estado antes de eliminar Alumno:';
SELECT m.AlumnoID, a.AlumnoNombre, m.CursoID, m.Periodo 
FROM Academico.Matriculas m
JOIN Academico.Alumnos a ON m.AlumnoID = a.AlumnoID
WHERE m.AlumnoID = 1;

-- Eliminar Alumno con CASCADE
DELETE FROM Academico.Alumnos 
WHERE AlumnoID = 1;

-- Estado después de eliminar
PRINT 'Estado después de eliminar Alumno:';
SELECT m.AlumnoID, a.AlumnoNombre, m.CursoID, m.Periodo 
FROM Academico.Matriculas m
JOIN Academico.Alumnos a ON m.AlumnoID = a.AlumnoID
WHERE m.AlumnoID = 1;




