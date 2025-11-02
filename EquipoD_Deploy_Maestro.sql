/*******************************************************************************
 * SCRIPT MAESTRO DE DESPLIEGUE - EQUIPO D
 * Proyecto Final - Módulo III - Academia2022
 * 
 * Seguridad, RLS y Operaciones
 * Compatible: Azure SQL Database y SQL Server Local
 * 
 * EJECUCIÓN: Este script es IDEMPOTENTE - puede ejecutarse múltiples veces
 * 
 * ORDEN DE DESPLIEGUE:
 * 1. Verificación de prerequisitos
 * 2. Creación de roles
 * 3. Tablas de seguridad y auditoría
 * 4. Row-Level Security (RLS)
 * 5. Stored procedures
 * 6. Vistas de monitoreo
 * 7. Permisos y grants
 * 8. Validación final
 ******************************************************************************/

USE Academia2022;
GO

SET NOCOUNT ON;
GO

PRINT '╔════════════════════════════════════════════════════════════════════════════╗';
PRINT '║                   DESPLIEGUE MAESTRO - EQUIPO D                            ║';
PRINT '║             Seguridad, RLS y Operaciones - Academia2022                    ║';
PRINT '╚════════════════════════════════════════════════════════════════════════════╝';
PRINT '';
PRINT 'Fecha de ejecución: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT 'Base de datos: ' + DB_NAME();
PRINT 'Servidor: ' + @@SERVERNAME;
PRINT 'Versión SQL: ' + CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR);
PRINT '';

-- ============================================================================
-- FASE 1: VERIFICACIÓN DE PREREQUISITOS
-- ============================================================================

PRINT '───────────────────────────────────────────────────────────────────────────';
PRINT 'FASE 1: VERIFICANDO PREREQUISITOS';
PRINT '───────────────────────────────────────────────────────────────────────────';

-- Verificar que existe el esquema Seguridad
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Seguridad')
BEGIN
    PRINT '✗ Error: Esquema Seguridad no existe';
    PRINT '  Solución: Ejecutar primero el script base ScriptSQLFinalMod-2.sql';
    RAISERROR('Prerequisitos no cumplidos', 16, 1);
    RETURN;
END

-- Verificar que existen tablas base
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Alumnos' AND SCHEMA_NAME(schema_id) = 'Academico')
BEGIN
    PRINT '✗ Error: Tabla Academico.Alumnos no existe';
    PRINT '  Solución: Ejecutar primero el script base';
    RAISERROR('Tablas base no encontradas', 16, 1);
    RETURN;
END

PRINT '✓ Esquema Seguridad: OK';
PRINT '✓ Tablas base: OK';
PRINT '';

-- ============================================================================
-- FASE 2: CREACIÓN DE ROLES
-- ============================================================================

PRINT '───────────────────────────────────────────────────────────────────────────';
PRINT 'FASE 2: CREANDO ROLES DE SEGURIDAD';
PRINT '───────────────────────────────────────────────────────────────────────────';

-- Rol AppReader
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'AppReader' AND type = 'R')
BEGIN
    CREATE ROLE AppReader;
    PRINT '✓ Rol AppReader creado';
END
ELSE
    PRINT '• Rol AppReader ya existe (idempotente)';

-- Rol AppWriter  
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'AppWriter' AND type = 'R')
BEGIN
    CREATE ROLE AppWriter;
    PRINT '✓ Rol AppWriter creado';
END
ELSE
    PRINT '• Rol AppWriter ya existe (idempotente)';

-- Rol AuditorDB
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'AuditorDB' AND type = 'R')
BEGIN
    CREATE ROLE AuditorDB;
    PRINT '✓ Rol AuditorDB creado';
END
ELSE
    PRINT '• Rol AuditorDB ya existe (idempotente)';

PRINT '';

-- ============================================================================
-- FASE 3: TABLAS DE SEGURIDAD Y AUDITORÍA
-- ============================================================================

PRINT '───────────────────────────────────────────────────────────────────────────';
PRINT 'FASE 3: CREANDO TABLAS DE SEGURIDAD';
PRINT '───────────────────────────────────────────────────────────────────────────';

-- Tabla AuditoriaAccesos
IF OBJECT_ID('Seguridad.AuditoriaAccesos', 'U') IS NOT NULL
BEGIN
    PRINT '• Tabla Seguridad.AuditoriaAccesos ya existe (preservando datos)';
