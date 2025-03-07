
/*
SELECT * FROM dbo.fn_MakeTable('8675309', ',')
SELECT * FROM dbo.fn_MakeTable('james,1234,5150', ',')
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF EXISTS (SELECT * FROM sysobjects WHERE id = object_id(N'[dbo].[fn_MakeTable]'))
DROP FUNCTION [dbo].[fn_MakeTable]
GO

CREATE FUNCTION [dbo].[fn_MakeTable]
(
	@Values VARCHAR(MAX),
	@Delimiter VARCHAR(50)
)
RETURNS @Vals TABLE ([Value] VARCHAR(MAX))
AS
BEGIN
	DECLARE @idx INT
	DECLARE @val VARCHAR(200)
	DECLARE @len INT

	SET @len = LEN(@Values)
	SET @idx = 1
	SET @val = ''

	WHILE @idx <= @len
	BEGIN
		IF (SUBSTRING(@Values, @idx, 1) <> @Delimiter)
		BEGIN
			SET @val = @val + SUBSTRING(@Values, @idx, 1)
		END

		IF ((SUBSTRING(@Values,@idx,1) = @Delimiter OR @idx = @len)) OR @Delimiter = ''
		BEGIN
			INSERT @Vals ([Value]) VALUES (@val)
			SET @Val = ''
		END

		SET @idx = @idx + 1
	END
	RETURN
END
GO