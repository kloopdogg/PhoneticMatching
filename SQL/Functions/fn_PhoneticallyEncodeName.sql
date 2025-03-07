
/*
SELECT dbo.fn_PhoneticallyEncodeName('Klueppel')
SELECT dbo.fn_PhoneticallyEncodeName('Kluepfel III')
SELECT dbo.fn_PhoneticallyEncodeName('Knopfel')
SELECT dbo.fn_PhoneticallyEncodeName('Klappel, Sr.')
SELECT dbo.fn_PhoneticallyEncodeName('Culpepper, MD')
SELECT dbo.fn_PhoneticallyEncodeName('Rudolph')
SELECT dbo.fn_PhoneticallyEncodeName('ULYSSIS')
SELECT dbo.fn_PhoneticallyEncodeName('SANCHEZ')
SELECT dbo.fn_PhoneticallyEncodeName('Sanchez-Romero')
SELECT dbo.fn_PhoneticallyEncodeName('Rivera')
SELECT dbo.fn_PhoneticallyEncodeName('Romero')
SELECT dbo.fn_PhoneticallyEncodeName('REINHARDT')
SELECT dbo.fn_PhoneticallyEncodeName('A')
SELECT dbo.fn_PhoneticallyEncodeName('D')
SELECT dbo.fn_PhoneticallyEncodeName('theodore')
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF EXISTS (SELECT * FROM sysobjects WHERE id = object_id(N'[dbo].[fn_PhoneticallyEncodeName]'))
DROP FUNCTION [dbo].[fn_PhoneticallyEncodeName]
GO

CREATE FUNCTION [dbo].[fn_PhoneticallyEncodeName]
(
	@InputString VARCHAR(50)
)
RETURNS VARCHAR(50)
AS
BEGIN
	/* This algorithm is from the New York State Identification and Intelligence System (NYSIIS) Phonetic Encoder - Modified (variant) Algorithm */

    DECLARE @Key VARCHAR(50),
            @Char VARCHAR(3),
            @Chars VARCHAR(3),
            @Vowels VARCHAR(10),
            @FirstChar CHAR(1),
            @Result VARCHAR(10)

    DECLARE @i INT

    /* Vowels */
    SELECT @Vowels = 'AEIOU'

	/* Convert all characters to upper case */
    SELECT @InputString = UPPER(@InputString)

	/* Remove JR, SR, and Roman Numerals from the end of the string */
	IF CHARINDEX(' ', @InputString)  > 0
	BEGIN
		SELECT @InputString = CASE
			WHEN RIGHT(@InputString, 2) IN (' I') THEN LEFT(@InputString, LEN(@InputString) - 2)
			WHEN RIGHT(@InputString, 3) IN (' II', ' IV', ' VI', ' JR', ' SR', ' MD') THEN LEFT(@InputString, LEN(@InputString) -3)
			WHEN RIGHT(@InputString, 4) IN (' III', ', SR', ', JR', ', MD', ' SR.', ' JR.', ' PHD') THEN LEFT(@InputString, LEN(@InputString) -4)
			WHEN RIGHT(@InputString, 5) IN (', SR.', ', JR.', ', PHD') THEN LEFT(@InputString, LEN(@InputString) -5)
			ELSE @InputString END
	END

    /* Trim all trailing whitespace and special characters */
    SELECT @InputString = dbo.fn_RemoveSpecialCharacters(@InputString, NULL, NULL)

    /* ( 0) Save first character */
    SELECT @FirstChar = LEFT(@InputString, 1)

    /* ( 1) Remove all 'S' and 'Z' characters from the end of the surname */
    SELECT @i = LEN(@InputString)
    WHILE SUBSTRING(@InputString, @i, 1) IN ('S', 'Z')
        SELECT @i = @i - 1
    SELECT @InputString = LEFT(@InputString, @i)

    /* ( 2) Transcode initial strings */
    /*      MAC => MC                 */
    /*      PF => F                   */
    SELECT @InputString = CASE
		WHEN LEFT(@InputString, 3) = 'MAC' THEN 'MC' + SUBSTRING(@InputString, 3, LEN(@InputString))
		WHEN LEFT(@InputString, 2) = 'PF' THEN 'F' + SUBSTRING(@InputString, 3, LEN(@InputString))
		ELSE @InputString END

    /* ( 3) Transcode trailing strings as follows */
    /*      IX       => IC                        */
    /*      EX       => EC                        */
    /*      YE,EE,IE => Y                         */
    /*      NT,ND    => D                         */
	DECLARE @Previous VARCHAR(50)
	SET @Previous = ''
	WHILE @Previous <> @InputString
	BEGIN
		SELECT @Previous = @InputString, @InputString = CASE
			WHEN RIGHT(@InputString, 2) = 'IX' THEN LEFT(@InputString, LEN(@InputString) - 2 ) + 'IC'
			WHEN RIGHT(@InputString, 2) = 'EX' THEN LEFT(@InputString, LEN(@InputString) - 2 ) + 'EC'
			WHEN RIGHT(@InputString, 2) IN ('YE', 'EE', 'IE') THEN LEFT(@InputString, LEN(@InputString) - 2) + 'Y'
			WHEN RIGHT(@InputString, 2) IN ('DT', 'RT', 'RD', 'NT', 'ND') THEN LEFT(@InputString, LEN(@InputString) - 2) + 'D'
			ELSE @InputString END
	END

	/* ( 4) Transcode 'EV' to 'EF' if not at start of name */
    SELECT @InputString = CASE
		WHEN LEFT(@InputString, 2) = 'EV' THEN RIGHT(@InputString, LEN(@InputString) - 2 ) + 'AF' 
        ELSE @InputString END

    /* ( 5) Use first character of name as first character of key */
    /* SELECT @Key = LEFT(@InputString, 1) */
    /* Most implementations skip this step or don't use the following loop for the 
	   first character if this step is included. */
    SELECT @Key = ''

    SELECT @i = 1
    /* Loop through each character in @InputString */
    WHILE SUBSTRING(@InputString, @i, 1) > ''
    BEGIN
        SELECT @Chars = SUBSTRING(@InputString, @i, 3)

        SELECT @Result = CASE
			/* ( 6) Remove any 'W' that follows a vowel */
			WHEN LEFT(@Chars, 1) = 'W' AND CHARINDEX(SUBSTRING(@InputString, @i - 1, 1), @Vowels) > 0 THEN SUBSTRING(@InputString, @i - 1, 1)
			/* ( 7) Replace all vowels with 'A' */
			WHEN CHARINDEX(LEFT(@Chars, 1), @Vowels) > 0 THEN 'A'
			/* ( 8) Transcode 'GHT' to 'GT' */
			WHEN LEFT(@Chars, 2) = 'GHT' THEN 'GGG'
			/* ( 9) Transcode 'DG' to 'G' */
			WHEN LEFT(@Chars, 2) = 'DG' THEN ' G'
			/* (10) Transcode 'PH' to 'F' */
			WHEN LEFT(@Chars, 2) = 'PH' THEN ' F'
			/* (11) If not first character, eliminate all 'H' preceded or followed by a vowel */
			WHEN LEFT(@Chars, 1) = 'H' AND @i > 1 AND ( CHARINDEX( SUBSTRING( @InputString, @i - 1, 1 ), @Vowels ) > 0 OR CHARINDEX( SUBSTRING( @InputString, @i + 1, 1 ), @Vowels ) > 0 ) THEN SUBSTRING( @InputString, @i - 1, 1 )
			/* (12) Change 'KN' to 'N', else 'K' to 'C' */
			WHEN LEFT(@Chars, 2) = 'KN' THEN ' N'
			WHEN LEFT(@Chars, 1) = 'K' THEN 'C'
			/* (13) If not first character, change 'M' to 'N' */
			WHEN @i > 1 AND LEFT(@Chars, 1) = 'M' THEN 'N'
			/* (14) If not first character, change 'Q' to 'G' */
			WHEN @i > 1 AND LEFT(@Chars, 1) = 'Q' THEN 'G'
			/* (15) Transcode 'SH' to 'S' */
			WHEN LEFT(@Chars, 2) = 'SH' THEN ' S'
			/* (16) Transcode 'SCH' to 'S' */
			WHEN @Chars = 'SCH' THEN '  S' 
			/* (17) Transcode 'YW' to 'Y' */
			WHEN LEFT(@Chars, 2) = 'YW' THEN ' Y'
			/* (18) If not first or last character, change 'Y' to 'A' */
			WHEN @i > 1 AND @i < LEN(@InputString) AND LEFT(@Chars, 1) = 'Y' THEN 'A'     
			/* (19) Transcode 'WR' to 'R' */
			WHEN LEFT(@Chars, 2) = 'WR' THEN ' R'
			/* (20) If not first character, change 'Z' to 'S' */
			WHEN @i > 1 AND LEFT(@Chars, 1) = 'Z' THEN 'S'
			/* Use the input character */
			ELSE LEFT(@Chars, 1) END
 
        SELECT @InputString = STUFF(@InputString, @i, LEN(@Result), LTRIM(@Result))
        /* (23 modfied) Add current result to key (phonetic code) if current <> last key character */
        IF RIGHT(@Key, 1) != LEFT(LTRIM(@Result), 1)
            SELECT @Key = @Key + LTRIM(@Result)

        SELECT @i = @i + 1
    END

    /* (21) Transcode terminal 'AY' to 'Y' */
    IF RIGHT(@Key, 2) = 'AY'
        SELECT @Key = LEFT(@Key, LEN( @Key) - 2) + 'Y'
  
    /* (22) Remove traling vowels */
	SET @i = LEN(@Key)
    WHILE CHARINDEX(SUBSTRING(@Key, @i, 1), @Vowels) > 0
	BEGIN
        /* Replace vowels with empty string */
        SELECT @Key = STUFF(@Key, @i, 1, ''),
               @i = @i - 1
	END

    /* (23) Collapse all strings of repeated characters */
    /* Not needed, see step (23 modified) before step (21) as the last step in the loop */

	/* (24) If first character of original name was a vowel, prepend on code (or replace first transcoded 'A') */
    IF CHARINDEX(@FirstChar, @Vowels) > 0
	BEGIN
		IF CHARINDEX(@Key, 'A') = 0
		BEGIN
			IF LEN(@Key) = 0
				SELECT @Key = @FirstChar
			ELSE
				SELECT @Key = STUFF(@Key, 1, 1, @FirstChar)
		END
		ELSE
			SELECT @Key = @FirstChar + @Key
	END
	
    RETURN @Key
END