END
ELSE
BEGIN
    CREATE TABLE Seguridad.AuditoriaAccesos (
        AuditoriaID INT IDENTITY(1,1) CONSTRAINT PK_AuditoriaAccesos PRIMARY KEY,
        Usuario NVARCHAR(128) NOT NULL,
        Accion NVARCHAR(50) NOT NULL,
        Tabla NVARCHAR(128) NOT NULL,
        AlumnoID INT NULL,
        FechaHora DATETIME2 NOT NULL CONSTRAINT DF_AuditoriaAccesos_FechaHora DEFAULT SYSDATETIME(),
        IP NVARCHAR(45) NULL,
        Aplicacion NVARCHAR(128) NULL
    );
    
    CREATE INDEX IX_AuditoriaAccesos_FechaHora ON Seguridad.AuditoriaAccesos(FechaHora DESC);
    CREATE INDEX IX_AuditoriaAccesos_Usuario ON Seguridad.AuditoriaAccesos(Usuario);
    
    PRINT '✓ Tabla Seguridad.AuditoriaAccesos creada con índices';
END

-- Tabla SesionAlumno
IF OBJECT_ID('Seguridad.SesionAlumno', 'U') IS NOT NULL
BEGIN
    PRINT '• Tabla Seguridad.SesionAlumno ya existe (preservando datos)';
END
ELSE
BEGIN
    CREATE TABLE Seguridad.SesionAlumno (
        SessionID INT IDENTITY(1,1) CONSTRAINT PK_SesionAlumno PRIMARY KEY,
        Usuario NVARCHAR(128) NOT NULL,
        AlumnoID INT NOT NULL,
        FechaInicio DATETIME2 NOT NULL CONSTRAINT DF_SesionAlumno_FechaInicio DEFAULT SYSDATETIME(),
        FechaExpiracion DATETIME2 NULL,
        Activa BIT NOT NULL CONSTRAINT DF_SesionAlumno_Activa DEFAULT 1,
        CONSTRAINT UQ_SesionAlumno_Usuario UNIQUE (Usuario)
    );
    
    CREATE INDEX IX_SesionAlumno_Activa ON Seguridad.SesionAlumno(Activa, Usuario);
    
    PRINT '✓ Tabla Seguridad.SesionAlumno creada con índices';
END

-- Tabla RegistroBackups
IF OBJECT_ID('Seguridad.RegistroBackups', 'U') IS NOT NULL
BEGIN
    PRINT '• Tabla Seguridad.RegistroBackups ya existe (preservando datos)';
END
ELSE
BEGIN
    CREATE TABLE Seguridad.RegistroBackups (
        BackupID INT IDENTITY(1,1) CONSTRAINT PK_RegistroBackups PRIMARY KEY,
        TipoBackup NVARCHAR(20) NOT NULL,
        RutaArchivo NVARCHAR(500) NOT NULL,
        FechaInicio DATETIME2 NOT NULL,
        FechaFin DATETIME2 NOT NULL,
        TamañoMB DECIMAL(10,2) NULL,
        Estado NVARCHAR(20) NOT NULL,
        ErrorMensaje NVARCHAR(MAX) NULL
    );
    
    CREATE INDEX IX_RegistroBackups_Fecha ON Seguridad.RegistroBackups(FechaInicio DESC);
    
    PRINT '✓ Tabla Seguridad.RegistroBackups creada con índices';
END

PRINT '';

-- ============================================================================
-- FASE 4: ROW-LEVEL SECURITY (RLS)
-- ============================================================================

PRINT '───────────────────────────────────────────────────────────────────────────';
PRINT 'FASE 4: CONFIGURANDO ROW-LEVEL SECURITY';
PRINT '───────────────────────────────────────────────────────────────────────────';

-- Eliminar políticas existentes (para actualización)
IF EXISTS (SELECT * FROM sys.security_policies WHERE name = 'RLS_Alumnos')
BEGIN
    DROP SECURITY POLICY Seguridad.RLS_Alumnos;
    PRINT '• Política RLS_Alumnos eliminada (actualización)';
END

IF EXISTS (SELECT * FROM sys.security_policies WHERE name = 'RLS_Matriculas')
BEGIN
    DROP SECURITY POLICY Seguridad.RLS_Matriculas;
    PRINT '• Política RLS_Matriculas eliminada (actualización)';
END

-- Función de predicado
IF OBJECT_ID('Seguridad.fn_PredicadoAlumno', 'IF') IS NOT NULL
BEGIN
    DROP FUNCTION Seguridad.fn_PredicadoAlumno;
    PRINT '• Función fn_PredicadoAlumno eliminada (actualización)';
END
GO

