import std.stdio;
import std.array;
import std.conv;
import std.encoding: transcode, Windows1251String;
import std.random: uniform;
import std.socket;
import std.string;
import std.outbuffer;

//==================================================================
//
// Utility functions

ubyte[] toAnsi(string text)
{
    Windows1251String encoded;
    transcode(text, encoded);
    return cast(ubyte[])encoded;
}

string fromAnsi(ubyte[] text)
{
    Windows1251String s = cast(Windows1251String)text;
    string decoded;
    transcode(s, decoded);
    return decoded;
}

ubyte[] toUtf(string text)
{
    return cast(ubyte[])text;
}

string fromUtf(ubyte[] text)
{
    return cast(string)text;
}

pure bool sameChar(char c1, char c2)
{
    return toUpper(c1) == toUpper(c2);
}

pure bool sameString(string s1, string s2)
{
    return icmp(s1, s2) == 0;
}

string irbisToDos(string text)
{
    return replace(text, "\x1F\x1E", "\n");
}

string[] irbisToLines(string text)
{
    return text.split("\x1F\x1E");
}

pure int parseInt(ubyte[] text)
{
    int result = 0;
    foreach(c; text)
        result = result * 10 + c - 32;
    return result;
}

pure int parseInt(string text)
{
    int result = 0;
    foreach(c; text)
        result = result * 10 + c - 48;
    return result;
}

pure string[] split2(string text, string delimiter)
{
    auto index = indexOf(text, delimiter);
    if (index < 0)
    {
        return [text];
    }

    return [text[0..index], text[index + 1..$]];
}

pure string oneOf(string[] strings ...)
{
    foreach(s; strings)
        if ((s != null) && (s.length != 0))
            return s;

    throw new Exception("No strings!");
}

pure bool isNullOrEmpty(string text)
{
    return (text is null) || (text.length == 0);
}

string removeComments(string text)
{
    if (isNullOrEmpty(text))
        return text;

    if (indexOf(text, "/*") < 0)
        return text;

    // TODO implement
    return text;
}

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

    this()
    {
    }

    this(char code, string value)
    {
        this.code = code;
        this.value = value;
    }

    /**
     * Deep clone of the subfield.
     */
    SubField clone() const
    {
        return new SubField(code, value);
    }

    /**
     * Decode the subfield from protocol representation.
     */
    void decode(string text)
    {
        code = text[0];
        value = text[1..$];
    }

    pure override string toString() const
    {
        return "^" ~ code ~ value;
    }

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

    this(int tag=0, string value="")
    {
        this.tag = tag;
        this.value = value;
        this.subfields = new SubField[0];
    }

    /**
     * Append subfield with specified code and value.
     */
    RecordField add(char code, string value)
    {
        auto subfield = new SubField(code, value);
        subfields ~= subfield;
        return this;
    }

    /**
     * Clear the field (remove the value and all the subfields).
     */
    RecordField clear()
    {
        value = "";
        subfields = [];
        return this;
    }

    /**
     * Clone the field.
     */
    RecordField clone()
    {
        auto result = new RecordField(tag, value);
        foreach (subfield; subfields)
        {
            result.subfields ~= subfield.clone();
        }
        return result;
    }

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
    }

    /**
     * Decode the field from the protocol representation.
     */
    void decode(string text)
    {
        auto parts = split2(text, "#");
        tag = parseInt(parts[0]);
        decodeBody(parts[1]);
    }

    /**
     * Get slice of the embedded fields.
     */
    RecordField[] getEmbeddedFields()
    {
        // TODO implement
        return [];
    }

    /**
     * Get first subfield with given code.
     */
    SubField getFirstSubField(char code)
    {
        foreach (subfield; subfields)
            if (sameChar(subfield.code, code))
                return subfield;
        return null;
    }

    /**
     * Get value of first subfield with given code.
     */
    string getFirstSubFieldValue(char code)
    {
        foreach (subfield; subfields)
            if (sameChar(subfield.code, code))
                return subfield.value;
        return null;
    }

    /**
     * Insert the subfield at specified position.
     */
    RecordField insertAt(int index, SubField subfield)
    {
        // TODO implement
        return this;
    }

    /**
     * Remove subfield at specified position.
     */
    RecordField removeAt(int index)
    {
        // TODO implement
        return this;
    }

    /**
     * Remove all subfields with specified code.
     */
    RecordField removeSubfield(char code)
    {
        // TODO implement
        return this;
    }

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
    }

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
    }
} // class RecordField

//==================================================================

/**
 * Record consist of fields.
 */
final class MarcRecord
{
    string database;
    int mfn;
    int versionNumber;
    int status;
    RecordField[] fields;

