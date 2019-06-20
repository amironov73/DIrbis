/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

module irbis.fst;

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

import irbis.utils;

//==================================================================

/// FST file line.
final class FstLine
{
    /// Line number.
    int lineNumber;

    /// Field tag.
    int tag;

    /// Index method.
    int method;

    /// Format itself.
    string format;

    /// Parse one line of text.
    void parse(string text) {
        auto parts = splitN(text, " ", 3);
    } // method parse

} // class FstLine

//==================================================================

/// FST file.
final class FstFile
{

} // class FstFile

//==================================================================