CREATE FUNCTION Seguridad.fn_PredicadoAlumno(@AlumnoID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN (
    SELECT 1 AS Permitido
    WHERE 
        IS_MEMBER('db_owner') = 1
        OR USER_NAME() = 'dbo'
        OR @AlumnoID IN (
            SELECT s.AlumnoID
            FROM Seguridad.SesionAlumno s
            WHERE s.Usuario = USER_NAME()
              AND s.Activa = 1
              AND (s.FechaExpiracion IS NULL OR s.FechaExpiracion > SYSDATETIME())
        )
);
GO

PRINT '✓ Función de predicado Seguridad.fn_PredicadoAlumno creada';

---------------------------------------
PRINT '';
PRINT '--- PASO 3: Creando función de predicado ---';
PRINT '';
PRINT 'Creando: Seguridad.fn_PredicadoAlumno';
PRINT 'Tipo: Inline Table-Valued Function';
PRINT 'Con: SCHEMABINDING';
PRINT '';
GO

-- IMPORTANTE: CREATE FUNCTION debe ser la primera instrucción del batch
CREATE FUNCTION Seguridad.fn_PredicadoAlumno(@AlumnoID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN (
    SELECT 1 AS Permitido
    WHERE 
        -- Permitir a usuarios con rol db_owner o dbo
        IS_MEMBER('db_owner') = 1
        OR USER_NAME() = 'dbo'
        -- Permitir si el AlumnoID coincide con la sesión activa
        OR @AlumnoID IN (
            SELECT s.AlumnoID
            FROM Seguridad.SesionAlumno s
            WHERE s.Usuario = USER_NAME()
              AND s.Activa = 1
              AND (s.FechaExpiracion IS NULL OR s.FechaExpiracion > SYSDATETIME())
        )
);
GO

-- ============================================================================
-- VERIFICAR QUE SE CREÓ CORRECTAMENTE
-- ============================================================================

PRINT '';
PRINT '--- PASO 4: Verificando función creada ---';

IF OBJECT_ID('Seguridad.fn_PredicadoAlumno', 'IF') IS NOT NULL
BEGIN
    PRINT '✓ Función Seguridad.fn_PredicadoAlumno creada correctamente';
    PRINT '';
    
    -- Mostrar detalles de la función
    SELECT 
        SCHEMA_NAME(schema_id) + '.' + name AS NombreFuncion,
        type_desc AS TipoFuncion,
        create_date AS FechaCreacion,
        modify_date AS FechaModificacion
    FROM sys.objects
    WHERE object_id = OBJECT_ID('Seguridad.fn_PredicadoAlumno');
END
ELSE
BEGIN
    PRINT '✗ ERROR: La función NO se creó';
    PRINT '';
    PRINT 'Posibles causas:';
    PRINT '1. Error de sintaxis en CREATE FUNCTION';
    PRINT '2. Tabla Seguridad.SesionAlumno no existe';
    PRINT '3. Permisos insuficientes';
    PRINT '';
    RAISERROR('La función no se pudo crear', 16, 1);
END
GO

-- ============================================================================
--PROBAR LA FUNCIÓN
-- ============================================================================

PRINT '';
PRINT '--- PASO 5: Probando función ---';

-- Probar con un AlumnoID válido
DECLARE @TestAlumnoID INT = 1;

-- Ver si la función devuelve resultados
IF EXISTS (SELECT * FROM Seguridad.fn_PredicadoAlumno(@TestAlumnoID))
    PRINT '✓ Función ejecuta correctamente (como dbo, devuelve TRUE)';
ELSE
    PRINT '⚠ Función ejecuta pero devuelve FALSE';
GO

-- ============================================================================
--  ELIMINAR POLÍTICAS ANTERIORES
-- ============================================================================

PRINT '';
PRINT '--- PASO 6: Eliminando políticas anteriores ---';

IF EXISTS (SELECT * FROM sys.security_policies WHERE name = 'RLS_Alumnos')
BEGIN
    DROP SECURITY POLICY Seguridad.RLS_Alumnos;
    PRINT '✓ Política RLS_Alumnos eliminada';
END
ELSE
    PRINT '• Política RLS_Alumnos no existe';
GO

IF EXISTS (SELECT * FROM sys.security_policies WHERE name = 'RLS_Matriculas')
BEGIN
    DROP SECURITY POLICY Seguridad.RLS_Matriculas;
    PRINT '✓ Política RLS_Matriculas eliminada';
END
ELSE
    PRINT '• Política RLS_Matriculas no existe';
GO

-- ============================================================================
--CREAR POLÍTICAS RLS
-- ============================================================================

PRINT '';
PRINT '--- PASO 7: Creando políticas RLS ---';

BEGIN TRY
    -- Política para Alumnos
    CREATE SECURITY POLICY Seguridad.RLS_Alumnos
    ADD FILTER PREDICATE Seguridad.fn_PredicadoAlumno(AlumnoID)
        ON Academico.Alumnos
    WITH (STATE = ON);
    
    PRINT '✓ Política RLS_Alumnos creada en Academico.Alumnos';
END TRY
BEGIN CATCH
    PRINT '✗ Error al crear RLS_Alumnos: ' + ERROR_MESSAGE();
END CATCH
GO

BEGIN TRY
    -- Política para Matriculas
    CREATE SECURITY POLICY Seguridad.RLS_Matriculas
    ADD FILTER PREDICATE Seguridad.fn_PredicadoAlumno(AlumnoID)
        ON Academico.Matriculas
    WITH (STATE = ON);
    
    PRINT '✓ Política RLS_Matriculas creada en Academico.Matriculas';
END TRY
BEGIN CATCH
    PRINT '✗ Error al crear RLS_Matriculas: ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================================
-- FASE 5: STORED PROCEDURES
-- ============================================================================

PRINT '───────────────────────────────────────────────────────────────────────────';
PRINT 'FASE 5: CREANDO STORED PROCEDURES';
PRINT '───────────────────────────────────────────────────────────────────────────';

-- SP IniciarSesionAlumno
IF OBJECT_ID('Seguridad.sp_IniciarSesionAlumno', 'P') IS NOT NULL
    DROP PROCEDURE Seguridad.sp_IniciarSesionAlumno;
GO

CREATE PROCEDURE Seguridad.sp_IniciarSesionAlumno
    @Usuario NVARCHAR(128),
    @AlumnoID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    IF NOT EXISTS (SELECT 1 FROM Academico.Alumnos WHERE AlumnoID = @AlumnoID)
    BEGIN
        RAISERROR('AlumnoID %d no existe', 16, 1, @AlumnoID);
        RETURN;
    END
    
    UPDATE Seguridad.SesionAlumno
    SET Activa = 0, FechaExpiracion = SYSDATETIME()
    WHERE Usuario = @Usuario;
    
    INSERT INTO Seguridad.SesionAlumno (Usuario, AlumnoID)
    VALUES (@Usuario, @AlumnoID);
    
    INSERT INTO Seguridad.AuditoriaAccesos (Usuario, Accion, Tabla, AlumnoID)
    VALUES (@Usuario, 'LOGIN', 'SesionAlumno', @AlumnoID);
END
GO

PRINT '✓ SP Seguridad.sp_IniciarSesionAlumno creado';

-- SP CerrarSesionAlumno
IF OBJECT_ID('Seguridad.sp_CerrarSesionAlumno', 'P') IS NOT NULL
    DROP PROCEDURE Seguridad.sp_CerrarSesionAlumno;
GO

CREATE PROCEDURE Seguridad.sp_CerrarSesionAlumno
    @Usuario NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE Seguridad.SesionAlumno
    SET Activa = 0, FechaExpiracion = SYSDATETIME()
    WHERE Usuario = @Usuario AND Activa = 1;
    
    INSERT INTO Seguridad.AuditoriaAccesos (Usuario, Accion, Tabla)
    VALUES (@Usuario, 'LOGOUT', 'SesionAlumno');
END
GO

PRINT '✓ SP Seguridad.sp_CerrarSesionAlumno creado';

-- SP BackupFull
IF OBJECT_ID('Seguridad.sp_BackupFull', 'P') IS NOT NULL
    DROP PROCEDURE Seguridad.sp_BackupFull;
GO

CREATE PROCEDURE Seguridad.sp_BackupFull
    @RutaBackup NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF SERVERPROPERTY('EngineEdition') = 5
    BEGIN
        PRINT '⚠ Azure SQL Database no soporta BACKUP TO DISK';
        RETURN;
    END
    
    DECLARE @NombreDB NVARCHAR(128) = DB_NAME();
    DECLARE @FechaInicio DATETIME2 = SYSDATETIME();
    DECLARE @RutaCompleta NVARCHAR(500);
    
    IF @RutaBackup IS NULL
        SET @RutaBackup = 'C:\Backups\Academia2022\';
    
    SET @RutaCompleta = @RutaBackup + @NombreDB + '_FULL_' 
        + CONVERT(VARCHAR, GETDATE(), 112) + '_' 
        + REPLACE(CONVERT(VARCHAR, GETDATE(), 108), ':', '') + '.bak';
    
    BEGIN TRY
        BACKUP DATABASE @NombreDB TO DISK = @RutaCompleta
        WITH COMPRESSION, STATS = 10, CHECKSUM;
        
        INSERT INTO Seguridad.RegistroBackups 
            (TipoBackup, RutaArchivo, FechaInicio, FechaFin, Estado)
        VALUES ('FULL', @RutaCompleta, @FechaInicio, SYSDATETIME(), 'SUCCESS');
    END TRY
    BEGIN CATCH
        INSERT INTO Seguridad.RegistroBackups 
            (TipoBackup, RutaArchivo, FechaInicio, FechaFin, Estado, ErrorMensaje)
        VALUES ('FULL', @RutaCompleta, @FechaInicio, SYSDATETIME(), 'FAILED', ERROR_MESSAGE());
        THROW;
    END CATCH
END
GO

PRINT '✓ SP Seguridad.sp_BackupFull creado';

-- SP BackupDiferencial
IF OBJECT_ID('Seguridad.sp_BackupDiferencial', 'P') IS NOT NULL
    DROP PROCEDURE Seguridad.sp_BackupDiferencial;
GO

CREATE PROCEDURE Seguridad.sp_BackupDiferencial
    @RutaBackup NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF SERVERPROPERTY('EngineEdition') = 5
    BEGIN
        PRINT '⚠ Azure SQL Database no soporta BACKUP TO DISK';
        RETURN;
    END
    
    DECLARE @NombreDB NVARCHAR(128) = DB_NAME();
    DECLARE @FechaInicio DATETIME2 = SYSDATETIME();
    DECLARE @RutaCompleta NVARCHAR(500);
    
    IF @RutaBackup IS NULL
        SET @RutaBackup = 'C:\Backups\Academia2022\';
    
    SET @RutaCompleta = @RutaBackup + @NombreDB + '_DIFF_' 
        + CONVERT(VARCHAR, GETDATE(), 112) + '_' 
        + REPLACE(CONVERT(VARCHAR, GETDATE(), 108), ':', '') + '.bak';
    
    BEGIN TRY
        BACKUP DATABASE @NombreDB TO DISK = @RutaCompleta
        WITH DIFFERENTIAL, COMPRESSION, STATS = 10, CHECKSUM;
        
        INSERT INTO Seguridad.RegistroBackups 
            (TipoBackup, RutaArchivo, FechaInicio, FechaFin, Estado)
        VALUES ('DIFF', @RutaCompleta, @FechaInicio, SYSDATETIME(), 'SUCCESS');
    END TRY
    BEGIN CATCH
        INSERT INTO Seguridad.RegistroBackups 
            (TipoBackup, RutaArchivo, FechaInicio, FechaFin, Estado, ErrorMensaje)
        VALUES ('DIFF', @RutaCompleta, @FechaInicio, SYSDATETIME(), 'FAILED', ERROR_MESSAGE());
        THROW;
    END CATCH
END
GO

PRINT '✓ SP Seguridad.sp_BackupDiferencial creado';

-- SP LimpiarSesionesExpiradas
IF OBJECT_ID('Seguridad.sp_LimpiarSesionesExpiradas', 'P') IS NOT NULL
    DROP PROCEDURE Seguridad.sp_LimpiarSesionesExpiradas;
GO

CREATE PROCEDURE Seguridad.sp_LimpiarSesionesExpiradas
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM Seguridad.SesionAlumno
    WHERE Activa = 0 AND FechaExpiracion < DATEADD(DAY, -30, SYSDATETIME());
END
GO

PRINT '✓ SP Seguridad.sp_LimpiarSesionesExpiradas creado';
PRINT '';

-- ============================================================================
-- FASE 6: VISTAS DE MONITOREO
-- ============================================================================

PRINT '───────────────────────────────────────────────────────────────────────────';
PRINT 'FASE 6: CREANDO VISTAS DE MONITOREO';
PRINT '───────────────────────────────────────────────────────────────────────────';

-- Vista AuditoriaPermisos
IF OBJECT_ID('Seguridad.vw_AuditoriaPermisos', 'V') IS NOT NULL
    DROP VIEW Seguridad.vw_AuditoriaPermisos;
GO

CREATE VIEW Seguridad.vw_AuditoriaPermisos
AS
SELECT 
    dp.name AS Usuario,
    dp.type_desc AS TipoUsuario,
    r.name AS Rol,
    o.name AS Objeto,
    p.permission_name AS Permiso,
    p.state_desc AS Estado
FROM sys.database_principals dp
LEFT JOIN sys.database_role_members rm ON dp.principal_id = rm.member_principal_id
LEFT JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
LEFT JOIN sys.database_permissions p ON dp.principal_id = p.grantee_principal_id
LEFT JOIN sys.objects o ON p.major_id = o.object_id
WHERE dp.type IN ('S', 'U', 'R')
  AND dp.name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys');
GO

PRINT '✓ Vista Seguridad.vw_AuditoriaPermisos creada';

-- Vista SesionesActivas
IF OBJECT_ID('Seguridad.vw_SesionesActivas', 'V') IS NOT NULL
    DROP VIEW Seguridad.vw_SesionesActivas;
GO

CREATE VIEW Seguridad.vw_SesionesActivas
AS
SELECT 
    s.Usuario,
    s.AlumnoID,
    a.AlumnoNombre + ' ' + a.AlumnoApellido AS NombreCompleto,
    s.FechaInicio,
    DATEDIFF(MINUTE, s.FechaInicio, SYSDATETIME()) AS MinutosActiva,
    s.FechaExpiracion
FROM Seguridad.SesionAlumno s
INNER JOIN Academico.Alumnos a ON s.AlumnoID = a.AlumnoID
WHERE s.Activa = 1;
GO

PRINT '✓ Vista Seguridad.vw_SesionesActivas creada';

-- Vista UltimosAccesos
IF OBJECT_ID('Seguridad.vw_UltimosAccesos', 'V') IS NOT NULL
    DROP VIEW Seguridad.vw_UltimosAccesos;
GO

CREATE VIEW Seguridad.vw_UltimosAccesos
AS
SELECT TOP 1000
    Usuario, Accion, Tabla, AlumnoID, FechaHora, IP, Aplicacion
FROM Seguridad.AuditoriaAccesos
ORDER BY FechaHora DESC;
GO

PRINT '✓ Vista Seguridad.vw_UltimosAccesos creada';
PRINT '';

-- ============================================================================
-- FASE 7: ASIGNACIÓN DE PERMISOS
-- ============================================================================

PRINT '───────────────────────────────────────────────────────────────────────────';
PRINT 'FASE 7: ASIGNANDO PERMISOS A ROLES';
PRINT '───────────────────────────────────────────────────────────────────────────';

-- Permisos AppReader
GRANT SELECT ON SCHEMA::Academico TO AppReader;
GRANT SELECT ON SCHEMA::App TO AppReader;
PRINT '✓ Permisos de lectura asignados a AppReader';

-- Permisos AppWriter
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Academico TO AppWriter;
GRANT SELECT ON SCHEMA::App TO AppWriter;
GRANT EXECUTE ON SCHEMA::Academico TO AppWriter;
PRINT '✓ Permisos DML asignados a AppWriter';

-- Permisos AuditorDB
GRANT SELECT ON SCHEMA::Seguridad TO AuditorDB;
GRANT VIEW DATABASE STATE TO AuditorDB;
GRANT SELECT ON Seguridad.vw_AuditoriaPermisos TO AuditorDB;
GRANT SELECT ON Seguridad.vw_SesionesActivas TO AuditorDB;
GRANT SELECT ON Seguridad.vw_UltimosAccesos TO AuditorDB;
PRINT '✓ Permisos de auditoría asignados a AuditorDB';
PRINT '';

PRINT '╔════════════════════════════════════════════════════════════════════════════╗';
PRINT '║                       VALIDACIÓN FINAL - EQUIPO D                         ║';
PRINT '╚════════════════════════════════════════════════════════════════════════════╝';
PRINT '';
GO

DECLARE @ErrorCount INT = 0;

PRINT '───────────────────────────────────────────────────────────────────────────';
PRINT 'VERIFICANDO COMPONENTES';
PRINT '───────────────────────────────────────────────────────────────────────────';
PRINT '';

-- ============================================================================
-- 1. VERIFICAR ROLES
-- ============================================================================
PRINT '1. Roles de Seguridad:';

DECLARE @RolesCount INT;
SELECT @RolesCount = COUNT(*) 
FROM sys.database_principals 
WHERE type = 'R' 
  AND name IN ('AppReader', 'AppWriter', 'AuditorDB');

IF @RolesCount <> 3
BEGIN
    PRINT '   ✗ Fallo: ' + CAST(@RolesCount AS VARCHAR) + ' de 3 roles creados';
    SET @ErrorCount = @ErrorCount + 1;
    
    -- Mostrar qué falta
    IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'AppReader' AND type = 'R')
        PRINT '      Falta: AppReader';
    IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'AppWriter' AND type = 'R')
        PRINT '      Falta: AppWriter';
    IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'AuditorDB' AND type = 'R')
        PRINT '      Falta: AuditorDB';
