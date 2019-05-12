/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

//==================================================================

import std.algorithm: canFind;
import std.array;
import std.conv;
import std.encoding: transcode, Windows1251String;
import std.random: uniform;
import std.socket;
import std.stdio;
import std.string;
import std.outbuffer;

//==================================================================
//
// Constants
//

// Record status

const LOGICALLY_DELETED  = 1;  /// Logically deleted record.
const PHYSICALLY_DELETED = 2;  /// Physically deleted record.
const ABSENT             = 4;  /// Record is absent.
const NON_ACTUALIZED     = 8;  /// Record is not actualized.
const LAST_VERSION       = 32; /// Last version of the record.
const LOCKED_RECORD      = 64; /// Record is locked.

// Common formats

const ALL_FORMAT       = "&uf('+0')";  /// Full data by all the fields.
const BRIEF_FORMAT     = "@brief";     /// Short bibliographical description.
const IBIS_FORMAT      = "@ibiskw_h";  /// Old IBIS format.
const INFO_FORMAT      = "@info_w";    /// Informational format.
const OPTIMIZED_FORMAT = "@";          /// Optimized format.

// Common search prefixes

const KEYWORD_PREFIX    = "K=";  /// Keywords.
const AUTHOR_PREFIX     = "A=";  /// Individual author, editor, compiler.
const COLLECTIVE_PREFIX = "M=";  /// Collective author or event.
const TITLE_PREFIX      = "T=";  /// Title.
const INVENTORY_PREFIX  = "IN="; /// Inventory number, barcode or RFID tag.
const INDEX_PREFIX      = "I=";  /// Document index.

// Logical operators for search

const LOGIC_OR                = 0; /// OR only
const LOGIC_OR_AND            = 1; /// OR or AND
const LOGIC_OR_AND_NOT        = 2; /// OR, AND or NOT (default)
const LOGIC_OR_AND_NOT_FIELD  = 3; /// OR, AND, NOT, AND in field
const LOGIC_OR_AND_NOT_PHRASE = 4; /// OR, AND, NOT, AND in field, AND in phrase

// Workstation codes

const ADMINISTRATOR = "A"; /// Administator
const CATALOGER     = "C"; /// Cataloger
const ACQUSITIONS   = "M"; /// Acquisitions
const READER        = "R"; /// Reader
const CIRCULATION   = "B"; /// Circulation
const BOOKLAND      = "B"; /// Bookland
const PROVISION     = "K"; /// Provision

// Commands for global correction.

const ADD_FIELD        = "ADD";    /// Add field.
const DELETE_FIELD     = "DEL";    /// Delete field.
const REPLACE_FIELD    = "REP";    /// Replace field.
const CHANGE_FIELD     = "CHA";    /// Change field.
const CHANGE_WITH_CASE = "CHAC";   /// Change field with case sensitivity.
const DELETE_RECORD    = "DELR";   /// Delete record.
const UNDELETE_RECORD  = "UNDELR"; /// Recover (undelete) record.
const CORRECT_RECORD   = "CORREC"; /// Correct record.
const CREATE_RECORD    = "NEWMFN"; /// Create record.
const EMPTY_RECORD     = "EMPTY";  /// Empty record.
const UNDO_RECORD      = "UNDOR";  /// Revert to previous version.
const GBL_END          = "END";    /// Closing operator bracket.
const GBL_IF           = "IF";     /// Conditional statement start.
const GBL_FI           = "FI";     /// Conditional statement end.
const GBL_ALL          = "ALL";    /// All.
const GBL_REPEAT       = "REPEAT"; /// Repeat operator.
const GBL_UNTIL        = "UNTIL";  /// Until condition.
const PUTLOG           = "PUTLOG"; /// Save logs to file.

// Line delimiters

const IRBIS_DELIMITER = "\x1F\x1E"; /// IRBIS line delimiter.
const SHORT_DELIMITER = "\x1E";     /// Short version of line delimiter.
const ALT_DELIMITER   = "\x1F";     /// Alternative version of line delimiter.
const UNIX_DELIMITER  = "\n";       /// Standard UNIX line delimiter.

//==================================================================
//
// Utility functions
//

/// Converts the text to ANSI encoding.
ubyte[] toAnsi(string text)
{
    Windows1251String encoded;
    transcode(text, encoded);
    return cast(ubyte[])encoded;
}

/// Converts the slice of bytes from ANSI encoding to text.
string fromAnsi(ubyte[] text)
{
    Windows1251String s = cast(Windows1251String)text;
    string decoded;
    transcode(s, decoded);
    return decoded;
}

/// Converts the text to UTF-8 encoding.
ubyte[] toUtf(string text)
{
    return cast(ubyte[])text;
}

/// Converts the slice of bytes from UTF-8 encoding to text.
string fromUtf(ubyte[] text)
{
    return cast(string)text;
}

/// Examines whether the characters are the same.
pure bool sameChar(char c1, char c2)
{
    return toUpper(c1) == toUpper(c2);
}

/// Examines whether the strings are the same.
pure bool sameString(string s1, string s2)
{
    return icmp(s1, s2) == 0;
}

/// Convert text from IRBIS representation to UNIX.
string irbisToUnix(string text)
{
    return replace(text, IRBIS_DELIMITER, UNIX_DELIMITER);
}

/// Split text to lines by IRBIS delimiter
string[] irbisToLines(string text)
{
    return text.split(IRBIS_DELIMITER);
}

/// Fast parse integer number.
pure int parseInt(ubyte[] text)
{
    int result = 0;
    foreach(c; text)
        result = result * 10 + c - 32;
    return result;
}

/// Fast parse integer number.
pure int parseInt(string text)
{
    int result = 0;
    foreach(c; text)
        result = result * 10 + c - 48;
    return result;
}

/// Split the text by the delimiter to 2 parts.
pure string[] split2(string text, string delimiter)
{
    auto index = indexOf(text, delimiter);
    if (index < 0)
    {
        return [text];
    }

    return [to!string(text[0..index]), to!string(text[index + 1..$])];
}

/// Determines whether the string is null or empty.
pure bool isNullOrEmpty(string text)
{
    return (text is null) || (text.length == 0);
}

/// Pick first non-empty string from the array.
pure string pickOne(string[] strings ...)
{
    foreach(s; strings)
        if (!isNullOrEmpty(s))
            return s;

    throw new Exception("No strings!");
}

/// Remove comments from the format.
string removeComments(string text)
{
    if (isNullOrEmpty(text))
        return text;

    if (indexOf(text, "/*") < 0)
        return text;

    // TODO implement
    return text;
}

/// Prepare the format.
string prepareFormat(string text)
{
    text = removeComments(text);
    // TODO implement
    return text;
}

//==================================================================

/**
 * Subfield consist of a code and value.
 */
final class SubField
{
    char code; /// One-symbol code of the subfield.
    string value; /// String value of the subfield.

    /// Constructor.
    this()
    {
    } // constructor

    /// Constructor.
    this(char code, string value)
    {
        this.code = code;
        this.value = value;
    } // constructor

    /**
     * Deep clone of the subfield.
     */
    SubField clone() const
    {
        return new SubField(code, value);
    } // method clone

    /**
     * Decode the subfield from protocol representation.
     */
    void decode(string text)
    {
        code = text[0];
        value = text[1..$];
    } // method decode

    pure override string toString() const
    {
        return "^" ~ code ~ value;
    }

