
/*
usp_PartyPhoneticName_Refresh 5150
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_PartyPhoneticName_Refresh]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_PartyPhoneticName_Refresh]
GO

CREATE PROCEDURE [dbo].[usp_PartyPhoneticName_Refresh]
(
	@UserID INT
)
AS
BEGIN
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	SET NOCOUNT ON

	DECLARE @Errors INT
	SET @Errors = 0

	CREATE TABLE #Parties (PartyID INT, PhoneticFirstName VARCHAR(200), PhoneticLastName VARCHAR(200))
	INSERT #Parties (PartyID, PhoneticFirstName, PhoneticLastName)
	SELECT p.PartyID, dbo.fn_PhoneticallyEncodeName(p.FirstName), dbo.fn_PhoneticallyEncodeName(p.LastName)
	FROM (
		SELECT DISTINCT PartyID = r.PartyFromID
		FROM HealthcareEligibilityGroupMember m
		JOIN PartyRelationship r ON r.PartyRelationshipID = m.PartyRelationshipID
	) AS pr
	JOIN Party p ON p.PartyID = pr.PartyID
	IF @@ERROR <> 0 SET @Errors = @Errors + 1

	CREATE TABLE #PartyPhoneticName (RowID INT IDENTITY(1,1), PartyID INT, PhoneticName VARCHAR(200), NameFieldID INT, Weight DECIMAL(18,3))

	-- Insert full first names
	INSERT #PartyPhoneticName (PartyID, PhoneticName, NameFieldID, Weight)
	SELECT PartyID, PhoneticFirstName, 1, 1
	FROM #Parties
	IF @@ERROR <> 0 SET @Errors = @Errors + 1

	-- Insert full last names
	INSERT #PartyPhoneticName (PartyID, PhoneticName, NameFieldID, Weight)
	SELECT PartyID, PhoneticLastName, 2, 1
	FROM #Parties
	IF @@ERROR <> 0 SET @Errors = @Errors + 1

	-- Insert LEFT(6) first names
	INSERT #PartyPhoneticName (PartyID, PhoneticName, NameFieldID, Weight)
	SELECT PartyID, LEFT(PhoneticFirstName, 6), 1, 0.9
	FROM #Parties
	IF @@ERROR <> 0 SET @Errors = @Errors + 1

	-- Insert LEFT(6) last names
	INSERT #PartyPhoneticName (PartyID, PhoneticName, NameFieldID, Weight)
	SELECT PartyID, LEFT(PhoneticLastName, 6), 2, 0.9
	FROM #Parties
	IF @@ERROR <> 0 SET @Errors = @Errors + 1

	-- Insert LEFT(4) first names
	INSERT #PartyPhoneticName (PartyID, PhoneticName, NameFieldID, Weight)
	SELECT PartyID, LEFT(PhoneticFirstName, 4), 1, 0.5
	FROM #Parties
	IF @@ERROR <> 0 SET @Errors = @Errors + 1

	-- Insert LEFT(4) last names
	INSERT #PartyPhoneticName (PartyID, PhoneticName, NameFieldID, Weight)
	SELECT PartyID, LEFT(PhoneticLastName, 4), 2, 0.5
	FROM #Parties
	IF @@ERROR <> 0 SET @Errors = @Errors + 1

	-- Insert RIGHT(4) first names
	INSERT #PartyPhoneticName (PartyID, PhoneticName, NameFieldID, Weight)
	SELECT PartyID, RIGHT(PhoneticFirstName, 4), 1, 0.5
	FROM #Parties
	IF @@ERROR <> 0 SET @Errors = @Errors + 1

	-- Insert RIGHT(4) last names
	INSERT #PartyPhoneticName (PartyID, PhoneticName, NameFieldID, Weight)
	SELECT PartyID, RIGHT(PhoneticLastName, 4), 2, 0.5
	FROM #Parties
	IF @@ERROR <> 0 SET @Errors = @Errors + 1

	IF @Errors = 0
	BEGIN
		BEGIN TRANSACTION

		UPDATE ppn
		SET ppn.PhoneticName = temp.PhoneticName
		FROM PartyPhoneticName ppn
		JOIN #PartyPhoneticName temp ON temp.PartyID = ppn.PartyID
			AND temp.NameFieldID = ppn.NameFieldID
			AND temp.Weight = ppn.Weight
			AND temp.PhoneticName <> ppn.PhoneticName
		LEFT JOIN (
			SELECT RowID
			FROM PartyPhoneticName ppn
			JOIN #PartyPhoneticName temp ON temp.PartyID = ppn.PartyID
				AND temp.NameFieldID = ppn.NameFieldID
				AND temp.Weight = ppn.Weight
				AND temp.PhoneticName = ppn.PhoneticName
		) matches ON matches.RowID = temp.RowID
		WHERE matches.RowID IS NULL
		IF @@ERROR <> 0 SET @Errors = @Errors + 1

		INSERT PartyPhoneticName (PartyID, PhoneticName, NameFieldID, Weight, CreatedBy, ModifiedBy)
		SELECT temp.PartyID, temp.PhoneticName, temp.NameFieldID, temp.Weight, @UserID, @UserID
		FROM #PartyPhoneticName temp
		LEFT JOIN PartyPhoneticName ppn ON ppn.PartyID = temp.PartyID
			AND ppn.NameFieldID = temp.NameFieldID
			AND ppn.Weight = temp.Weight
		WHERE ppn.PartyID IS NULL
		IF @@ERROR <> 0 SET @Errors = @Errors + 1

		DELETE pn
		FROM PartyPhoneticName pn
		JOIN #PartyPhoneticName tpn ON tpn.PartyID = pn.PartyID
		AND pn.PartyPhoneticNameID NOT IN (
			SELECT DISTINCT ppn.PartyPhoneticNameID
			FROM PartyPhoneticName ppn
			JOIN #PartyPhoneticName temp ON temp.PartyID = ppn.PartyID
				AND temp.NameFieldID = ppn.NameFieldID
				AND temp.Weight = ppn.Weight
				AND temp.PhoneticName = ppn.PhoneticName
		)
		IF @@ERROR <> 0 SET @Errors = @Errors + 1
	END

	IF @Errors <> 0
	BEGIN
		ROLLBACK TRANSACTION			
		RAISERROR(N'PartyPhoneticName could not be refreshed.', 11, 1, NULL)
	END
	ELSE
	BEGIN
		COMMIT TRANSACTION
	END
END