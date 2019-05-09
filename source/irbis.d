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

string[] split2(string text, string delimiter)
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

    override pure string toString()
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

    override string toString()
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
    string encode(string delimiter)
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

    override string toString()
    {
        return encode("\n");
    }
}

//==================================================================

final class RawRecord
{
    string database;
    int mfn;
    int versionNumber;
    int status;
    string[] fields;
}

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

    override string toString()
    {
        return code ~ " - " ~ comment;
    }
}

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

    override string toString()
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
}

//==================================================================

final class IniLine
{
    string key;
    string value;
}

//==================================================================

final class IniSection
{
    string name;
    IniLine[] lines;
}

//==================================================================

final class IniFile
{
    IniSection[] sections;
}

//==================================================================

final class TreeNode
{
    TreeNode[] children;
    string value;
    int level;
}

//==================================================================

final class TreeFile
{
    TreeNode[] roots;
}

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
        }

        return result;
    }

    override string toString()
    {
        return name;
    }
}

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
    }
}

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

}

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
    }

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
    }

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
    }
}

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
    }

    string toString()
    {
        return format("%d#%s", count, text);
    }
}

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
    }

    string toString()
    {
        return to!string(mfn) ~ "#"
            ~ to!string(tag) ~ "#"
            ~ to!string(occurrence) ~ "#"
            ~ to!string(count) ~ "#"
            ~ text;
    }
}

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
}

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

    override string toString()
    {
        return table;
    }
}

//==================================================================

/**
 * IRBIS64 server working statistics.
 */
final class ServerStat
{
    string[] runningClients;
    int clientCount;
    int totalCommandCount;
}

//==================================================================

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
    }

    ClientQuery add(int value)
    {
        auto text = to!string(value);
        return addUtf(text);
    }

    ClientQuery addAnsi(string text)
    {
        auto bytes = toAnsi(text);
        _buffer.write(bytes);
        return this;
    }

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
    }

    ClientQuery addUtf(string text)
    {
        auto bytes = toUtf(text);
        _buffer.write(bytes);
        return this;
    }

    ubyte[] encode()
    {
        auto bytes = _buffer.toBytes();
        auto result = new OutBuffer();
        result.printf("%d\n", bytes.length);
        result.write(bytes);
        return result.toBytes();
    }

    ClientQuery newLine()
    {
        _buffer.write(cast(byte)10);
        return this;
    }
}

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
    }

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
}

//==================================================================

class ClientSocket
{
    abstract ServerResponse TalkToServer(ClientQuery query);
}

//==================================================================

final class Tcp4ClientSocket : ClientSocket
{
    private Connection _connection;

    this(Connection connection)
    {
        _connection = connection;
    }

    override ServerResponse TalkToServer(ClientQuery query)
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
    }
}

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

        clientId = uniform(100_000, 999_999);
        queryId = 1;
        auto query = new ClientQuery(this, "A");
        query.addAnsi(username).newLine();
        query.addAnsi(password);
        auto response = execute(query);
        if (!response.ok)
        {
            return false;
        }

        response.getReturnCode();
        if (response.returnCode < 0)
        {
            return false;
        }

        _connected = true;
        serverVersion = response.serverVersion;
        interval = response.interval;

        return true;
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
        if (!response.ok)
            return false;
        response.checkReturnCode();

        return true;
    }

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
    }

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
    }

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
    }

    ServerResponse execute(ClientQuery query)
    {
        ServerResponse result;
        try
        {
            result = socket.TalkToServer(query);
            queryId++;
        }
        catch (Exception ex)
        {
            result = new ServerResponse([]);
        }

        return result;
    }

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
    }

    /**
     * Get the maximal MFN for the database.
     */
    int getMaxMfn(string database)
    {
        if (!connected)
            return 0;

        auto query = new ClientQuery(this, "O");
        query.addAnsi(database);
        auto response = execute(query);
        if (!response.ok)
            return 0;

        response.checkReturnCode();

        return response.returnCode;
    }

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
    }

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
    }

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
    }

     /**
      * Empty operation. Confirms the client is alive.
      */
    bool noOp()
    {
        if (!connected)
            return false;

        auto query = new ClientQuery(this, "N");

        return execute(query).ok;
    }

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
    }

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
    }

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
    }

    TermInfo[] readTerms(string startTerm, int number)
    {
        auto parameters = new TermParameters();
        parameters.startTerm = startTerm;
        parameters.numberOfTerms = number;
        return readTerms(parameters);
    }

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
    }

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
    }

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
    }

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
    }

    /**
     * Restarting the server (without losing the connected clients).
     */
    bool restartServer()
    {
        if (!connected)
            return false;

        auto query = new ClientQuery(this, "+8");

        return execute(query).ok;
    }

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
    }

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
    }

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
    }

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
    }

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
    }

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
    }

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
    }
}

//==================================================================