    /**
     * Verify the subfield.
     */
    pure bool verify() const
    {
        return (code != 0) && !isNullOrEmpty(value);
    }
} // class SubField

//==================================================================

/**
 * Field consist of a value and subfields.
 */
final class RecordField
{
    int tag; /// Numerical tag of the field.
    string value; /// String value of the field.
    SubField[] subfields; /// Subfields.

    /// Constructor.
    this(int tag=0, string value="")
    {
        this.tag = tag;
        this.value = value;
        this.subfields = new SubField[0];
    } // constructor

    /**
     * Append subfield with specified code and value.
     */
    RecordField add(char code, string value)
    {
        auto subfield = new SubField(code, value);
        subfields ~= subfield;
        return this;
    } // method add

    /**
     * Clear the field (remove the value and all the subfields).
     */
    RecordField clear()
    {
        value = "";
        subfields = [];
        return this;
    } // method clear

    /**
     * Clone the field.
     */
    RecordField clone() const
    {
        auto result = new RecordField(tag, value);
        foreach (subfield; subfields)
        {
            result.subfields ~= subfield.clone();
        }
        return result;
    } // method clone

    /**
     * Decode body of the field from protocol representation.
     */
    void decodeBody(string bodyText)
    {
        auto all = bodyText.split("^");
        if (bodyText[0] != '^')
        {
            value = all[0];
            all = all[1..$];
        }
        foreach(one; all)
        {
            if (one.length != 0)
            {
                auto subfield = new SubField();
                subfield.decode(one);
                subfields ~= subfield;
            }
        }
    } // method decodeBody

    /**
     * Decode the field from the protocol representation.
     */
    void decode(string text)
    {
        auto parts = split2(text, "#");
        tag = parseInt(parts[0]);
        decodeBody(parts[1]);
    } // method decode

    /**
     * Get slice of the embedded fields.
     */
    RecordField[] getEmbeddedFields()
    {
        // TODO implement
        return [];
    } // method getEmbeddedFields

    /**
     * Get first subfield with given code.
     */
    SubField getFirstSubField(char code)
    {
        foreach (subfield; subfields)
            if (sameChar(subfield.code, code))
                return subfield;
        return null;
    } // method getFirstSubfield

    /**
     * Get value of first subfield with given code.
     */
    string getFirstSubFieldValue(char code)
    {
        foreach (subfield; subfields)
            if (sameChar(subfield.code, code))
                return subfield.value;
        return null;
    } // method getFirstFieldValue

    /**
     * Insert the subfield at specified position.
     */
    RecordField insertAt(int index, SubField subfield)
    {
        // TODO implement
        return this;
    } // method insertAt

    /**
     * Remove subfield at specified position.
     */
    RecordField removeAt(int index)
    {
        // TODO implement
        return this;
    } // method removeAt

    /**
     * Remove all subfields with specified code.
     */
    RecordField removeSubField(char code)
    {
        // TODO implement
        return this;
    } // method removeSubField

    pure override string toString() const
    {
        auto result = new OutBuffer();
        result.put(to!string(tag));
        result.put("#");
        result.put(value);
        foreach(subfield; subfields)
        {
            result.put(subfield.toString());
        }
        return result.toString();
    } // method toString

    /**
     * Verify the field.
     */
    bool verify()
    {
        bool result = (tag != 0) && (!isNullOrEmpty(value) || (subfields.length != 0));
        if (result && (subfields.length != 0))
        {
            foreach (subfield; subfields)
            {
                result = subfield.verify();
                if (!result)
                    break;
            }
        }

        return result;
    } // method verify

} // class RecordField

//==================================================================

/**
 * Record consist of fields.
 */
final class MarcRecord
{
    string database; /// Database name
    int mfn; /// Masterfile number
    int versionNumber; /// Version number
    int status; /// Status
    RecordField[] fields; /// Slice of fields.

    /// Constructor.
    this()
    {
        fields = new RecordField[0];
    } // constructor

    /**
     * Add the field to back of the record.
     */
    RecordField add(int tag, string value="")
    {
        auto field = new RecordField(tag, value);
        fields ~= field;
        return field;
    } // method add

    /**
     * Add the field if it is non-empty.
     */
    MarcRecord addNonEmpty(int tag, string value)
    {
        if (!isNullOrEmpty(value))
            add(tag, value);
        return this;
    } // method addNonEmpty

    /**
     * Clear the record by removing all the fields.
     */
    MarcRecord clear()
    {
        fields = [];
        return this;
    } // method clear

    /**
     * Decode the record from the protocol representation.
     */
    void decode(string[] lines)
    {
        auto firstLine = split2(lines[0], "#");
        mfn = parseInt(firstLine[0]);
        status = parseInt(firstLine[1]);
        auto secondLine = split2(lines[1], "#");
        versionNumber = parseInt(secondLine[1]);
        foreach(line; lines[2..$])
        {
            if (line.length != 0)
            {
                auto field = new RecordField();
                field.decode(line);
                fields ~= field;
            }
        }
    } // method decode

    /**
     * Encode the record to the protocol representation.
     */
    pure string encode(string delimiter=IRBIS_DELIMITER) const
    {
        auto result = new OutBuffer();
        result.put(to!string(mfn));
        result.put("#");
        result.put(to!string(status));
        result.put(delimiter);
        result.put("0#");
        result.put(to!string(versionNumber));
        result.put(delimiter);
        foreach (field;fields)
        {
            result.put(field.toString());
            result.put(delimiter);
        }

        return result.toString();
    } // method encode

    /**
     * Get value of the field with given tag
     * (or subfield if code given).
     */
    pure string fm(int tag, char code=0) const
    {
        foreach (field; fields)
        {
            if (field.tag == tag)
            {
                if (code != 0)
                {
                    foreach (subfield; field.subfields)
                    {
                        if (sameChar(subfield.code, code))
                            if (!isNullOrEmpty(subfield.value))
                                return subfield.value;
                    }
                }
                else
                {
                    if (!isNullOrEmpty(field.value))
                        return field.value;
                }
            }
        }

        return null;
    } // method fm

    /**
     * Get slice of values of the fields with given tag
     * (or subfield values if code given).
     */
    pure string[] fma(int tag, char code=0)
    {
        string[] result;
        foreach (field; fields)
        {
            if (field.tag == tag)
            {
                if (code != 0)
                {
                    foreach (subfield; field.subfields)
                    {
                        if (sameChar (subfield.code, code))
                            if (!isNullOrEmpty(subfield.value))
                                result ~= subfield.value;
                    }
                }
                else
                {
                    if (!isNullOrEmpty(field.value))
                        result ~= field.value;
                }
            }
        }

        return result;
    }

    /**
     * Get field by tag and occurrence number.
     */
    pure RecordField getField(int tag, int occurrence=0)
    {
        foreach (field; fields)
        {
            if (field.tag == tag)
            {
                if (occurrence == 0)
                    return field;
                occurrence--;
            }
        }

        return null;
    } // method getField

    /**
     * Get slice of fields with given tag.
     */
    pure RecordField[] getFields(int tag)
    {
        RecordField[] result;
        foreach (field; fields)
        {
            if (field.tag == tag)
                result ~= field;
        }

        return result;
    } // method getFields

    /**
     * Insert the field at given index.
     */
    MarcRecord insertAt(int index, RecordField field)
    {
        // TODO implement
        return this;
    }