END
ELSE
    PRINT '   ✓ Roles: 3/3 creados correctamente';

-- ============================================================================
-- 2. VERIFICAR TABLAS DE SEGURIDAD
-- ============================================================================
PRINT '';
PRINT '2. Tablas de Seguridad:';

DECLARE @TablasCount INT;
SELECT @TablasCount = COUNT(*) 
FROM sys.tables 
WHERE SCHEMA_NAME(schema_id) = 'Seguridad' 
  AND name IN ('AuditoriaAccesos', 'SesionAlumno', 'RegistroBackups');

IF @TablasCount <> 3
BEGIN
    PRINT '   ✗ Fallo: ' + CAST(@TablasCount AS VARCHAR) + ' de 3 tablas creadas';
    SET @ErrorCount = @ErrorCount + 1;
    
    -- Mostrar qué falta
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AuditoriaAccesos' AND SCHEMA_NAME(schema_id) = 'Seguridad')
        PRINT '      Falta: Seguridad.AuditoriaAccesos';
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SesionAlumno' AND SCHEMA_NAME(schema_id) = 'Seguridad')
        PRINT '      Falta: Seguridad.SesionAlumno';
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'RegistroBackups' AND SCHEMA_NAME(schema_id) = 'Seguridad')
        PRINT '      Falta: Seguridad.RegistroBackups';
