DECLARE @SearchTerm VARCHAR(100) = 'Austin Dallas'
DECLARE @SearchTermSoundex VARCHAR(50)
SELECT @SearchTermSoundex = dbo.fn_PhoneticallyEncodeName(@SearchTerm)
SELECT SearchTerm = @SearchTerm, SearchTermSoundex = @SearchTermSoundex


-- SELECT EntityId = e.Id, e.EntityType, e.EntityValue1, e.EntityValue2, n.PhoneticName, n.NameFieldId, n.[Weight], RowId = ROW_NUMBER() OVER (PARTITION BY e.EntityType, e.EntityValue1, e.EntityValue2 ORDER BY [Weight] DESC)
-- FROM Entity e
-- JOIN EntityPhoneticName n ON e.Id = n.EntityId
--     AND NULLIF(n.PhoneticName, '') IS NOT NULL
-- WHERE n.PhoneticName = @SearchTermSoundex
-- OR @SearchTermSoundex LIKE '%' + n.PhoneticName + '%'

SELECT *, Distance = dbo.fn_LevenshteinDistance(@SearchTerm, w.EntityValue1 + CASE WHEN w.EntityValue2 IS NULL THEN '' ELSE ' ' + w.EntityValue2 END)
FROM (
    SELECT EntityId = e.Id, e.EntityType, e.EntityValue1, e.EntityValue2, n.PhoneticName, n.NameFieldId, n.[Weight], RowId = ROW_NUMBER() OVER (PARTITION BY e.EntityType, e.EntityValue1, e.EntityValue2 ORDER BY [Weight] DESC)
    FROM Entity e
    JOIN EntityPhoneticName n ON e.Id = n.EntityId
        AND NULLIF(n.PhoneticName, '') IS NOT NULL
    WHERE n.PhoneticName = @SearchTermSoundex
    OR @SearchTermSoundex LIKE '%' + n.PhoneticName + '%'
    --ORDER BY e.EntityType, e.EntityValue1, e.EntityValue2
) AS w
WHERE w.RowId = 1
ORDER BY Distance ASC