    /**
     * Determine whether the record is marked as deleted.
     */
    @property pure bool isDeleted() const
    {
        return (status & 3) != 0;
    } // method isDeleted

    /**
     * Remove field at specified index.
     */
    MarcRecord removeAt(int index)
    {
        // TODO implement
        return this;
    } // method removeAt

    pure override string toString() const
    {
        return encode("\n");
    } // method toString

} // class MarcRecord

//==================================================================

/**
 * Half-parsed record.
 */
final class RawRecord
{
    string database; /// Database name.
    int mfn; /// Masterfile number
    int versionNumber; /// Version number
    int status; /// Status.
    string[] fields; /// Slice of fields.

    /**
     * Decode the text representation.
     */
    bool decode(string[] lines)
    {
        if (lines.length < 3)
            return false;

        const firstLine = split2(lines[0], "#");
        if (firstLine.length != 2)
            return false;

        mfn = parseInt(firstLine[0]);
        status = parseInt(firstLine[1]);

        const secondLine = split2(lines[1], "#");
        if (secondLine.length != 2)
            return false;

        versionNumber = parseInt(secondLine[1]);
        fields = lines[2..$];

        return true;
    } // method decode

    /**
     * Encode to the text representation.
     */
    pure string encode(string delimiter = IRBIS_DELIMITER) const
    {
        auto result = new OutBuffer();
        result.put(to!string(mfn));
        result.put("#");
        result.put(to!string(status));
        result.put(delimiter);
        result.put("0#");
        result.put(to!int(versionNumber));
        result.put(delimiter);

        foreach (field; fields)
        {
            result.put(field);
            result.put(delimiter);
        }

        return result.toString();
    } // method encode

} // class RawRecord

//==================================================================

/**
 * Two lines in the MNU-file.
 */
final class MenuEntry
{
    string code; /// Code.
    string comment; /// Comment.

    /// Constructor.
    this()
    {
    }

    /// Constructor.
    this(string code, string comment)
    {
        this.code = code;
        this.comment = comment;
    }

    override string toString() const
    {
        return code ~ " - " ~ comment;
    }
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
    MenuFile add(string code, string comment)
    {
        auto entry = new MenuEntry(code, comment);
        entries ~= entry;
        return this;
    }

    /**
     * Clear the menu.
     */
    MenuFile clear()
    {
        entries = [];
        return this;
    }

    /**
     * Get entry.
     */
    MenuEntry getEntry(string code)
    {
        if (entries.length == 0)
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
    }

    /**
     * Get value.
     */
    string getValue(string code, string defaultValue="")
    {
        auto entry = getEntry(code);
        if (entry is null)
            return defaultValue;
        return entry.comment;
    }

    /**
     * Parse text representation.
     */
    void parse(string[] lines)
    {
        for(int i=0; i < lines.length; i += 2)
        {
            auto code = lines[i];
            if (code.length == 0 || code.startsWith("*****"))
                break;
            auto comment = lines[i+1];
            auto entry = new MenuEntry(code, comment);
            entries ~= entry;
        }
    }

    override string toString() const
    {
        auto result = new OutBuffer();
        foreach(entry; entries)
        {
            result.put(entry.toString());
            result.put("\n");
        }
        result.put("*****");

        return result.toString();
    }
} // class MenuFile

//==================================================================

/**
 * Line of INI-file. Consist of a key and value.
 */
final class IniLine
{
    string key; /// Key string.
    string value; /// Value string

    pure override string toString() const
    {
        return this.key ~ "=" ~ this.value;
    }
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
    pure string getValue(string key, string defaultValue="")
    {
        auto found = find(key);
        return (found is null) ? defaultValue : found.value;
    }

    /**
     * Remove line with specified key.
     */
    void remove(string key)
    {
        // TODO implement
    }

    /**
     * Set the value for specified key.
     */
    IniSection setValue(string key, string value)
    {
        if (value is null)
        {
            remove(key);
        }
        else
        {
            auto item = find(key);
            if (item is null)
            {
                item = new IniLine();
                lines ~= item;
                item.key = key;
            }
            item.value = value;
        }

        return this;
    }

