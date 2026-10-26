/* Ejecutar una sola vez sobre NewTalentLoans antes de activar SQL Server. */
IF COL_LENGTH('dbo.Usuario', 'Usuario_Sueldo') IS NULL
    ALTER TABLE dbo.Usuario ADD Usuario_Sueldo DECIMAL(18,2) NOT NULL CONSTRAINT DF_Usuario_Sueldo DEFAULT (0);
GO
IF COL_LENGTH('dbo.Solicitud', 'Solicitud_TipoPrestamoId') IS NULL
    ALTER TABLE dbo.Solicitud ADD Solicitud_TipoPrestamoId INT NULL;
GO
IF COL_LENGTH('dbo.Solicitud', 'Solicitud_MetodoPagoId') IS NULL
    ALTER TABLE dbo.Solicitud ADD Solicitud_MetodoPagoId INT NULL;
GO
IF COL_LENGTH('dbo.Solicitud', 'Solicitud_GaranteNombre') IS NULL
    ALTER TABLE dbo.Solicitud ADD Solicitud_GaranteNombre NVARCHAR(150) NULL;
GO
IF COL_LENGTH('dbo.Solicitud', 'Solicitud_GaranteCedula') IS NULL
    ALTER TABLE dbo.Solicitud ADD Solicitud_GaranteCedula NVARCHAR(30) NULL;
GO
IF COL_LENGTH('dbo.Solicitud', 'Solicitud_GaranteTelefono') IS NULL
    ALTER TABLE dbo.Solicitud ADD Solicitud_GaranteTelefono NVARCHAR(30) NULL;
GO
