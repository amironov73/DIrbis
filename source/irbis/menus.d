/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

module irbis.menus;

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
 * Two lines in the MNU-file.
 */
final class MenuEntry
{
    string code; /// Code.
    string comment; /// Comment.

    /// Constructor.
    this() {
    } // constructor

    /// Constructor.
    this(string code, string comment) {
        this.code = code;
        this.comment = comment;
    } // constructor

    override string toString() const {
        return code ~ " - " ~ comment;
    } // method toString

} // class MenuEntry

//==================================================================

/**
 * MNU-file wrapper.
 */
final class MenuFile
{
    MenuEntry[] entries; /// Slice of entries.

    /**
     * Add an entry.
     */
    MenuFile append(string code, string comment) {
        auto entry = new MenuEntry(code, comment);
        entries ~= entry;
        return this;
    } // method append

    /**
     * Clear the menu.
     */
    MenuFile clear() nothrow {
        entries = [];
        return this;
    } // method clear

    /**
     * Get entry.
     */
    MenuEntry getEntry(string code) {
        if (entries.empty)
            return null;

        foreach (entry; entries)
            if (sameString(entry.code, code))
                return entry;

        code = strip(code);
        foreach (entry; entries)
            if (sameString(entry.code, code))
                return entry;

        code = strip(code, "-=:");
        foreach (entry; entries)
            if (sameString(entry.code, code))
                return entry;

        return null;
    } // method getEntry

    /**
     * Get value.
     */
    string getValue(string code, string defaultValue="") {
        auto entry = getEntry(code);
        if (entry is null)
            return defaultValue;
        return entry.comment;
    } // method getValue

    /**
     * Parse text representation.
     */
    void parse(string[] lines) {
        for(int i=0; i < lines.length; i += 2) {
            auto code = lines[i];
            if (code.length == 0 || code.startsWith("*****"))
                break;
            auto comment = lines[i+1];
            auto entry = new MenuEntry(code, comment);
            entries ~= entry;
        }
    } // method parse

    override string toString() const {
        auto result = new OutBuffer();
        foreach(entry; entries) {
            result.put(entry.toString());
            result.put("\n");
        }
        result.put("*****");

        return result.toString;
    } // method toString

} // class MenuFile