END
ELSE
    PRINT '   ✓ Tablas: 3/3 creadas correctamente';

-- ============================================================================
-- 3. VERIFICAR FUNCIÓN DE PREDICADO RLS
-- ============================================================================
PRINT '';
PRINT '3. Función de Predicado RLS:';

IF OBJECT_ID('Seguridad.fn_PredicadoAlumno', 'IF') IS NULL
BEGIN
    PRINT '   ✗ Fallo: Función fn_PredicadoAlumno no existe';
    SET @ErrorCount = @ErrorCount + 1;
END
ELSE
    PRINT '   ✓ Función: Seguridad.fn_PredicadoAlumno (inline table-valued)';

-- ============================================================================
-- 4. VERIFICAR POLÍTICAS RLS
-- ============================================================================
PRINT '';
PRINT '4. Políticas RLS:';

DECLARE @PoliticasCount INT;
SELECT @PoliticasCount = COUNT(*) 
FROM sys.security_policies 
WHERE is_enabled = 1
  AND name IN ('RLS_Alumnos', 'RLS_Matriculas');

IF @PoliticasCount < 2
BEGIN
    PRINT '   ✗ Fallo: ' + CAST(@PoliticasCount AS VARCHAR) + ' de 2 políticas activas';
    SET @ErrorCount = @ErrorCount + 1;
    
    -- Mostrar qué falta
    IF NOT EXISTS (SELECT * FROM sys.security_policies WHERE name = 'RLS_Alumnos')
        PRINT '      Falta: RLS_Alumnos';
    ELSE IF EXISTS (SELECT * FROM sys.security_policies WHERE name = 'RLS_Alumnos' AND is_enabled = 0)
        PRINT '      RLS_Alumnos existe pero está DESHABILITADA';
        
    IF NOT EXISTS (SELECT * FROM sys.security_policies WHERE name = 'RLS_Matriculas')
        PRINT '      Falta: RLS_Matriculas';
    ELSE IF EXISTS (SELECT * FROM sys.security_policies WHERE name = 'RLS_Matriculas' AND is_enabled = 0)
        PRINT '      RLS_Matriculas existe pero está DESHABILITADA';
