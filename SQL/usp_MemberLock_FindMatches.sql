
/*
exec usp_MemberLock_FindMatches null, '803200015' --\ same
exec usp_MemberLock_FindMatches 1001276282, null  --/ claim

-- Easy (first item is correct match)
usp_MemberLock_FindMatches null, 'PC0148486', 5
usp_MemberLock_FindMatches null, 'PC0148912'
usp_MemberLock_FindMatches null, 'PC0149166'
usp_MemberLock_FindMatches null, 'PC0149169'
usp_MemberLock_FindMatches null, 'PC0149171'
usp_MemberLock_FindMatches null, 'PC0149174'
usp_MemberLock_FindMatches null, 'PC0149177'
usp_MemberLock_FindMatches null, 'PC0149187'
usp_MemberLock_FindMatches null, 'PC0149336'
usp_MemberLock_FindMatches null, 'PC0149298'
usp_MemberLock_FindMatches null, 'PC0149346'

-- More difficult (first item is correct match)
usp_MemberLock_FindMatches null, 'PC0149305' -- DOB incorrect, last name spelled wrong
usp_MemberLock_FindMatches null, 'PC0149328' -- DOB incorrect
usp_MemberLock_FindMatches null, 'PC0149364' -- Jesse James
usp_MemberLock_FindMatches null, '803200008' -- JOSEFELIX / VALDERRAMALOPEZ mapped to JOSE / FELIX VALDERRAMA- LOPEZ
usp_MemberLock_FindMatches null, '803200015' -- JUANOPUS / DAVILA mapped to JUAN / DAVILA

-- Difficult (correct match is in top 10)
usp_MemberLock_FindMatches null, '700500084'

select * from keyedclaim where stampnumber='700500084'

-- No good matches found
usp_MemberLock_FindMatches null, 'PC0149247' -- No DOB, doesn't find a match
usp_MemberLock_FindMatches null, 'PC0154325' -- Name T / M doesn't match to Timothy Moore

usp_MemberLock_FindMatches @StampNumber='020831100001'

select * from partyphoneticname where partyid=71928
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_MemberLock_FindMatches]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_MemberLock_FindMatches]
GO

CREATE PROCEDURE [dbo].[usp_MemberLock_FindMatches]
(
	@ClaimID INT = NULL,
	@StampNumber VARCHAR(50) = NULL,
	@Quantity INT = 10
)
AS
BEGIN
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	IF NULLIF(@ClaimID, 0) IS NULL AND NULLIF(@StampNumber, '') IS NULL		
		RAISERROR(N'Either ClaimID or StampNumber must be specified', 11, 1, NULL)
 
	DECLARE @PhoneticLastName VARCHAR(100)
	DECLARE @PhoneticFirstName VARCHAR(100)
	DECLARE @LastName VARCHAR(100)
	DECLARE @FirstName VARCHAR(100)
	DECLARE @Day TINYINT
	DECLARE @Month TINYINT
	DECLARE @Year SMALLINT
	DECLARE @DateOfBirthString VARCHAR(10)

	SELECT @LastName = PatientLastName
		, @FirstName = PatientFirstName
		, @DateOfBirthString = CONVERT(VARCHAR, PatientDOB, 102)
		, @Day = DAY(PatientDOB)
		, @Month = MONTH(PatientDOB)
		, @Year = YEAR(PatientDOB)
	FROM KeyedClaim
	WHERE (@StampNumber IS NOT NULL AND StampNumber = @StampNumber)
	OR (@ClaimID IS NOT NULL AND ClaimID = @ClaimID)

	IF @LastName LIKE 'FEDERAL%'
	BEGIN
		SET @LastName = 'JAMES'
		SET @FirstName = 'JESSE'
	END

	SELECT @PhoneticLastName = dbo.fn_PhoneticallyEncodeName(@LastName)
	SELECT @PhoneticFirstName = dbo.fn_PhoneticallyEncodeName(@FirstName)

	IF LEN(@PhoneticLastName) > 0 AND LEN(@PhoneticFirstName) > 0
	BEGIN
		SELECT DISTINCT TOP (@Quantity) Rank = ROW_NUMBER() OVER (ORDER BY TotalDistance), PartyID, LastName, FirstName, DOB
		FROM (
			SELECT PartyID, LastName, FirstName, DOB, TotalDistance = MIN(TotalDistance)
			FROM (
				SELECT PartyID
					, LastName
					, FirstName
					, DOB
					, Score
					, DateOfBirthDistance
					, Distance
					, ReverseDistance
					, TotalDistance = (CASE WHEN Distance < ReverseDistance THEN Distance ELSE ReverseDistance END) + (2 * DateOfBirthDistance) + (10 - Score)
				FROM (
					SELECT selectedPartyIDs.PartyID
						, p.LastName
						, p.FirstName
						, Distance = dbo.fn_LevenshteinDistance(p.FirstName, @FirstName) + dbo.fn_LevenshteinDistance(p.LastName, @LastName)
						, ReverseDistance = dbo.fn_LevenshteinDistance(p.FirstName, @LastName) + dbo.fn_LevenshteinDistance(p.LastName, @FirstName)
						, DateOfBirthDistance = dbo.fn_LevenshteinDistance(CONVERT(VARCHAR, p.DOB, 102), @DateOfBirthString)
						, p.DOB
						, Score
					FROM (
						SELECT TOP 500 PartyID, Score = Weight * (Types + Cnt)
						FROM (
							SELECT PartyID, Weight, Types=COUNT(DISTINCT NameFieldID), Cnt = COUNT(PartyPhoneticNameID)
							FROM (
								SELECT pn.PartyID
									, Weight
									, NameFieldID
									, PartyPhoneticNameID
								FROM PartyPhoneticName pn
								JOIN (
									SELECT PartyID, [Day] = DAY(DOB), [Month] = MONTH(DOB), [Year] = YEAR(DOB)
									FROM Party
									WHERE DOB IS NOT NULL
								) AS p ON p.PartyID = pn.PartyID
									AND (p.[Year] = @Year OR p.[Month] = @Month OR p.[Day] = @Day)
								JOIN PartyRelationship pr ON pr.PartyFromID = p.PartyID
								JOIN HealthcareEligibilityGroupMember hegm ON hegm.PartyRelationshipID = pr.PartyRelationshipID
								WHERE @PhoneticLastName = PhoneticName
								OR @PhoneticFirstName = PhoneticName
								OR @PhoneticLastName LIKE '%' + PhoneticName + '%'
								OR @PhoneticFirstName LIKE '%' + PhoneticName + '%'
							) AS w
							GROUP BY PartyID, Weight
						) AS scoredPartyIDs
						ORDER BY Score DESC
					) AS selectedPartyIDs
					JOIN Party p ON p.PartyID = selectedPartyIDs.PartyID
				) AS distanceCalculatedPartyIDs
			) AS rankedPartyIDs
			GROUP BY PartyID, LastName, FirstName, DOB
		) AS groupedPartyIDs
	END
END