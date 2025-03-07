// filepath: /Users/scott/Projects/Soundex/EntityResolution/LevenshteinDistanceCalculator.cs
using System;

namespace EntityResolution
{
    public static class LevenshteinDistanceCalculator
    {
        public static int Calculate(string left, string right)
        {
            if (left == null) throw new ArgumentNullException(nameof(left));
            if (right == null) throw new ArgumentNullException(nameof(right));

            int leftLength = left.Length;
            int rightLength = right.Length;

            if (leftLength == 0) return rightLength;
            if (rightLength == 0) return leftLength;

            int[] previousRow = new int[rightLength + 1];
            int[] currentRow = new int[rightLength + 1];

            for (int j = 0; j <= rightLength; j++)
            {
                previousRow[j] = j;
            }

            for (int i = 1; i <= leftLength; i++)
            {
                currentRow[0] = i;
                for (int j = 1; j <= rightLength; j++)
                {
                    int cost = (left[i - 1] == right[j - 1]) ? 0 : 1;
                    currentRow[j] = Math.Min(
                        Math.Min(previousRow[j] + 1, currentRow[j - 1] + 1),
                        previousRow[j - 1] + cost);
                }

                var temp = previousRow;
                previousRow = currentRow;
                currentRow = temp;
            }

            return previousRow[rightLength];
        }
    }
}