    pure override string toString() const
    {
        auto result = new OutBuffer();
        if (!isNullOrEmpty(name))
        {
            result.put("[");
            result.put(name);
            result.put("]");
        }
        foreach (line; lines)
        {
            result.put(line.toString());
            result.put("\n");
        }
        return result.toString();
    }
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
    void parse(string[] lines)
    {
        IniSection section = null;
        foreach (line; lines) {
            auto trimmed = strip(line);
            if (isNullOrEmpty(line))
                continue;

            if (trimmed[0] == '[')
            {
                auto name = trimmed[1..$-1];
                section = getOrCreateSection(name);
            }
            else if (!(section is null))
            {
                auto parts = split2(trimmed, "=");
                if (parts.length != 2)
                    continue;
                auto key = strip(parts[0]);
                if (isNullOrEmpty(key))
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
    IniFile setValue(string sectionName, string key, string value)
    {
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

//==================================================================

/**
 * Node of TRE-file.
 */
final class TreeNode
{
    TreeNode[] children; /// Slice of children.
    string value; /// Value of the node.
    int level; /// Level of the node.

    /**
     * Constructor.
     */
    this(string value="")
    {
        this.value = value;
    } // constructor

    /**
     * Add child node with specified value.
     */
    TreeNode add(string value)
    {
        auto child = new TreeNode(value);
        child.level = this.level + 1;
        children ~= child;
        return this;
    } // method add

    pure override string toString() const
    {
        return value;
    } // method toString

} // class TreeNode

//==================================================================

/**
 * TRE-file.
 */
final class TreeFile
{
    TreeNode[] roots; /// Slice of root nodes.

    private static void arrange1(TreeNode[] list, int level)
    {
        int count = cast(int)list.length;
        auto index = 0;
        while (index < count)
        {
            const next = arrange2(list, level, index, count);
            index = next;
        }
    } // method arrange1

    private static int arrange2(TreeNode[] list, int level, int index, int count)
    {
        int next = index + 1;
        const level2 = level + 1;
        auto parent = list[index];
        while (next < count)
        {
            auto child = list[next];
            if (child.level < level)
                break;
            if (child.level == level2)
                parent.children ~= child;
            next++;
        }

        return next;
    } // method arrange2

    private static int countIndent(string text)
    {
        auto result = 0;
        const length = text.length;
        for (int i = 0; i < length; i++)
            if (text[i] == '\t')
                result++;
            else
                break;
        return result;
    } // method countIndent

    /**
     * Add root node.
     */
    TreeFile addRoot(string value)
    {
        auto root = new TreeNode(value);
        roots ~= root;
        return this;
    } // method addRoot

    /**
     * Parse the text representation.
     */
    void parse(string[] lines)
    {
        if (lines.length == 0)
            return;

        TreeNode[] list = [];
        int currentLevel = 0;
        auto firstLine = lines[0];
        if (isNullOrEmpty(firstLine) || (countIndent(firstLine) != 0))
            throw new Exception("Wrong TRE");

        list ~= new TreeNode(firstLine);
        foreach (line; lines)
        {
            if (isNullOrEmpty(line))
                continue;

            auto level = countIndent(line);
            if (level > (currentLevel + 1))
                throw new Exception("Wrong TRE");
            
            currentLevel = level;
            auto node = new TreeNode(line[level..$]);
            node.level = level;
            list ~= node;
        } // foreach

        int maxLevel = 0;
        foreach (item; list)
            if (item.level > maxLevel)
                maxLevel = item.level;
        
        for (int level = 0; level < maxLevel; level++)
            arrange1(list, level);

        foreach (item; list)
            if (item.level == 0)
                roots ~= item;
    } // method parse

} // class TreeFile

//==================================================================

/**
 * Information about IRBIS database.
 */
final class DatabaseInfo
{
    string name; /// Database name
    string description; /// Description
    int maxMfn; /// Maximal MFN
    int[] logicallyDeletedRecords; /// Logically deleted records.
    int[] physicallyDeletedRecords; /// Physically deleted records.
    int[] nonActualizedRecords; /// Non-actualized records.
    int[] lockedRecords; /// Locked records.
    bool databaseLocked; /// Whether the database is locked.
    bool readOnly; /// Whether the database is read-only.

    /**
     * Parse the menu.
     */
    static DatabaseInfo[] parseMenu(const MenuFile menu)
    {
        DatabaseInfo[] result;

        foreach(entry; menu.entries)
        {
            string entryName = entry.code;
            if ((entryName.length == 0) || entryName.startsWith("*****"))
                break;
            auto description = entry.comment;
            auto readOnly = false;
            if (entryName[0] == '-')
            {
                entryName = entryName[1..$];
                readOnly = true;
            }

            auto db = new DatabaseInfo();
            db.name = entryName;
            db.description = description;
            db.readOnly = readOnly;
            result ~= db;
        } // foreach

        return result;
    } // method parseMenu

    override string toString() const
    {
        return name;
    }
} // class DatabaseInfo

//==================================================================

/**
 * Information about the IRBIS64 server version.
 */
final class VersionInfo
{
    string organization; /// License owner organization.
    string serverVersion; /// Server version itself. Example: 64.2008.1
    int maxClients; /// Maximum simultaneous connected client number.
    int connectedClients; /// Current connected clients number.

    /// Constructor.
    this()
    {
        organization = "";
        serverVersion = "";
        maxClients = 0;
        connectedClients = 0;
    }

    /**
     * Parse the server response.
     */
    void parse(string[] lines) {
        if (lines.length == 3)
        {
            serverVersion = lines[0];
            connectedClients = to!int(lines[1]);
            maxClients = to!int(lines[2]);
        }
        else
        {
            organization = lines[0];
            serverVersion = lines[1];
            connectedClients = to!int(lines[2]);
            maxClients = to!int(lines[3]);
        }
    } // method parse
} // class VersionInfo

//==================================================================

/**
 * Parameters for search method.
 */
final class SearchParameters
{
    string database; /// Database name.
    int firstRecord = 1; /// First record number.
    string format; /// Format specification.
    int maxMfn; /// Maximal MFN.
    int minMfn; /// Minimal MFN.
    int numberOfRecords; /// Number of records required. 0 = all.
    string expression; /// Search expression.
    string sequential; /// Sequential search expression.
    string filter; /// Additional filter.
} // class SearchParameters

//==================================================================

/**
 * Information about found record.
 * Used in search method.
 */
struct FoundLine
{
    int mfn; /// Record MFN.
    string description; /// Description (optional).

    /**
     * Parse one text line.
     */
    void parse(string text)
    {
        auto parts = split2(text, "#");
        mfn = parseInt(parts[0]);
        if (parts.length > 1)
            description = parts[1];
    }

    /**
     * Parse server response for descriptions.
     */
    static string[] parseDesciptions(string[] lines)
    {
        string[] result;
        reserve(result, lines.length);
        foreach(line; lines)
        {
            if (line.length != 0)
            {
                auto index = indexOf(line, '#');
                if (index >= 0)
                {
                    auto description = to!string(line[index+1..$]);
                    result ~= description;
                }
            }
        }

        return result;
    } // method parseDescriptions

    /**
     * Parse the server response for all the information.
     */
    static FoundLine[] parseFull(string[] lines)
    {
        FoundLine[] result;
        reserve(result, lines.length);
        foreach(line; lines)
        {
            if (line.length != 0)
            {
                FoundLine item;
                item.parse(line);
                result ~= item;
            }
        }

        return result;
    } // method parseFull

    /**
     * Parse the server response for MFN only.
     */
    static int[] parseMfn(string[] lines)
    {
        int[] result;
        reserve(result, lines.length);
        foreach(line; lines)
        {
            if (line.length != 0)
            {
                auto item = parseInt(line);
                result ~= item;
            }
        }

        return result;
    } // method parseMfn

} // class FoundLine

//==================================================================

/**
 * Search term info.
 */
struct TermInfo
{
    int count; /// link count
    string text; /// search term text

    /**
     * Parse the server response for terms.
     */
    static TermInfo[] parse(string[] lines)
    {
        TermInfo[] result;
        foreach(line; lines)
        {
            if (line.length != 0)
            {
                auto parts = split2(line, "#");
                if (parts.length == 2)
                {
                    TermInfo item;
                    item.count = parseInt(parts[0]);
                    item.text = parts[1];
                    result ~= item;
                }
            }
        }

        return result;
    } // method parse

    pure string toString() const
    {
        return format("%d#%s", count, text);
    } // method toString

} // class TermInfo

//==================================================================

/**
 * Term posting info.
 */
struct TermPosting
{
    int mfn; /// Record MFN.
    int tag; /// Field tag.
    int occurrence; /// Field occurrence.
    int count; /// Term count.
    string text; /// Text value.

    /**
     * Parse the server response.
     */
    static TermInfo[] parse(string[] lines)
    {
        TermInfo[] result;
        foreach(line; lines)
        {
            if (line.length != 0)
            {
                // TODO implement
            }
        }

        return result;
    } // method parse

    pure string toString() const
    {
        return to!string(mfn) ~ "#"
            ~ to!string(tag) ~ "#"
            ~ to!string(occurrence) ~ "#"
            ~ to!string(count) ~ "#"
            ~ text;
    }
} // class TermPosting

//==================================================================

/**
 * Parameters for readTerms method.
 */
final class TermParameters
{
    string database; /// Database name.
    int numberOfTerms; /// Number of terms to read.
    bool reverseOrder; /// Return terms in reverse order?
    string startTerm; /// Start term.
    string format; /// Format specification (optional).
} // class TermParameters

//==================================================================

/**
 * Data for printTable method.
 */
final class TableDefinition
{
    string database; /// Database name.
    string table; /// Table file name.
    string[] headers; /// Table headers.
    string mode; /// Table mode.
    string searchQuery; /// Search query.
    int minMfn; /// Minimal MFN.
    int maxMfn; /// Maximal MFN.
    string sequentialQuery; /// Query for sequential search.
    int[] mfnList; /// Lisf of MFNs to use.

    pure override string toString() const
    {
        return table;
    }
} // class TableDefinition

//==================================================================

/**
 * Information about connected client
 * (not necessarily current client).
 */
final class ClientInfo
{
    string number; /// Sequential number.
    string ipAddress; /// Clien IP address.
    string port; /// Port number.
    string name; /// User login.
    string id; /// Client identifier (just unique number).
    string workstation; /// Client software kind.
    string registered; /// Registration moment.
    string acknowledged; /// Last acknowledge moment.
    string lastCommand; /// Last command issued.
    string commandNumber; /// Last command number.

    /**
     * Parse the server response.
     */
    void parse(string[] lines)
    {
        number = lines[0];
        ipAddress = lines[1];
        port = lines[2];
        name = lines[3];
        id = lines[4];
        workstation = lines[5];
        registered = lines[6];
        acknowledged = lines[7];
        lastCommand = lines[8];
        commandNumber = lines[9];
    } // method parse

    pure override string toString() const
    {
        return ipAddress;
    } // method toString
}

//==================================================================

/**
 * IRBIS64 server working statistics.
 */
final class ServerStat
{
    ClientInfo[] runningClients; /// Slice of running clients.
    int clientCount; /// Actual client count.
    int totalCommandCount; /// Total command count.

    /**
     * Parse the server response.
     */
    void parse(string[] lines)
    {
        totalCommandCount = parseInt(lines[0]);
        clientCount = parseInt(lines[1]);
        auto linesPerClient = parseInt(lines[2]);
        lines = lines[3..$];
        for(int i = 0; i < clientCount; i++)
        {
            auto client = new ClientInfo();
            client.parse(lines);
            runningClients ~= client;
            lines = lines[linesPerClient + 1..$];
        } // for
    } // method parse

    pure override string toString() const
    {
        auto result = new OutBuffer();
        result.put(to!string(totalCommandCount));
        result.put("\n");
        result.put(to!string(clientCount));
        result.put("\n8\n");
        foreach(client; runningClients) 
        {
            result.put(client.toString());
            result.put("\n");
        }
        return result.toString();
    } // method toString

} // class ServerStat

//==================================================================

/**
 * Client query encoder.
 */
final class ClientQuery
{
    private OutBuffer _buffer;

    /// Constructor.
    this(Connection connection, string command)
    {
        _buffer = new OutBuffer();
        addAnsi(command).newLine();
        addAnsi(connection.workstation).newLine();
        addAnsi(command).newLine();
        add(connection.clientId).newLine();
        add(connection.queryId).newLine();
        addAnsi(connection.password).newLine();
        addAnsi(connection.username).newLine();
        newLine();
        newLine();
        newLine();
    } // this

    /// Add integer value.
    ClientQuery add(int value)
    {
        auto text = to!string(value);
        return addUtf(text);
    } // method add

    /// Add boolean value.
    ClientQuery add(bool value)
    {
        auto text = value ? "1" : "0";
        return addUtf(text);
    } // method add

    /// Add text in ANSI encoding.
    ClientQuery addAnsi(string text)
    {
        auto bytes = toAnsi(text);
        _buffer.write(bytes);
        return this;
    } // method addAnsi

    /// Add format specification
    bool addFormat(string text)
    {
        const stripped = strip(text);

        if (stripped.length == 0)
        {
            newLine();
            return false;
        }

        auto prepared = prepareFormat(text);
        if (prepared[0] == '@')
        {
            addAnsi(prepared);
        }
        else if (prepared[0] == '!')
        {
            addUtf(prepared);
        }
        else
        {
            addUtf("!");
            addUtf(prepared);
        }
        newLine();

        return true;
    } // method addFormat

    /// Add text in UTF-8 encoding.
    ClientQuery addUtf(string text)
    {
        auto bytes = toUtf(text);
        _buffer.write(bytes);
        return this;
    } // method addUtf

    /// Encode the query.
    ubyte[] encode() const
    {
        auto bytes = _buffer.toBytes();
        auto result = new OutBuffer();
        result.printf("%d\n", bytes.length);
        result.write(bytes);
        return result.toBytes();
    } // method encode

    /// Add line delimiter symbol.
    ClientQuery newLine()
    {
        _buffer.write(cast(byte)10);
        return this;
    } // method newLine

} // class ClientQuery

//==================================================================

/**
 * Server response decoder.
 */
final class ServerResponse
{
    private bool _ok;
    private ubyte[] _buffer;
    private ptrdiff_t _offset;

    Connection connection; /// connection used

    string command; /// Command code.
    int clientId; /// Client id.
    int queryId; /// Query id.
    int answerSize; /// Answer size.
    int returnCode; /// Return code.
    string serverVersion; /// Server version.
    int interval; /// Auto-ack interval.

    /// Constructor.
    this(ubyte[] buffer)
    {
        _ok = buffer.length != 0;
        _buffer = buffer;
        _offset=0;

        command = readAnsi();
        clientId = readInteger();
        queryId = readInteger();
        answerSize = readInteger();
        serverVersion = readAnsi();
        interval = readInteger();
        readAnsi();
        readAnsi();
        readAnsi();
        readAnsi();
    } // this

    /// Whether all data received?
    @property pure bool ok() const nothrow
    {
        return _ok;
    }

    /// Whether end of response reached?
    @property pure bool eof() const nothrow
    {
        return _offset >= _buffer.length;
    }

    /// Check return code.
    bool checkReturnCode(int[] allowed ...)
    {
        if (getReturnCode() < 0)
            return canFind(allowed, returnCode);
        return true;
    }

    /// Get raw line (no encoding applied).
    ubyte[] getLine()
    {
        auto result = new OutBuffer();

        while (_offset < _buffer.length)
        {
            auto symbol = _buffer[_offset++];
            if (symbol == 13)
            {
                if (_buffer[_offset] == 10)
                {
                    _offset++;
                }
                break;
            }
            result.write(symbol);
        }

        return result.toBytes();
    } // method getLine

    /// Get return code.
    int getReturnCode()
    {
        returnCode = readInteger();
        connection.lastError = returnCode;
        return returnCode;
    }

    /// Read line in ANSI encoding.
    string readAnsi()
    {
        return fromAnsi(getLine());
    } // method readAnsi

    /// Read integer value
    int readInteger()
    {
        auto line = readUtf();
        auto result = 0;
        if (line.length != 0)
        {
            result = to!int(line);
        }
        return result;
    } // method readInteger

    /// Read remaining lines in ANSI encoding.
    string[] readRemainingAnsiLines()
    {
        string[] result = new string[0];
        while (!eof)
        {
            auto line = readAnsi();
            result ~= line;
        }
        return result;
    } // method readRemainingAnsiLines

    /// Read remaining text in ANSI encoding.
    string readRemainingAnsiText()
    {
        auto chunk = _buffer[_offset..$];
        return fromAnsi(chunk);
    } // method readRemainingAnsiText

    /// Read remaining lines in UTF-8 encoding.
    string[] readRemainingUtfLines()
    {
        string[] result = new string[0];
        while (!eof)
        {
            auto line = readUtf();
            result ~= line;
        }
        return result;
    } // method readRemainingUtfLines

    /// Read remaining text in UTF-8 encoding.
    string readRemainingUtfText()
    {
        auto chunk = _buffer[_offset..$];
        return fromUtf(chunk);
    } // method readRemainingUtfText

    /// Read line in UTF-8 encoding.
    string readUtf()
    {
        return fromUtf(getLine());
    } // method readUtf

} // class ServerResponse

//==================================================================

/**
 * Abstract client socket.
 */
class ClientSocket
{
    /**
     * Talk to server and get response.
     */
    abstract ServerResponse talkToServer(const ClientQuery query);
} // class ClientSocket

//==================================================================

/**
 * Client socket implementation for TCP/IP v4.
 */
final class Tcp4ClientSocket : ClientSocket
{
    private Connection _connection;

    /// Constructor.
    this(Connection connection)
    {
        _connection = connection;
    }

    override ServerResponse talkToServer(const ClientQuery query)
    {
        auto socket = new Socket(AddressFamily.INET, SocketType.STREAM);
        auto address = new InternetAddress(_connection.host, _connection.port);
        socket.connect(address);
        scope(exit) socket.close();
        auto outgoing = query.encode();
        socket.send(outgoing);

        ptrdiff_t amountRead;
        auto incoming = new OutBuffer();
        incoming.reserve(2048);
        auto buffer = new ubyte[2056];
        while((amountRead = socket.receive(buffer)) != 0)
        {
            incoming.write(buffer[0..amountRead]);
        }

        auto result = new ServerResponse(incoming.toBytes());

        return result;
    } // method talkToServer

} // class Tcp4ClientSocket

//==================================================================

/**
 * IRBIS-sever connection.
 */
final class Connection
{
    private bool _connected;

    string host; /// Host name or address.
    ushort port; /// Port number.
    string username; /// User login.
    string password; /// User password.
    string database; /// Current database name.
    string workstation; /// Workstation code.
    int clientId; /// Unique client identifier.
    int queryId; /// Sequential query number.
    string serverVersion; /// Server version.
    int interval; /// Auto-ack interval.
    IniFile ini; /// INI-file.
    ClientSocket socket; /// Socket.
    int lastError; /// Last error code.

    /// Constructor.
    this()
    {
        host = "127.0.0.1";
        port = 6666;
        database = "IBIS";
        workstation = CATALOGER;
        socket = new Tcp4ClientSocket(this);
        _connected = false;
    }

    ~this()
    {
        disconnect();
    }

    /**
     * Actualize all the non-actualized records in the database.
     */
    bool actualizeDatabase(string database)
    {
        return actualizeRecord(database, 0);
    } // method actualizeDatabase

    /**
     * Actualize the record with the given MFN.
     */
    bool actualizeRecord(string database, int mfn)
    {
        if (!connected)
            return false;

        auto query = new ClientQuery (this, "F");
        query.addAnsi(database).newLine();
        query.add(mfn).newLine();
        auto response = execute(query);
        return response.ok && response.checkReturnCode();
    } // method actualizeRecord

    /**
     * Establish the server connection.
     */
    bool connect()
    {
        if (connected)
            return true;

        AGAIN: queryId = 1;
        clientId = uniform(100_000, 999_999);
        auto query = new ClientQuery(this, "A");
        query.addAnsi(username).newLine();
        query.addAnsi(password);
        auto response = execute(query);
        if (!response.ok)
            return false;

        response.getReturnCode();
        if (response.returnCode == -3337)
            goto AGAIN;

        if (response.returnCode < 0)
            return false;

        _connected = true;
        serverVersion = response.serverVersion;
        interval = response.interval;
        auto lines = response.readRemainingAnsiLines();
        ini = new IniFile();
        ini.parse(lines);
        return true;
    } // method connect

    /// Whether the client is connected to the server?
    @property pure bool connected() const nothrow
    {
        return _connected;
    }

    /**
     * Create the server database.
     */
    bool createDatabase(string database, string description, bool readerAccess=true)
    {
        if (!connected)
            return false;

        auto query = new ClientQuery(this, "T");
        query.addAnsi(database).newLine();
        query.addAnsi(description).newLine();
        query.add(cast(int)readerAccess).newLine();
        auto response = execute(query);
        return response.ok && response.checkReturnCode();
    } // method createDatabase

    /**
     * Create the dictionary for the database.
     */
    bool createDictionary(string database)
    {
        if (!connected)
            return false;

        auto query = new ClientQuery(this, "Z");
        query.addAnsi(database).newLine();
        auto response = execute(query);
        return response.ok && response.checkReturnCode();
    } // method createDictionary

    /**
     * Delete the database on the server.
     */
    bool deleteDatabase(string database)
    {
        if (!connected)
            return false;

        auto query = new ClientQuery(this, "W");
        query.addAnsi(database).newLine();
        auto response = execute(query);
        return response.ok && response.checkReturnCode();
    } // method deleteDatabase

    /**
     * Disconnect from the server.
     */
    bool disconnect()
    {
        if (!connected)
            return true;

        auto query = new ClientQuery(this, "B");
        query.addAnsi(username);
        execute(query);
        _connected = false;
        return true;
    } // method disconnect

    /**
     * Execute the query.
     */
    ServerResponse execute(const ClientQuery query)
    {
        lastError = 0;
        ServerResponse result;
        try
        {
            result = socket.talkToServer(query);
            result.connection = this;
            queryId++;
        }
        catch (Exception ex)
        {
            lastError = -100_000;
            result = new ServerResponse([]);
        }

        return result;
    } // method execute

    /**
     * Format the record by MFN.
     */
    string formatRecord(string text, int mfn)
    {
        if (!connected)
            return "";

        auto query = new ClientQuery(this, "G");
        query.addAnsi(database).newLine();
        if (!query.addFormat(text))
            return "";

        query.add(1).newLine();
        query.add(mfn).newLine();
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode())
            return "";

        auto result = response.readRemainingUtfText();
        result = strip(result);

        return result;
    } // method formatRecord

    /**
     * Format virtual record.
     */
    string formatRecord(string format, const MarcRecord record)
    {
        if (!connected || isNullOrEmpty(format) || (record is null))
            return "";

        auto db = pickOne(record.database, this.database);
        auto query = new ClientQuery(this, "G");
        query.addAnsi(db).newLine();
        query.addFormat(format);
        query.add(-2).newLine();
        query.addUtf(record.encode(IRBIS_DELIMITER));
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode())
            return "";

        auto result = response.readRemainingUtfText();
        result = stripRight(result);
        return result;
    }

    /**
     * Get the maximal MFN for the database.
     */
    int getMaxMfn(string databaseName = "")
    {
        if (!connected)
            return 0;

        auto db = pickOne(databaseName, this.database);
        auto query = new ClientQuery(this, "O");
        query.addAnsi(db);
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode())
            return 0;

        return response.returnCode;
    } // method getMaxMfn

    /**
     * Get server running statistics.
     */
    ServerStat getServerStat()
    {
        auto result = new ServerStat();
        if (!connected)
            return result;

        auto query = new ClientQuery(this, "+1");
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode())
            return result;

        auto lines = response.readRemainingAnsiLines();
        result.parse(lines);
        return result;
    } // method getServerStat

    /**
     * Get the server version.
     */
    VersionInfo getServerVersion()
    {
        auto result = new VersionInfo();

        if (connected)
        {
            auto query = new ClientQuery(this, "1");
            auto response = execute(query);
            if (response.ok && response.checkReturnCode())
            {
                auto lines = response.readRemainingAnsiLines();
                result.parse(lines);
            }
        }

        return result;
    } // method getServerVersion

    /**
     * List server databases.
     */
    DatabaseInfo[] listDatabases(string specification = "1..dbnam2.mnu")
    {
        DatabaseInfo[] result;

        if (!connected)
            return result;

        auto menu = readMenuFile(specification);
        if (menu is null)
            return result;

        result = DatabaseInfo.parseMenu(menu);
        return result;
    } // method listDatabase

    /**
     * List server files by specification.
     */
    string[] listFiles(string[] specifications ...)
    {
        string[] result;
        if (!connected)
            return result;

        if (specifications.length == 0)
            return result;

        auto query = new ClientQuery(this, "!");
        foreach (spec; specifications)
            query.addAnsi(spec).newLine();
        auto response = execute(query);
        if (!response.ok)
            return result;

        auto lines = response.readRemainingAnsiLines();
        foreach (line; lines)
        {
            auto files = irbisToLines(line);
            foreach (file; files)
            {
                if (file.length != 0)
                    result ~= file;
            }
        }

        return result;
    } // method listFiles

     /**
      * Empty operation. Confirms the client is alive.
      */
    bool noOp()
    {
        if (!connected)
            return false;

        auto query = new ClientQuery(this, "N");
        return execute(query).ok;
    } // method noOp

    /**
     * Parse the connection string.
     */
    void parseConnectionString(string connectionString)
    {
        auto items = split(connectionString, ";");
        foreach(item; items)
        {
            if (item.length == 0)
                continue;

            auto parts = split2(item, "=");
            if (parts.length != 2)
                continue;

            const name = toLower(strip(parts[0]));
            auto value = strip(parts[1]);

            switch(name)
            {
                case "host", "server", "address":
                    host = value;
                    break;

                case "port":
                    port = to!ushort(value);
                    break;

                case "user", "username", "name", "login":
                    username = value;
                    break;

                case "pwd", "password":
                    password = value;
                    break;

                case "db", "database", "catalog":
                    database = value;
                    break;

                case "arm", "workstation":
                    workstation = value;
                    break;

                default:
                    throw new Exception("Unknown key");
            }
        }
    } // method parseConnectionString

    /**
     * Read the MNU-file from the server.
     */
    MenuFile readMenuFile(string specification)
    {
        if (!connected)
            return null;

        auto lines = readTextLines(specification);
        if (lines.length == 0)
            return null;

        auto result = new MenuFile();
        result.parse(lines);
        return result;
    } // method readMenuFile

    /**
     * Read and half-decode the record.
     */
    RawRecord readRawRecord(int mfn, int versionNumber=0)
    {
        if (!connected)
            return null;

        auto query = new ClientQuery(this, "C");
        query.addAnsi(database).newLine();
        query.add(mfn).newLine();
        query.add(versionNumber).newLine();

        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode(-201, -600, -602, -603))
            return null;

        auto result = new RawRecord();
        auto lines = response.readRemainingUtfLines();
        result.decode(lines);
        result.database = database;

        if (versionNumber != 0)
            unlockRecords(database, [mfn]);

        return result;
    } // method readRawRecord