END
ELSE
    PRINT '   ✓ Políticas RLS: ' + CAST(@PoliticasCount AS VARCHAR) + ' activas';

-- ============================================================================
-- 5. VERIFICAR STORED PROCEDURES
-- ============================================================================
PRINT '';
PRINT '5. Stored Procedures:';

DECLARE @SPsCount INT;
SELECT @SPsCount = COUNT(*) 
FROM sys.procedures 
WHERE SCHEMA_NAME(schema_id) = 'Seguridad';

IF @SPsCount < 5
BEGIN
    PRINT '   ✗ Fallo: ' + CAST(@SPsCount AS VARCHAR) + ' stored procedures (esperados: 5+)';
    SET @ErrorCount = @ErrorCount + 1;
END
ELSE
    PRINT '   ✓ SPs: ' + CAST(@SPsCount AS VARCHAR) + ' creados correctamente';

-- Listar SPs creados
PRINT '   SPs encontrados:';
SELECT '      - ' + name AS SP
FROM sys.procedures
WHERE SCHEMA_NAME(schema_id) = 'Seguridad'
ORDER BY name;

-- ============================================================================
-- 6. VERIFICAR VISTAS
-- ============================================================================
PRINT '';
PRINT '6. Vistas de Monitoreo:';

DECLARE @VistasCount INT;
SELECT @VistasCount = COUNT(*) 
FROM sys.views 
WHERE SCHEMA_NAME(schema_id) = 'Seguridad';

