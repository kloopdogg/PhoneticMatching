DROP TABLE #Entities
DROP TABLE #EntityPhoneticName

DECLARE @Errors INT
SET @Errors = 0

CREATE TABLE #Entities (EntityId INT, PhoneticName1 VARCHAR(200), PhoneticName2 VARCHAR(200))
INSERT #Entities (EntityId, PhoneticName1, PhoneticName2)
SELECT DISTINCT e.Id, dbo.fn_PhoneticallyEncodeName(e.EntityValue1), CASE WHEN e.EntityValue1 IS NULL THEN NULL ELSE dbo.fn_PhoneticallyEncodeName(e.EntityValue2) END
FROM Entity e 
IF @@ERROR <> 0 SET @Errors = @Errors + 1

CREATE TABLE #EntityPhoneticName (RowID INT IDENTITY(1,1), EntityId INT, PhoneticName VARCHAR(200), NameFieldId INT, [Weight] DECIMAL(18,3))

-- Insert full first names
INSERT #EntityPhoneticName (EntityId, PhoneticName, NameFieldId, [Weight])
SELECT DISTINCT EntityId, PhoneticName1, 1, 1
FROM #Entities
IF @@ERROR <> 0 SET @Errors = @Errors + 1

-- Insert full last names
INSERT #EntityPhoneticName (EntityId, PhoneticName, NameFieldId, [Weight])
SELECT DISTINCT EntityId, PhoneticName2, 2, 1
FROM #Entities
WHERE PhoneticName2 IS NOT NULL
IF @@ERROR <> 0 SET @Errors = @Errors + 1

-- Insert LEFT(6) first names
INSERT #EntityPhoneticName (EntityId, PhoneticName, NameFieldId, [Weight])
SELECT DISTINCT EntityId, LEFT(PhoneticName1, 6), 1, 0.9
FROM #Entities
IF @@ERROR <> 0 SET @Errors = @Errors + 1

-- Insert LEFT(6) last names
INSERT #EntityPhoneticName (EntityId, PhoneticName, NameFieldId, [Weight])
SELECT DISTINCT EntityId, LEFT(PhoneticName2, 6), 2, 0.9
FROM #Entities
WHERE PhoneticName2 IS NOT NULL
IF @@ERROR <> 0 SET @Errors = @Errors + 1

-- Insert LEFT(4) first names
INSERT #EntityPhoneticName (EntityId, PhoneticName, NameFieldId, [Weight])
SELECT DISTINCT EntityId, LEFT(PhoneticName1, 4), 1, 0.5
FROM #Entities
IF @@ERROR <> 0 SET @Errors = @Errors + 1

-- Insert LEFT(4) last names
INSERT #EntityPhoneticName (EntityId, PhoneticName, NameFieldId, [Weight])
SELECT DISTINCT EntityId, LEFT(PhoneticName2, 4), 2, 0.5
FROM #Entities
WHERE PhoneticName2 IS NOT NULL
IF @@ERROR <> 0 SET @Errors = @Errors + 1

-- Insert RIGHT(4) first names
INSERT #EntityPhoneticName (EntityId, PhoneticName, NameFieldId, [Weight])
SELECT DISTINCT EntityId, RIGHT(PhoneticName1, 4), 1, 0.5
FROM #Entities
IF @@ERROR <> 0 SET @Errors = @Errors + 1

-- Insert RIGHT(4) last names
INSERT #EntityPhoneticName (EntityId, PhoneticName, NameFieldId, [Weight])
SELECT DISTINCT EntityId, RIGHT(PhoneticName2, 4), 2, 0.5
FROM #Entities
WHERE PhoneticName2 IS NOT NULL
IF @@ERROR <> 0 SET @Errors = @Errors + 1

IF @Errors = 0
BEGIN
    BEGIN TRANSACTION

    SELECT DISTINCT * 
    FROM #EntityPhoneticName
    WHERE NULLIF(PhoneticName, '') IS NOT NULL
    --GROUP BY PhoneticName -- take max weight only

    DELETE EntityPhoneticName
    IF @@ERROR <> 0 SET @Errors = @Errors + 1

    INSERT EntityPhoneticName (PhoneticName, NameFieldId, [Weight], EntityId)
    SELECT DISTINCT PhoneticName, NameFieldId, [Weight], EntityId
    FROM #EntityPhoneticName
    WHERE NULLIF(PhoneticName, '') IS NOT NULL
    IF @@ERROR <> 0 SET @Errors = @Errors + 1

    -- UPDATE ppn
    -- SET ppn.PhoneticName = temp.PhoneticName
    -- FROM EntityPhoneticName ppn
    -- JOIN #EntityPhoneticName temp ON temp.PartyID = ppn.PartyID
    --     AND temp.NameFieldID = ppn.NameFieldID
    --     AND temp.Weight = ppn.Weight
    --     AND temp.PhoneticName <> ppn.PhoneticName
    -- LEFT JOIN (
    --     SELECT RowID
    --     FROM EntityPhoneticName ppn
    --     JOIN #EntityPhoneticName temp ON temp.PartyID = ppn.PartyID
    --         AND temp.NameFieldID = ppn.NameFieldID
    --         AND temp.Weight = ppn.Weight
    --         AND temp.PhoneticName = ppn.PhoneticName
    -- ) matches ON matches.RowID = temp.RowID
    -- WHERE matches.RowID IS NULL
    -- IF @@ERROR <> 0 SET @Errors = @Errors + 1

    -- INSERT EntityPhoneticName (PartyID, PhoneticName, NameFieldID, Weight, CreatedBy, ModifiedBy)
    -- SELECT temp.PartyID, temp.PhoneticName, temp.NameFieldID, temp.Weight, @UserID, @UserID
    -- FROM #EntityPhoneticName temp
    -- LEFT JOIN EntityPhoneticName ppn ON ppn.PartyID = temp.PartyID
    --     AND ppn.NameFieldID = temp.NameFieldID
    --     AND ppn.Weight = temp.Weight
    -- WHERE ppn.PartyID IS NULL
    -- IF @@ERROR <> 0 SET @Errors = @Errors + 1

    -- DELETE pn
    -- FROM EntityPhoneticName pn
    -- JOIN #EntityPhoneticName tpn ON tpn.PartyID = pn.PartyID
    -- AND pn.EntityPhoneticNameID NOT IN (
    --     SELECT DISTINCT ppn.EntityPhoneticNameID
    --     FROM EntityPhoneticName ppn
    --     JOIN #EntityPhoneticName temp ON temp.PartyID = ppn.PartyID
    --         AND temp.NameFieldID = ppn.NameFieldID
    --         AND temp.Weight = ppn.Weight
    --         AND temp.PhoneticName = ppn.PhoneticName
    -- )
    -- IF @@ERROR <> 0 SET @Errors = @Errors + 1
END

IF @Errors <> 0
BEGIN
    ROLLBACK TRANSACTION			
    RAISERROR(N'EntityPhoneticName could not be refreshed.', 11, 1, NULL)
END
ELSE
BEGIN
    COMMIT TRANSACTION
END