    /**
     * Read the record from the server by MFN.
     */
    MarcRecord readRecord(int mfn, int versionNumber=0)
    {
        if (!connected)
            return null;

        auto query = new ClientQuery(this, "C");
        query.addAnsi(database).newLine();
        query.add(mfn).newLine();
        query.add(versionNumber).newLine();
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode(-201, -600, -602, -603))
            return null;

        auto result = new MarcRecord();
        auto lines = response.readRemainingUtfLines();
        result.decode(lines);
        result.database = database;

        if (versionNumber != 0)
            unlockRecords(database, [mfn]);

        return result;
    } // method readRecord

    /**
     * Read some records.
     */
    MarcRecord[] readRecords(int[] mfnList)
    {
        MarcRecord[] result;

        if (!connected || (mfnList.length == 0))
            return result;

        if (mfnList.length == 1)
        {
            auto record = readRecord(mfnList[0]);
            if (record !is null)
                result ~= record;
        }
        else 
        {
            auto query = new ClientQuery(this, "G");
            query.addAnsi(database).newLine();
            query.addAnsi(ALL_FORMAT).newLine();
            query.add(cast(int)mfnList.length).newLine();
            foreach(mfn; mfnList)
                query.add(mfn).newLine();

            auto response = execute(query);
            if (!response.ok || !response.checkReturnCode())
                return result;

            auto lines = response.readRemainingUtfLines();
            foreach(line; lines) 
                if (!isNullOrEmpty(line))
                {
                    auto parts = split2(line, "#");
                    parts = split(parts[1], ALT_DELIMITER);
                    parts = parts[1..$];
                    auto record = new MarcRecord();
                    record.decode(parts);
                    record.database = database;
                    result ~= record;
                }
        }

        return result;
    } // method readRecords

    /**
     * Read terms from the inverted file.
     */
    TermInfo[] readTerms(string startTerm, int number)
    {
        auto parameters = new TermParameters();
        parameters.startTerm = startTerm;
        parameters.numberOfTerms = number;
        return readTerms(parameters);
    } // method readTerms

    /**
     * Read terms from the inverted file.
     */
    TermInfo[] readTerms(const TermParameters parameters)
    {
        if (!connected)
            return [];

        auto command = parameters.reverseOrder ? "P" : "H";
        auto db = pickOne(parameters.database, this.database);
        auto query = new ClientQuery(this, command);
        query.addAnsi(db).newLine();
        query.addUtf(parameters.startTerm).newLine();
        query.add(parameters.numberOfTerms).newLine();
        auto prepared = prepareFormat(parameters.format);
        query.addAnsi(prepared).newLine();
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode(-202, -203, -204))
            return [];

        auto lines = response.readRemainingUtfLines();
        auto result = TermInfo.parse(lines);
        return result;
    } // method readTerms

    /**
     * Read the text file from the server.
     */
    string readTextFile(string specification)
    {
        if (!connected)
            return "";

        auto query = new ClientQuery(this, "L");
        query.addAnsi(specification).newLine();
        auto response = execute(query);
        if (!response.ok)
            return "";

        auto result = response.readAnsi();
        result = irbisToUnix(result);
        return result;
    } // method readTextFile

    /**
    * Read the text file from the server as the array of lines.
    */
    string[] readTextLines(string specification)
    {
        if (!connected || isNullOrEmpty(specification))
            return [];

        auto query = new ClientQuery(this, "L");
        query.addAnsi(specification).newLine();
        auto response = execute(query);
        if (!response.ok)
            return [];

        auto content = response.readAnsi();
        auto result = irbisToLines(content);
        return result;
    } // method readTextLines

    /**
     * Read TRE-file from the server.
     */
    TreeFile readTreeFile(string specification)
    {
        auto lines = readTextLines(specification);
        if (lines.length == 0)
            return null;

        auto result = new TreeFile();
        result.parse(lines);
        return result;
    }

    /**
    * Recreate dictionary for the database.
    */
    bool reloadDictionary(string database)
    {
        if (!connected)
            return false;

        auto query = new ClientQuery(this, "Y");
        query.addAnsi(database).newLine();
        return execute(query).ok;
    } // method reloadDictionary

    /**
     * Recreate master file for the database.
     */
    bool reloadMasterFile(string database)
    {
        if (!connected)
            return false;

        auto query = new ClientQuery(this, "X");
        query.addAnsi(database).newLine();
        return execute(query).ok;
    } // method reloadMasterFile

    /**
     * Restarting the server (without losing the connected clients).
     */
    bool restartServer()
    {
        if (!connected)
            return false;

        auto query = new ClientQuery(this, "+8");
        return execute(query).ok;
    } // method restartServer

    /**
     * Simple search for records (no more than 32k records).
     */
    int[] search(string expression)
    {
        if (!connected)
            return [];

        if (expression.length == 0)
            return [];

        auto query = new ClientQuery(this, "K");
        query.addAnsi(database).newLine();
        query.addUtf(expression).newLine();
        query.add(0).newLine();
        query.add(1).newLine();
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode())
            return [];

        response.readInteger(); // count of found records
        auto lines = response.readRemainingUtfLines();
        auto result = FoundLine.parseMfn(lines);
        return result;
    } // method search

    /**
     * Extended search for records (no more than 32k records).
     */
    FoundLine[] search(const SearchParameters parameters)
    {
        if (!connected)
            return [];

        auto db = pickOne(parameters.database, this.database);
        auto query = new ClientQuery(this, "K");
        query.addAnsi(db).newLine();
        query.addUtf(parameters.expression).newLine();
        query.add(parameters.numberOfRecords).newLine();
        query.add(parameters.firstRecord).newLine();
        query.addFormat(parameters.format);
        query.add(parameters.minMfn).newLine();
        query.add(parameters.maxMfn).newLine();
        query.addAnsi(parameters.sequential).newLine();
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode())
            return [];

        response.readInteger(); // count of found records
        auto lines = response.readRemainingUtfLines();
        auto result = FoundLine.parseFull(lines);
        return result;
    } // method search

    /**
     * Search all the records (even if more than 32k records).
     */
    int[] searchAll(string expression)
    {
        int[] result = [];
        if (!connected)
            return result;

        auto firstRecord = 1;
        auto totalCount = 0;
        while (true)
        {
            auto query = new ClientQuery(this, "K");
            query.addAnsi(database).newLine();
            query.addUtf(expression).newLine();
            query.add(0).newLine();
            query.add(firstRecord).newLine();
            auto response = execute(query);
            if (!response.ok || !response.checkReturnCode())
                return result;
            if (firstRecord == 1)
            {
                totalCount = response.readInteger();
                if (totalCount == 0)
                    break;
            }
            else 
            {
                response.readInteger(); // eat the line
            }

            auto lines = response.readRemainingUtfLines();
            auto found = FoundLine.parseMfn(lines);
            if (found.length == 0)
                break;
            result ~= found;
            firstRecord += found.length;
            if (firstRecord >= totalCount)
                break;
        } // while

        return result;
    } // method searchAll

    /**
     * Determine the number of records matching the search expression.
     */
    int searchCount(string expression)
    {
        if (!connected)
            return 0;

        if (expression.length == 0)
            return 0;

        auto query = new ClientQuery(this, "K");
        query.addAnsi(database).newLine();
        query.addUtf(expression).newLine();
        query.add(0).newLine();
        query.add(0).newLine();
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode())
            return 0;

        auto result = response.readInteger();
        return result;
    } // method searchCount

    /**
     * Search for recods and read found ones
     * (no more than 32k records).
     */
    MarcRecord[] searchRead(string expression, int limit=0)
    {
        MarcRecord[] result;
        if (!connected || isNullOrEmpty(expression))
            return result;
        
        auto parameters = new SearchParameters();
        parameters.expression = expression;
        parameters.format = ALL_FORMAT;
        parameters.numberOfRecords = limit;
        auto found = search(parameters);
        if ((found is null) || (found.length == 0))
            return result;

        foreach (item; found)
        {
            auto lines = split(item.description, ALT_DELIMITER);
            if (lines.length == 0)
                continue;
            lines = lines[1..$];
            if (lines.length == 0)
                continue;
            auto record = new MarcRecord();
            record.decode(lines);
            record.database = database;
            result ~= record;
        }

        return result;
    } // method searchRead

    /**
     * Search and read for single record satisfying the expression.
     * If many records found, any of them will be returned.
     * If no records found, null will be returned.
     */
    MarcRecord searchSingleRecord(string expression)
    {
        auto found = searchRead(expression, 1);
        return found.length != 0 ? found[0] : null;
    } // method searchSingleRecord

    /**
     * Compose the connection string for current connection.
     * The connection does not have to be established.
     */
    pure string toConnectionString() const
    {
        return format
            (
                "host=%s;port=%d;username=%s;password=%d;database=%s;arm=%s;",
                host,
                port,
                username,
                password,
                database,
                workstation
            );
    } // method toConnectionString

    /**
     * Empty the database.
     */
    bool truncateDatabase(string database)
    {
        if (!connected)
            return false;

        auto query = new ClientQuery(this, "S");
        query.addAnsi(database).newLine();
        return execute(query).ok;
    } // method truncateDatabase

    /**
     * Restore the deleted record.
     * If the record isn't deleted, no action taken.
     */
    MarcRecord undeleteRecord(int mfn)
    {
        auto result = readRecord(mfn);
        if (result is null)
            return result;

        if (result.isDeleted)
        {
            result.status &= ~LOGICALLY_DELETED;
            if (writeRecord(result) == 0)
                return null;
        }

        return result;
    } // method undeleteRecord

    /**
     * Unlock the database.
     */
    bool unlockDatabase(string database)
    {
        if (!connected)
            return false;

        auto query = new ClientQuery(this, "U");
        query.addAnsi(database).newLine();
        return execute(query).ok;
    } // method unlockDatabase

    /**
     * Unlock the slice of records.
     */
    bool unlockRecords(string databaseName, int[] mfnList)
    {
        if (!connected)
            return false;

        if (mfnList.length == 0)
            return true;

        const db = pickOne(databaseName, this.database);
        auto query = new ClientQuery(this, "Q");
        query.addAnsi(db).newLine();
        foreach(mfn; mfnList)
            query.add(mfn).newLine();
        return execute(query).ok;
    } // method unlockRecords

    /**
     * Update server INI file lines for current user.
     */
    bool updateIniFile(string[] lines)
    {
        if (!connected)
            return false;

        if (lines.length == 0)
            return true;

        auto query = new ClientQuery(this, "8");
        foreach (line; lines)
            query.addAnsi(line).newLine();
        return execute(query).ok;
    } // method updateIniFile

    /**
     * Write the raw record to the server.
     */
    int writeRawRecord
        (
            const RawRecord record,
            bool lockFlag=false,
            bool actualize=true
        )
    {
        if (!connected || (record is null))
            return 0;

        auto db = pickOne(record.database, this.database);
        auto query = new ClientQuery(this, "D");
        query.addAnsi(db).newLine();
        query.add(lockFlag).newLine();
        query.add(actualize).newLine();
        query.addUtf(record.encode()).newLine();
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode())
            return 0;

        return response.returnCode;
    } // method writeRawRecord

    /**
     * Write the record to the server.
     */
    int writeRecord
        (
            MarcRecord record, 
            bool lockFlag=false, 
            bool actualize=true,
            bool dontParse=false
         )
    {
        if (!connected || (record is null))
            return 0;

        auto db = pickOne(record.database, this.database);
        auto query = new ClientQuery(this, "D");
        query.addAnsi(db).newLine();
        query.add(lockFlag).newLine();
        query.add(actualize).newLine();
        query.addUtf(record.encode()).newLine();
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode())
            return 0;

        if (!dontParse)
        {
            record.fields = [];
            auto temp = response.readRemainingUtfLines();
            auto lines = [temp[0]];
            lines ~= split(temp[1], SHORT_DELIMITER);
            record.decode(lines);
            record.database = database;
        }

        return response.returnCode;
    } // method writeRecord

    /**
     * Write the text file to the server.
     */
    bool writeTextFile(string specification)
    {
        if (!connected)
            return false;

        auto query = new ClientQuery(this, "L");
        query.addAnsi(specification);
        return execute(query).ok;
    } // method writeTextFile

} // class Connection

//==================================================================