IF @VistasCount <> 3
BEGIN
    PRINT '   ✗ Fallo: ' + CAST(@VistasCount AS VARCHAR) + ' de 3 vistas creadas';
    SET @ErrorCount = @ErrorCount + 1;
    
    -- Mostrar qué falta
    IF NOT EXISTS (SELECT * FROM sys.views WHERE name = 'vw_AuditoriaPermisos' AND SCHEMA_NAME(schema_id) = 'Seguridad')
        PRINT '      Falta: vw_AuditoriaPermisos';
    IF NOT EXISTS (SELECT * FROM sys.views WHERE name = 'vw_SesionesActivas' AND SCHEMA_NAME(schema_id) = 'Seguridad')
        PRINT '      Falta: vw_SesionesActivas';
    IF NOT EXISTS (SELECT * FROM sys.views WHERE name = 'vw_UltimosAccesos' AND SCHEMA_NAME(schema_id) = 'Seguridad')
        PRINT '      Falta: vw_UltimosAccesos';
END
ELSE
    PRINT '   ✓ Vistas: 3/3 creadas correctamente';

-- ============================================================================
-- 7. VERIFICAR PERMISOS
-- ============================================================================
PRINT '';
PRINT '7. Permisos Asignados:';

DECLARE @PermisosCount INT;
SELECT @PermisosCount = COUNT(DISTINCT grantee_principal_id)
FROM sys.database_permissions p
INNER JOIN sys.database_principals dp ON p.grantee_principal_id = dp.principal_id
WHERE dp.name IN ('AppReader', 'AppWriter', 'AuditorDB');

