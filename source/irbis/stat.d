/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

module irbis.stat;

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

import irbis.constants, irbis.utils;

enum DONT_SORT = 0; /// Don't sort lines.
enum SORT_ASCENDING = 1; /// Ascending sort.
enum SORT_DESCENDING = 2; /// Descending sort.

/// Stat item.
struct StatItem
{
    string field; /// Field (possibly with subfield) specification.
    int length; /// Maximum length of the value (truncation control).
    int count; /// Count of items to take.
    int sort; /// How to sort result lines.

    string toString() const {
        return field ~ ","
            ~ to!string(length) ~ ","
            ~ to!string(count) ~ ","
            ~ to!string(sort);
    } // method toString

} // struct StatItem

/// Data for Stat command.
final class StatDefinition
{
    string database; /// Database name.
    StatItem[] items; /// Items.
    string searchExpression; /// Search query specification.
    int minMfn; /// Minimal MFN.
    int maxMfn; /// Maximal MFN.
    string sequentialSearch; /// Optional query for sequential search.
    int[] mfnList; /// List of records (optional).
} // class StatDefinition