    this()
    {
        fields = new RecordField[0];
    }

    /**
     * Add the field to back of the record.
     */
    RecordField add(int tag, string value="")
    {
        auto field = new RecordField(tag, value);
        fields ~= field;
        return field;
    }

    /**
     * Add the field if it is non-empty.
     */
    MarcRecord addNonEmpty(int tag, string value)
    {
        if (value.length != 0)
            add(tag, value);
        return this;
    }

    /**
     * Clear the record by removing all the fields.
     */
    MarcRecord clear()
    {
        fields = [];
        return this;
    }

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
    }

    /**
     * Encode the record to the protocol representation.
     */
    pure string encode(string delimiter="\x1F\x1E") const
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
    }

    /**
     * Get value of the field with given tag
     * (or subfield if code given).
     */
    string fm(int tag, char code=0)
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
    }

    /**
     * Get slice of values of the fields with given tag
     * (or subfield values if code given).
     */
    string[] fma(int tag, char code=0)
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
    RecordField getField(int tag, int occurrence=0)
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
    }

    /**
     * Get slice of fields with given tag.
     */
    RecordField[] getFields(int tag)
    {
        RecordField[] result;
        foreach (field; fields)
        {
            if (field.tag == tag)
                result ~= field;
        }

        return result;
    }

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
    }

    MarcRecord removeAt(int index)
    {
        // TODO implement
        return this;
    }

    pure override string toString() const
    {
        return encode("\n");
    }
} // class MarcRecord

//==================================================================

final class RawRecord
{
    string database;
    int mfn;
    int versionNumber;
    int status;
    string[] fields;
} // class RawRecord

//==================================================================

/**
 * Two lines in the MNU-file.
 */
final class MenuEntry
{
    string code;
    string comment;

    this()
    {
    }

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
    MenuEntry[] entries; // entries

    MenuFile add(string code, string comment)
    {
        auto entry = new MenuEntry(code, comment);
        entries ~= entry;
        return this;
    }

    MenuFile clear()
    {
        entries = [];
        return this;
    }

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

    string getValue(string code, string defaultValue="")
    {
        auto entry = getEntry(code);
        if (entry is null)
            return defaultValue;
        return entry.comment;
    }

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
    string name;
    IniLine[] lines;

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
    IniSection[] sections;

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
    }

    /**
     * Set the value for specified key in specified section.
     */
    IniFile setValue(string sectionName, string key, string value)
    {
        auto section = getOrCreateSection(sectionName);
        section.setValue(key, value);
        return this;
    }

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
    }
} // class IniFile

//==================================================================

final class TreeNode
{
    TreeNode[] children;
    string value;
    int level;
} // class TreeNode

//==================================================================

final class TreeFile
{
    TreeNode[] roots;
} // class TreeFile

//==================================================================

/*
 * Information about IRBIS database.
 */
final class DatabaseInfo
{
    string name; /// Database name
    string description; /// Description
    int maxMfn; // Maximal MFN
    int[] logicallyDeletedRecords;
    int[] physicallyDeletedRecords;
    int[] nonActualizedRecords;
    int[] lockedRecords;
    bool databaseLocked;
    bool readOnly;

    static DatabaseInfo[] parseMenu(MenuFile menu)
    {
        DatabaseInfo[] result;

        foreach(entry; menu.entries)
        {
            auto name = entry.code;
            if (name.length == 0 || name.startsWith("*****"))
                break;
            auto description = entry.comment;
            auto readOnly = false;
            if (name[0] == '-')
            {
                name = name[1..$];
                readOnly = true;
            }

            auto db = new DatabaseInfo();
            db.name = name;
            db.description = description;
            db.readOnly = readOnly;
            result ~= db;
        } // foreach

        return result;
    } // method parseMenu

    override string toString()
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
    /**
     * License owner organization.
     */
    string organization;

    /**
     * Server version itself. Example: 64.2008.1
     */
    string serverVersion;

    /**
     * Maximum simultaneous connected client number.
     */
    int maxClients;

    /**
     * Current connected clients number.
     */
    int connectedClients;

    this()
    {
        organization = "";
        serverVersion = "";
        maxClients = 0;
        connectedClients = 0;
    }

