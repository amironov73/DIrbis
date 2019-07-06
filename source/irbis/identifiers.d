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
    }

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
    }

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
        digits[12] = 'X';

        return to!string(digits);
    } // method toEan13

    /// Validate the isbn
    static bool validate(string isbn) {
        return checkHyphens(isbn) && checkControlDigit(isbn);
    } // method validate

} // class Isbn