IF @PermisosCount < 3
BEGIN
    PRINT '   ⚠ Advertencia: Solo ' + CAST(@PermisosCount AS VARCHAR) + ' roles tienen permisos asignados';
END
ELSE
    PRINT '   ✓ Permisos: Asignados a ' + CAST(@PermisosCount AS VARCHAR) + ' roles';

-- ============================================================================
-- RESULTADO FINAL
-- ============================================================================
PRINT '';
PRINT '───────────────────────────────────────────────────────────────────────────';

IF @ErrorCount = 0
BEGIN
    PRINT '╔════════════════════════════════════════════════════════════════════════════╗';
    PRINT '║                    ✓ VALIDACIÓN EXITOSA - TODO CORRECTO                   ║';
    PRINT '╚════════════════════════════════════════════════════════════════════════════╝';
    PRINT '';
    PRINT 'RESUMEN:';
    PRINT '  ✓ 3 Roles de seguridad';
    PRINT '  ✓ 3 Tablas de auditoría';
    PRINT '  ✓ 1 Función de predicado RLS';
    
    -- Calcular políticas activas
    DECLARE @TotalPoliticas INT;
    SELECT @TotalPoliticas = COUNT(*) FROM sys.security_policies WHERE is_enabled = 1;
    PRINT '  ✓ ' + CAST(@TotalPoliticas AS VARCHAR) + ' Políticas RLS activas';
    
    -- Calcular SPs totales
    DECLARE @TotalSPs INT;
    SELECT @TotalSPs = COUNT(*) FROM sys.procedures WHERE SCHEMA_NAME(schema_id) = 'Seguridad';
    PRINT '  ✓ ' + CAST(@TotalSPs AS VARCHAR) + ' Stored procedures';
    
    PRINT '  ✓ 3 Vistas de monitoreo';
    PRINT '';
    PRINT 'ESTADO: LISTO PARA PRUEBAS';
    PRINT '';
    PRINT 'PRÓXIMOS PASOS:';
    PRINT '  1. Ejecutar: EquipoD_Pruebas_Validacion.sql';
    PRINT '  2. Capturar pantallas para el reporte';
    PRINT '  3. Documentar evidencias';
END
ELSE
BEGIN
    PRINT '╔════════════════════════════════════════════════════════════════════════════╗';
    PRINT '║                    ✗ VALIDACIÓN CON ERRORES                               ║';
    PRINT '╚════════════════════════════════════════════════════════════════════════════╝';
    PRINT '';
    PRINT 'Errores encontrados: ' + CAST(@ErrorCount AS VARCHAR);
    PRINT '';
    PRINT 'ACCIÓN REQUERIDA:';
    PRINT '  - Revisar los mensajes anteriores';
    PRINT '  - Ejecutar de nuevo: EquipoD_Deploy_Maestro.sql';
    PRINT '  - O ejecutar: EquipoD_Correccion_Final.sql';
END

PRINT '';
PRINT '═══════════════════════════════════════════════════════════════════════════';
PRINT 'Fecha: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '═══════════════════════════════════════════════════════════════════════════';
GO
