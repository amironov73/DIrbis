/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

module irbis.spec;

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

/**
 * Path to file: path.database.filename.
 */
struct FileSpecification
{
    enum SYSTEM = 0; /// System-wide path.
    enum DATA = 1; /// Place for information about the IRBIS 64 server databases.
    enum MASTER = 2; /// Path to the master database file.
    enum INVERTED = 3; /// Path to the database dictionary.
    enum PARAMETER = 10; /// Path to the database parameter.
    enum FIULLTEXT = 11; /// Full text.

    int path; /// Path.
    string database; /// Database name (if any).
    string filename; /// File name.
    string content; /// Content of file (if any).
    bool isBinary; /// Is binary file?

    /// Constructor.
    this (int path, string database, string filename) {
        this.path = path;
        this.database = database;
        this.filename = filename;
    } // constructor

    /// Constructor.
    this(int path, string filename) {
        this.path = path;
        this.filename = filename;
    } // constructor

    /// Shortcut.
    static FileSpecification master(string database, string filename) {
        return FileSpecification(MASTER, database, filename);
    } // method master

    /// Parse the text representation of the specification.
    static FileSpecification parse(string text) {
        const parts = splitN(text, ".", 3);
        const path = parseInt(parts[0]);
        return FileSpecification(path, parts[1], parts[2]);
    } // method parse

    /// Shortcut.
    static FileSpecification system(string filename) {
        return FileSpecification(SYSTEM, filename);
    } // method system

    string toString() const {
        string result = filename;

        if (isBinary)
            result = "@" ~ filename;
        else if (!content.empty)
            result = "&" ~ filename;

        switch(path) {
            case 0:
            case 1:
                result = to!string(path) ~ ".." ~ result;
                break;

            default:
                result = to!string(path) ~ "." ~ database ~ "." ~ result;
                break;
        } // switch

        if (!content.empty)
            result = result ~ "&" ~ content;

        return result;
    } // method toString

} // struct FileSpecification