    /**
     * Parse the server answer.
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

final class SearchParameters
{
    string database;
    int firstRecord = 1;
    string format;
    int maxMfn;
    int minMfn;
    int numberOfRecords;
    string expression;
    string sequential;
    string filter;
    bool isUtf;
} // class SearchParameters

//==================================================================

struct FoundLine
{
    int mfn;
    string description;

    void parse(string text)
    {
        auto parts = split2(text, "#");
        mfn = parseInt(parts[0]);
        if (parts.length > 1)
            description = parts[1];
    }

    static string[] parseDesciptions(string[] lines)
    {
        string[] result;
        foreach(line; lines)
        {
            if (line.length != 0)
            {
                auto index = indexOf(line, '#');
                if (index >= 0)
                {
                    auto description = line[index+1..$];
                    result ~= description;
                }
            }
        }

        return result;
    } // method parseDescriptions

    static FoundLine[] parseFull(string[] lines)
    {
        FoundLine[] result;
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

    static int[] parseMfn(string[] lines)
    {
        int[] result;
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
    string text; // search term text

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
    }
} // class TermInfo

//==================================================================

/**
 * Term posting info.
 */
struct TermPosting
{
    int mfn;
    int tag;
    int occurrence;
    int count;
    string text;

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
 * IRBIS64 server working statistics.
 */
final class ServerStat
{
    string[] runningClients;
    int clientCount;
    int totalCommandCount;
} // class ServerStat

//==================================================================

/**
 * Client query.
 */
final class ClientQuery
{
    private OutBuffer _buffer;

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

    ClientQuery add(int value)
    {
        auto text = to!string(value);
        return addUtf(text);
    } // method add

    ClientQuery add(bool value)
    {
        auto text = value ? "1" : "0";
        return addUtf(text);
    } // method add

    ClientQuery addAnsi(string text)
    {
        auto bytes = toAnsi(text);
        _buffer.write(bytes);
        return this;
    } // method addAnsi

    bool addFormat(string text)
    {
        auto stripped = strip(text);

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

    ClientQuery addUtf(string text)
    {
        auto bytes = toUtf(text);
        _buffer.write(bytes);
        return this;
    } // method addUtf

    ubyte[] encode() const
    {
        auto bytes = _buffer.toBytes();
        auto result = new OutBuffer();
        result.printf("%d\n", bytes.length);
        result.write(bytes);
        return result.toBytes();
    } // method encode

    ClientQuery newLine()
    {
        _buffer.write(cast(byte)10);
        return this;
    } // method newLine
} // class ClientQuery

//==================================================================

final class ServerResponse
{
    private bool _ok;
    private ubyte[] _buffer;
    private ptrdiff_t _offset;

    string command;
    int clientId;
    int queryId;
    int answerSize;
    int returnCode;
    string serverVersion;
    int interval;

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

    @property bool ok() const nothrow
    {
        return _ok;
    }

    @property bool eof() const nothrow
    {
        return _offset >= _buffer.length;
    }

    bool checkReturnCode(int[] allowed ...)
    {
        if (getReturnCode() < 0)
        {
            // if (indexOf(allowed, returnCode) < 0)
                return false;
        }
        return true;
    }

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
    }

    int getReturnCode()
    {
        returnCode = readInteger();
        return returnCode;
    }

    string readAnsi()
    {
        return fromAnsi(getLine());
    }

    int readInteger()
    {
        auto line = readUtf();
        auto result = 0;
        if (line.length != 0)
        {
            result = to!int(line);
        }
        return result;
    }

    string[] readRemainingAnsiLines()
    {
        string[] result = new string[0];
        while (!eof)
        {
            auto line = readAnsi();
            result ~= line;
        }
        return result;
    }

    string readRemainingAnsiText()
    {
        auto chunk = _buffer[_offset..$];
        return fromAnsi(chunk);
    }

    string[] readRemainingUtfLines()
    {
        string[] result = new string[0];
        while (!eof)
        {
            auto line = readUtf();
            result ~= line;
        }
        return result;
    }

    string readRemainingUtfText()
    {
        auto chunk = _buffer[_offset..$];
        return fromUtf(chunk);
    }

    string readUtf()
    {
        return fromUtf(getLine());
    }
} // class ServerResponse

//==================================================================

/**
 * Abstract client socket.
 */
class ClientSocket
{
    abstract ServerResponse talkToServer(const ClientQuery query);
} // class ClientSocket

//==================================================================

/**
 * Client socket implementation for TCP/IP v4.
 */
final class Tcp4ClientSocket : ClientSocket
{
    private Connection _connection;

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

final class Connection
{
    private bool _connected;

    string host;
    ushort port;
    string username;
    string password;
    string database;
    string workstation;
    int clientId;
    int queryId;
    string serverVersion;
    int interval;
    IniFile ini;
    ClientSocket socket;

    this()
    {
        host = "127.0.0.1";
        port = 6666;
        database = "IBIS";
        workstation = "C";
        socket = new Tcp4ClientSocket(this);
        _connected = false;
    }

    ~this()
    {
        disconnect();
    }

