/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

module irbis.identifiers;

import std.algorithm: canFind, remove;
import std.array;
import std.bitmanip;
import std.conv;
import std.encoding: transcode, Windows1251String;
import std.random: uniform;
import std.socket;
import std.stdio;
import std.string;
import std.outbuffer;
import std.uni;

//==================================================================

/// EAN8
final class Ean8
{
    /// Coefficients for check digit calculation.
    static int[8] coefficients = [3, 1, 3, 1, 3, 1, 3, 1];

    /// Compute check digit
    static char computeCheckDigit(string digits) {
        auto sum = 0;
        for(auto i = 0; i < 7; i++)
            sum = sum + (digits[i] - '0') * coefficients[i];
        const result = cast(char)(10 - sum % 10 + '0');
        return result;
    } // method computeCheckDigit

    /// Test for computeCheckDigit
    unittest {
        assert(computeCheckDigit("46009333") == '3');
    } // unittest

    /// Check the control digit
    static bool checkControlDigit(string digits) {
        auto sum = 0;
        for(auto i = 0; i < 8; i++)
            sum = sum + (digits[i] - '0') * coefficients[i];
        const result = sum % 10 == 0;
        return result;
    } // method checkControlDigit

    /// Test for checkControlDigit
    unittest {
        assert(checkControlDigit("46009333"));
        assert(!checkControlDigit("46009332"));
    } // unittest

} // class Ean8

//==================================================================

/// EAN13
final class Ean13
{
    /// Coefficients for check digit calculation.
    static int[13] coefficients = [ 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1, 3, 1 ];

    /// Compute check digit.
    static char computeCheckDigit(string digits) {
        auto sum = 0;
        for(auto i = 0; i < 12; i++)
            sum = sum + (digits[i] - '0') * coefficients[i];
        const result = cast(char)(10 - sum % 10 + '0');
        return result;
    } // method computeCheckDigit

    /// Test for computeControlDigit
    unittest {
        assert(computeCheckDigit("4600051000057") == '7');
    } // unittest

    /// Check the control digit.
    static bool checkControlDigit(string digits) {
        auto sum = 0;
        for(auto i=0; i < 13; i++)
            sum = sum + (digits[i] - '0') * coefficients[i];
        const result = sum % 10 == 0;
        return result;
    } // method checkControlDigit

    /// Test for checkControlDigit
    unittest {
        assert(checkControlDigit("4600051000057"));
        assert(!checkControlDigit("4600051000056"));
    } // unittest

} // class Ean13

//==================================================================

/// ISBN
final class Isbn
{
    /// Check control digit
    static bool checkControlDigit(string isbn, char hyphen='-') {
        if (isbn.length != 13)
            return false;

        isbn = isbn.toUpper;
        const len = isbn.length;
        int[10] digits;
        int i, j, sum;
        for(i = j = 0; i < len; i++) {
            const chr = isbn[i];
            if (chr == hyphen)
                continue;
            if (chr == 'X') {
                if (j == 9)
                    digits[j] = 10;
                else
                    return false;
            } else {
                if (chr >= '0' && chr <= '9')
                    digits[j++] = cast(int)chr - 48;
                else
                    return false;
            } // else
        } // for

        for (i = sum = 0; i < 10; i++)
            sum += digits[i] * (10 - i);
        sum %= 11;

        return sum == 0;
    } // method checkControlDigit

    /// Test for checkControlDigit
    unittest {
        assert(checkControlDigit("5-02-003206-9"));
        assert(!checkControlDigit("5-02-0032239-5"));
        assert(!checkControlDigit("5-85-202-063-X"));
        assert(checkControlDigit("5-01-001033-X"));
        assert(!checkControlDigit("5-01-00103X-3"));
        assert(!checkControlDigit("5-01-00A033-X"));
    } // unittest

    /// Check hyphens.
    static bool checkHyphens(string isbn, char hyphen='-') {
        int count = 0;
        const len = isbn.length;
        if (len < 2 || isbn[0] == hyphen
            || isbn[len - 1] == hyphen
            || isbn[len - 2] != hyphen)
            return false;

        for(int i=0; i < len-1; i++)
        if (isbn[i] == hyphen) {
            if (isbn[i+1] == hyphen)
                return false;
            count++;
        }

        //writeln(count);

        return count == 3;
    } // method checkHyphens

