using System;
using EntityResolution;

namespace EntityResolver.ConsoleApp
{
    class Program
    {
        static void Main(string[] args)
        {
            string left = "Klueppel";
            string right = "Knopfel";

            int distance = LevenshteinDistanceCalculator.Calculate(left, right);
            Console.WriteLine($"Levenshtein distance between '{left}' and '{right}' is {distance}");
        }
    }
}