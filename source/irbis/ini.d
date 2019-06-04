/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

module irbis.ini;

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
 * Line of INI-file. Consist of a key and value.
 */
final class IniLine
{
    string key; /// Key string.
    string value; /// Value string

    pure override string toString() const {
        return this.key ~ "=" ~ this.value;
    } // method toString

} // class IniLine

//==================================================================

/**
 * Section of INI-file. Consist of lines (see IniLine).
 */
final class IniSection
{
    string name; /// Name of the section.
    IniLine[] lines; /// Lines.

    /**
     * Find INI-line with specified key.
     */
    pure IniLine find(string key)
    {
        foreach (line; lines)
            if (sameString(line.key, key))
                return line;
        return null;
    }

    /**
     * Get value for specified key.
     * If no entry found, default value used.
     */
    pure string getValue(string key, string defaultValue="") {
        auto found = find(key);
        return (found is null) ? defaultValue : found.value;
    }

    /**
     * Remove line with specified key.
     */
    void remove(string key)
    {
        // TODO implement
    } // method remove

    /**
     * Set the value for specified key.
     */
    IniSection setValue(string key, string value) {
        if (value is null)
            remove(key);
        else {
            auto item = find(key);
            if (item is null) {
                item = new IniLine;
                lines ~= item;
                item.key = key;
            }
            item.value = value;
        }

        return this;
    } // method setValue

    pure override string toString() const {
        auto result = new OutBuffer;
        if (!name.empty) {
            result.put("[");
            result.put(name);
            result.put("]");
        }
        foreach (line; lines) {
            result.put(line.toString);
            result.put("\n");
        }
        return result.toString();
    } // method toString

} // class IniSection

//==================================================================

/**
 * INI-file. Consist of sections (see IniSection).
 */
final class IniFile
{
    IniSection[] sections; /// Slice of sections.

    /**
     * Find section with specified name.
     */
    pure IniSection findSection(string name)
    {
        foreach (section; sections)
            if (sameString(section.name, name))
                return section;
        return null;
    }

    /**
     * Get section with specified name.
     * Create the section if it doesn't exist.
     */
    IniSection getOrCreateSection(string name)
    {
        auto result = findSection(name);
        if (result is null)
        {
            result = new IniSection();
            result.name = name;
            sections ~= result;
        }
        return result;
    }

    /**
     * Get the value from the specified section and key.
     */
    pure string getValue(string sectionName, string key, string defaultValue="")
    {
        auto section = findSection(sectionName);
        return (section is null)
            ? defaultValue : section.getValue(key, defaultValue);
    }

    /**
     * Parse the text representation of the INI-file.
     */
    void parse(string[] lines) {
        IniSection section = null;
        foreach (line; lines) {
            auto trimmed = strip(line);
            if (line.empty)
                continue;

            if (trimmed[0] == '[') {
                auto name = trimmed[1..$-1];
                section = getOrCreateSection(name);
            }
            else if (!(section is null)) {
                auto parts = split2(trimmed, "=");
                if (parts.length != 2)
                    continue;
                auto key = strip(parts[0]);
                if (key.empty)
                    continue;
                auto value = strip(parts[1]);
                auto item = new IniLine();
                item.key = key;
                item.value = value;
                section.lines ~= item;
            }
        }
    } // method parse

    /**
     * Set the value for specified key in specified section.
     */
    IniFile setValue(string sectionName, string key, string value) {
        auto section = getOrCreateSection(sectionName);
        section.setValue(key, value);
        return this;
    } // method setValue

    pure override string toString() const
    {
        auto result = new OutBuffer();
        auto first = true;
        foreach (section; sections)
        {
            if (!first)
                result.put("\n");
            result.put(section.toString());
            first = false;
        }
        return result.toString();
    } // method toString

} // class IniFile