    @property bool connected() const nothrow
    {
        return _connected;
    }

    /**
     * Actualize all the non-actualized records in the database.
     */
    bool actualizeDatabase(string database)
    {
        return actualizeRecord(database, 0);
    }

    /**
     * Actualize the record with the given MFN.
     */
    bool actualizeRecord(string database, int mfn)
    {
        if (!connected)
            return false;

        auto query = new ClientQuery(this, "F");
        query.addAnsi(database).newLine();
        query.add(mfn).newLine();
        auto response = execute(query);
        if (!response.ok)
            return false;
        response.checkReturnCode();

        return true;
    }

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
        if (!response.ok)
            return false;
        response.checkReturnCode();

        return true;
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
        if (!response.ok)
            return false;

        response.checkReturnCode();

        return true;
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
        if (!response.ok)
            return false;

        response.checkReturnCode();

        return true;
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

    ServerResponse execute(const ClientQuery query)
    {
        ServerResponse result;
        try
        {
            result = socket.talkToServer(query);
            queryId++;
        }
        catch (Exception ex)
        {
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
        if (!response.ok)
            return "";

        response.checkReturnCode();
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

        auto db = oneOf(record.database, this.database);
        auto query = new ClientQuery(this, "G");
        query.addAnsi(db).newLine();
        query.addFormat(format);
        query.add(-2).newLine();
        query.addUtf(record.encode("\x1F\x1E"));
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

        auto db = oneOf(databaseName, this.database);
        auto query = new ClientQuery(this, "O");
        query.addAnsi(db);
        auto response = execute(query);
        if (!response.ok)
            return 0;

        response.checkReturnCode();

        return response.returnCode;
    } // method getMaxMfn

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
            if (response.ok)
            {
                response.checkReturnCode();
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
     * List server files by specifiaction.
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

            auto name = toLower(strip(parts[0]));
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
        if (!response.ok)
            return null;

        response.checkReturnCode();

        auto result = new MarcRecord();
        auto lines = response.readRemainingUtfLines();
        result.decode(lines);
        result.database = database;

        return result;
    } // method readRecord

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
    TermInfo[] readTerms(TermParameters parameters)
    {
        if (!connected)
            return [];

        auto command = parameters.reverseOrder ? "P" : "H";
        auto db = oneOf(parameters.database, this.database);
        auto query = new ClientQuery(this, command);
        query.addAnsi(db).newLine();
        query.addUtf(parameters.startTerm).newLine();
        query.add(parameters.numberOfTerms).newLine();
        auto prepared = prepareFormat(parameters.format);
        query.addAnsi(prepared).newLine();
        auto response = execute(query);
        if (!response.ok)
            return [];

        response.checkReturnCode(-202, -203, -204);

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
        result = irbisToDos(result);

        return result;
    } // method readTextFile

    /**
    * Read the text file from the server as the array of lines.
    */
    string[] readTextLines(string specification)
    {
        if (!connected)
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
     * Simple search.
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
        if (!response.ok)
            return [];

        response.checkReturnCode();
        response.readInteger(); // count of found records
        auto lines = response.readRemainingUtfLines();
        auto result = FoundLine.parseMfn(lines);

        return result;
    } // method search

    /**
     * Extended search.
     */
    FoundLine[] search(SearchParameters parameters)
    {
        if (!connected)
            return [];

        auto db = oneOf(parameters.database, this.database);
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
        if (!response.ok)
            return [];

        response.checkReturnCode();
        response.readInteger(); // count of found records
        auto lines = response.readRemainingUtfLines();
        auto result = FoundLine.parseFull(lines);

        return result;
    } // method search

    /**
     * Search all the records.
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
     * Determine the number of entries matching the search expression.
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
        if (!response.ok)
            return 0;

        response.checkReturnCode();
        auto result = response.readInteger();

        return result;
    } // method searchCount

    /**
     * Compose the connection string for current connection.
     * The connection does not have to be established.
     */
    string toConnectionString()
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
        {
            query.addAnsi(line).newLine();
        }

        return execute(query).ok;
    } // method updateIniFile

    /**
     * Write the record to the server.
     */
    int writeRecord
        (
            const MarcRecord record, 
            bool lockFlag=false, 
            bool actualize=true
         )
    {
        if (!connected || (record is null))
            return 0;

        auto db = oneOf(record.database, this.database);
        auto query = new ClientQuery(this, "D");
        query.addAnsi(db).newLine();
        query.add(lockFlag).newLine();
        query.add(actualize).newLine();
        query.addUtf(record.encode()).newLine();
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode())
            return 0;

        return response.returnCode;
    } // method writeRecord

} // class Connection

//==================================================================

