USE Atlantis
GO
/*
SELECT dbo.fn_LevenshteinDistance('Klueppel', 'Knopfel')
SELECT dbo.fn_LevenshteinDistance('Klueppel', 'Klappel')
SELECT dbo.fn_LevenshteinDistance('Klueppel', 'Culpepper')
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF EXISTS (SELECT * FROM sysobjects WHERE id = object_id(N'[dbo].[fn_LevenshteinDistance]'))
DROP FUNCTION [dbo].[fn_LevenshteinDistance]
GO

CREATE FUNCTION [dbo].[fn_LevenshteinDistance]
(
	@Left NVARCHAR(MAX),
	@Right NVARCHAR(MAX)
)
RETURNS INT
AS
BEGIN
	DECLARE @LeftLength INT,
			@RightLength INT, 
			@i INT, 
			@j INT, 
			@LeftChar NCHAR, 
			@c INT, 
			@c_temp INT, 
			@cv0 VARBINARY(MAX), 
			@cv1 VARBINARY(MAX)

	SELECT @LeftLength = LEN(@Left), @RightLength = LEN(@Right), @cv1 = 0x0000, @j = 1, @i = 1, @c = 0

	WHILE @j <= @RightLength
		SELECT @cv1 = @cv1 + CAST(@j AS BINARY(2)), @j = @j + 1

	WHILE @i <= @LeftLength
	BEGIN
		SELECT @LeftChar = SUBSTRING(@Left, @i, 1), @c = @i, @cv0 = CAST(@i AS BINARY(2)), @j = 1
		WHILE @j <= @RightLength
		BEGIN
			SET @c = @c + 1
			SET @c_temp = CAST(SUBSTRING(@cv1, @j+@j-1, 2) AS INT) + CASE WHEN @LeftChar = SUBSTRING(@Right, @j, 1) THEN 0 ELSE 1 END

			IF @c > @c_temp SET @c = @c_temp
				SET @c_temp = CAST(SUBSTRING(@cv1, @j+@j+1, 2) AS INT)+1
			IF @c > @c_temp SET @c = @c_temp
				SELECT @cv0 = @cv0 + CAST(@c AS BINARY(2)), @j = @j + 1
		END
		SELECT @cv1 = @cv0, @i = @i + 1
	END

	RETURN @c
END