    /// Test for checkHyphens
    unittest {
        assert(checkHyphens("5-02-003157-7"));
        assert(checkHyphens("5-02-003228-X"));
        assert(!checkHyphens("502003228X"));
        assert(!checkHyphens("5-02--03157-7"));
        assert(!checkHyphens("5-02--0031577"));
    } // unittest

    /// Convert the ean to ISBN
    static string fromEan13(string ean) {
        if (ean.length != 13)
            return null;

        char[] digits = [ ' ', '-', ' ', ' ', ' ', '-', ' ', ' ', ' ', ' ', ' ', '-', ' ' ];
        char[] possible = [ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'X' ];

        // Skip beginning 978
        // country
        digits[0] = ean[3];
        // publisher
        digits[2] = ean[4];
        digits[3] = ean[5];
        digits[4] = ean[6];
        // book number
        digits[6] = ean[7];
        digits[7] = ean[8];
        digits[8] = ean[9];
        digits[9] = ean[10];
        digits[10] = ean[11];
        // control digit
        for(int i = 0; i < possible.length; i++) {
            digits[12] = possible[i];
            auto result = to!string(digits);
            if (checkControlDigit(result))
                return result;
        }
        return null;
    } // method fromEan13

    /// Test for fromEan13
    unittest {
        assert(fromEan13("9785020032064") == "5-020-03206-9");
    } // unittest

    /// Convert the isbn to EAN13.
    static string toEan13(string isbn) {
        if (isbn.length != 13)
            return null;

        char[13] digits =
        [
            '9', '7', '8', ' ', ' ', ' ', ' ', ' ',
            ' ', ' ', ' ', ' ', ' '
        ];

        for(int i = 0, j= 2; i < isbn.length; i++) {
            const chr = isbn[i];
            if (chr >= '0' && chr <= '9')
                digits[++j] = chr;
        }
        digits[12] = Ean13.computeCheckDigit(cast(string)digits);

        return to!string(digits);
    } // method toEan13

    /// Test for toEan13
    unittest {
        assert(toEan13("5-02-003206-9") == "9785020032064");
    } // unittest

    /// Validate the isbn
    static bool validate(string isbn) {
        return checkHyphens(isbn) && checkControlDigit(isbn);
    } // method validate

} // class Isbn

//==================================================================

/// ISSN
final class Issn
{
    /// Coefficients for check digit calculation.
    static immutable int[8] coefficients = [ 8, 7, 6, 5, 4, 3, 2, 1 ];

    private static int convertDigit(char c) {
        const result = c == 'X' || c == 'x' ? 10 : c - '0';
        return result;
    } // method convertDigit

    private static char convertDigit(int n) {
        const result = n == 10 ? 'X' : cast(char)('0' + n);
        return result;
    } // method convertDigit

    /// Compute check digit.
    static char computeCheckDigit(string digits) {
        auto sum = 0;
        for(auto i = 0; i < 7; i++)
            sum += convertDigit(digits[i]) * coefficients[i];
        const result = convertDigit(11 - sum % 11);
        return result;
    } // method computeCheckDigit

    /// Test for computeCheckDigit
    unittest {
        assert(computeCheckDigit("0033765X") == 'X');
    } // unittest

    /// Check control digit
    static bool checkControlDigit(string digits) {
        if (digits.length != 8)
            return false;

        auto sum = 0;
        for(auto i = 0; i < 8; i++)
            sum += convertDigit(digits[i]) * coefficients[i];
        const result = sum % 11 == 0;
        return result;
    } // method checkControlDigit

    /// Test for
    unittest {
        assert(checkControlDigit("0033765X"));
        assert(!checkControlDigit("00337651"));
    } // unittest

} // class Issn

//==================================================================

/// International Standard Name Identifier.
final class Isni
{
    /// Compute
    static char computeCheckDigit(string digits) {
        auto sum = 0;
        for(auto i = 0; i < digits.length; i++)
            sum = (sum + digits[i] - '0') * 2;
        const remainder = sum % 11;
        const checkNumber = (12 - remainder) % 11;
        const result = checkNumber == 10 ? 'X' : checkNumber + '0';
        return result;
    } // method computeCheckDigit

    /// Test for computeCheckDigit
    unittest {
        assert(computeCheckDigit("000000029534656") == 'X');
        assert(computeCheckDigit("000000021825009") == '7');
        assert(computeCheckDigit("000000015109370") == '0');
        assert(computeCheckDigit("000000021694233") == 'X');
    } // unittest

} // class Isni

//==================================================================
