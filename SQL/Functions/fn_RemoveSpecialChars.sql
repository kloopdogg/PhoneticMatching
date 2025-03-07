
/*
SELECT dbo.fn_RemoveSpecialCharacters('o''malley', null, null) -- apostrophes
SELECT dbo.fn_RemoveSpecialCharacters('pate-terry', null, null) -- hyphens
SELECT dbo.fn_RemoveSpecialCharacters(''' or 1=1; --', null, null) -- SQL injection attack
SELECT dbo.fn_RemoveSpecialCharacters('o''malley | test | hello, world!', '|^ ^,', '^') -- with additional allowed chars
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF EXISTS (SELECT * FROM sysobjects WHERE id = object_id(N'[dbo].[fn_RemoveSpecialCharacters]'))
DROP FUNCTION [dbo].[fn_RemoveSpecialCharacters]
GO

CREATE FUNCTION [dbo].[fn_RemoveSpecialCharacters]
(
	@InputString VARCHAR(MAX),
	@AllowedChars VARCHAR(100) = NULL,
	@AllowedCharsDelimiter VARCHAR(2) = '|'
)
RETURNS VARCHAR(MAX)
AS
BEGIN
	DECLARE @Index INT
	DECLARE @Current VARCHAR(200)
	DECLARE @Length INT
	
	SET @Index = 1
	SET @Current = ''
	SET @Length = LEN(@InputString)
	
	BEGIN
		WHILE @Index <= LEN(@InputString)
		BEGIN
			SET @Current = @Current + SUBSTRING(@InputString,@Index, 1)

			IF @Current LIKE '[a-z]' OR @Current LIKE '[0-9]' OR (@AllowedChars IS NOT NULL AND @Current IN (SELECT [Value] FROM dbo.fn_MakeTable(@AllowedChars, @AllowedCharsDelimiter)))
			BEGIN
				SET @Index = @Index + 1
			END
			ELSE
			BEGIN
				SET @InputString = REPLACE(@InputString, @Current, '')
			END
			SET @Current = ''	
		END
		RETURN @InputString
	END
END