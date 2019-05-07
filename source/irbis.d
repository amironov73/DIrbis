import std.stdio;
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

bool sameString(string s1, string s2)
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

//==================================================================

final class SubField
{
    char code;
    string value;

    this(char code, string value)
    {
        this.code = code;
        this.value = value;
    }
}

//==================================================================

final class RecordField
{
    int tag;
    string value;
    SubField[] subfields;

    this(int tag, string value="")
    {
        this.tag = tag;
        this.value = value;
        this.subfields = new SubField[0];
    }
}

//==================================================================

final class MarcRecord
{
    string database;
    int mfn;
    int versionNumber;
    int status;
    RecordField[] fields;
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

final class FoundLine
{
    bool materialized;
    int serialNumber;
    int mfn;
    bool selected;
    string description;
    string sort;
}

//==================================================================

final class MenuEntry
{
    string code;
    string comment;
}

//==================================================================

final class MenuFile
{
    MenuEntry[] entries;
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

    @property bool eof()
    {
        return _offset >= _buffer.length;
    }

    bool checkReturnCode()
    {
        if (getReturnCode() < 0)
        {
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

    @property bool connected() const nothrow
    {
        return _connected;
    }

    bool connect()
    {
        if (connected)
        {
            return true;
        }

        clientId = uniform(100_000, 999_999);
        queryId = 1;
        auto query = new ClientQuery(this, "A");
        query.addAnsi(username).newLine();
        query.addAnsi(password);
        auto response = execute(query);
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

    bool disconnect()
    {
        if (!connected)
        {
            return true;
        }

        auto query = new ClientQuery(this, "B");
        query.addAnsi(username);
        execute(query);
        _connected = false;

        return true;
    }

    ServerResponse execute(ClientQuery query)
    {
        auto result = socket.TalkToServer(query);
        queryId++;
        return result;
    }

    /**
     * Get maximal MFN for the database.
     */
    int getMaxMfn(string database)
    {
        if (!connected)
        {
            return 0;
        }

        auto query = new ClientQuery(this, "O");
        query.addAnsi(database);
        auto response = execute(query);
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
            response.checkReturnCode();
            auto lines = response.readRemainingAnsiLines();
            result.parse(lines);
        }

        return result;
    }

     /**
      * Empty operation. Confirms the client is alive.
      */
    bool noOp()
    {
        if (!connected)
        {
            return false;
        }

        auto query = new ClientQuery(this, "N");
        execute(query);

        return true;
    }

    /**
     * Read the text file from the server.
     */
    string readTextFile(string specification)
    {
        if (!connected)
        {
            return "";
        }

        auto query = new ClientQuery(this, "L");
        query.addAnsi(specification).newLine();
        auto response = execute(query);
        auto result = response.readAnsi();
        result = irbisToDos(result);

        return result;
    }

    /**
    * Recreate dictionary for the database.
    */
    bool reloadDictionary(string database)
    {
        if (!connected)
        {
            return false;
        }

        auto query = new ClientQuery(this, "Y");
        query.addAnsi(database).newLine();
        execute(query);

        return true;
    }

    /**
     * Recreate master file for the database.
     */
    bool reloadMasterFile(string database)
    {
        if (!connected)
        {
            return false;
        }

        auto query = new ClientQuery(this, "X");
        query.addAnsi(database).newLine();
        execute(query);

        return true;
    }

    /**
     * Restarting the server (without losing the connected clients).
     */
    bool restartServer()
    {
        if (!connected)
        {
            return false;
        }

        auto query = new ClientQuery(this, "+8");
        execute(query);

        return true;
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
        {
            return false;
        }

        auto query = new ClientQuery(this, "S");
        query.addAnsi(database).newLine();
        execute(query);

        return true;
    }

    /**
     * Unlock the database.
     */
    bool unlockDatabase(string database)
    {
        if (!connected)
        {
            return false;
        }

        auto query = new ClientQuery(this, "U");
        query.addAnsi(database).newLine();
        execute(query);

        return true;
    }

    /**
     * Update server INI file lines for current user.
     */
    bool updateIniFile(string[] lines)
    {
        if (!connected)
        {
            return false;
        }

        if (lines.length == 0)
        {
            return true;
        }

        auto query = new ClientQuery(this, "8");
        foreach (line; lines)
        {
            query.addAnsi(line).newLine();
        }
        execute(query);

        return true;
    }
}

//==================================================================

