/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

module irbis.connection;

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

import irbis.constants, irbis.utils, irbis.records, irbis.menus, 
       irbis.tree, irbis.ini, irbis.structures, irbis.errors;

//==================================================================

/**
 * Client query encoder.
 */
export struct ClientQuery
{
    private OutBuffer _buffer;

    @disable this();

    /// Constructor.
    this(Connection connection, string command)
        in (connection !is null)
        in (!connection.username.empty)
        in (!connection.password.empty)
        in (!command.empty)
    {
        _buffer = new OutBuffer;
        addAnsi(command).newLine;
        addAnsi(connection.workstation).newLine;
        addAnsi(command).newLine;
        add(connection.clientId).newLine;
        add(connection.queryId).newLine;
        addAnsi(connection.password).newLine;
        addAnsi(connection.username).newLine;
        newLine;
        newLine;
        newLine;
    } // constructor

    /// Add integer value.
    ref ClientQuery add(int value) {
        auto text = to!string(value);
        return addUtf(text);
    } // method add

    /// Add boolean value.
    ref ClientQuery add(bool value) {
        auto text = value ? "1" : "0";
        return addUtf(text);
    } // method add

    /// Add text in ANSI encoding.
    ref ClientQuery addAnsi(string text) {
        auto bytes = toAnsi(text);
        _buffer.write(bytes);
        return this;
    } // method addAnsi

    /// Add format specification
    bool addFormat(string text) {
        const stripped = strip(text);

        if (stripped.empty) {
            newLine;
            return false;
        }

        auto prepared = prepareFormat(text);
        if (prepared[0] == '@') 
            addAnsi(prepared);
        else if (prepared[0] == '!')
            addUtf(prepared);
        else {
            addUtf("!");
            addUtf(prepared);
        }
        newLine;
        return true;
    } // method addFormat

    /// Add text in UTF-8 encoding.
    ref ClientQuery addUtf(string text) {
        auto bytes = toUtf(text);
        _buffer.write(bytes);
        return this;
    } // method addUtf

    /// Encode the query.
    ubyte[] encode() const {
        auto bytes = _buffer.toBytes();
        auto result = new OutBuffer();
        result.printf("%d\n", bytes.length);
        result.write(bytes);
        return result.toBytes();
    } // method encode

    /// Add line delimiter symbol.
    ref ClientQuery newLine() {
        _buffer.write(cast(byte)10);
        return this;
    } // method newLine

} // class ClientQuery

//==================================================================

/**
 * Server response decoder.
 */
export struct ServerResponse
{
    private bool _ok;
    private ubyte[] _buffer;
    private ptrdiff_t _offset;

    Connection connection; /// Connection used.

    string command; /// Command code.
    int clientId; /// Client id.
    int queryId; /// Query id.
    int answerSize; /// Answer size.
    int returnCode; /// Return code.
    string serverVersion; /// Server version.
    int interval; /// Auto-ack interval.

    @disable this();

    /// Constructor.
    this(ubyte[] buffer) {
        _ok = !buffer.empty;
        _buffer = buffer;
        _offset=0;

        if (_ok)
        {
            command = readAnsi;
            clientId = readInteger;
            queryId = readInteger;
            answerSize = readInteger;
            serverVersion = readAnsi;
            interval = readInteger;
            readAnsi;
            readAnsi;
            readAnsi;
            readAnsi;
        }
    } // this

    /// Whether all data received?
    pure bool ok() const nothrow {
        return _ok;
    }

    /// Whether end of response reached?
    pure bool eof() const nothrow {
        return _offset >= _buffer.length;
    }

    /// Check return code.
    bool checkReturnCode(int[] allowed ...) {
        if (getReturnCode < 0)
            return canFind(allowed, returnCode);
        return true;
    }

    /// Get raw line (no encoding applied).
    ubyte[] getLine() {
        if (_offset >= _buffer.length)
            return null;

        auto result = new OutBuffer;
        while (_offset < _buffer.length) {
            auto symbol = _buffer[_offset++];
            if (symbol == 13) {
                if (_buffer[_offset] == 10)
                    _offset++;
                break;
            }
            result.write(symbol);
        }

        return result.toBytes;
    } // method getLine

    /// Get return code.
    int getReturnCode() {
        returnCode = readInteger;
        connection.lastError = returnCode;
        return returnCode;
    }

    /// Read line in ANSI encoding.
    string readAnsi() {
        return fromAnsi(getLine);
    } // method readAnsi

    /// Read integer value
    int readInteger() {
        auto line = readUtf;
        auto result = 0;
        if (!line.empty)
            result = to!int(line);
        return result;
    } // method readInteger

    /// Read remaining lines in ANSI encoding.
    string[] readRemainingAnsiLines() {
        string[] result;
        while (!eof) {
            auto line = readAnsi;
            result ~= line;
        }
        return result;
    } // method readRemainingAnsiLines

    /// Read remaining text in ANSI encoding.
    string readRemainingAnsiText() {
        if (eof)
            return null;
        auto chunk = _buffer[_offset..$];
        return fromAnsi(chunk);
    } // method readRemainingAnsiText

    /// Read remaining lines in UTF-8 encoding.
    string[] readRemainingUtfLines() {
        string[] result;
        while (!eof) {
            auto line = readUtf;
            result ~= line;
        }
        return result;
    } // method readRemainingUtfLines

    /// Read remaining text in UTF-8 encoding.
    string readRemainingUtfText() {
        if (eof)
            return null;
        auto chunk = _buffer[_offset..$];
        return fromUtf(chunk);
    } // method readRemainingUtfText

    /// Read line in UTF-8 encoding.
    string readUtf() {
        return fromUtf(getLine);
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
    abstract ServerResponse talkToServer(const ref ClientQuery query);
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

    override ServerResponse talkToServer(const ref ClientQuery query)
    {
        auto socket = new Socket(AddressFamily.INET, SocketType.STREAM);
        auto address = new InternetAddress(_connection.host, _connection.port);
        socket.connect(address);
        scope(exit) socket.close;
        auto outgoing = query.encode;
        socket.send(outgoing);

        ptrdiff_t amountRead;
        auto incoming = new OutBuffer;
        incoming.reserve(2048);
        auto buffer = new ubyte[2056];
        while((amountRead = socket.receive(buffer)) != 0)
        {
            incoming.write(buffer[0..amountRead]);
        }

        auto result = ServerResponse(incoming.toBytes);

        return result;
    } // method talkToServer

} // class Tcp4ClientSocket

//==================================================================

/**
 * IRBIS-sever connection.
 */
export final class Connection
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
    this() {
        host = "127.0.0.1";
        port = 6666;
        database = "IBIS";
        workstation = CATALOGER;
        socket = new Tcp4ClientSocket(this);
        _connected = false;
    } // constructor

    /// Constructor.
    this(string connectionString) {
        this();
        parseConnectionString(connectionString);
        connect;
    } // constructor

    ~this() {
        disconnect;
    } // destructor

    /**
     * Actualize all the non-actualized records in the database.
     */
    bool actualizeDatabase(string database="") {
        const db = pickOne(database, this.database);
        return actualizeRecord(db, 0);
    } // method actualizeDatabase

    /**
     * Actualize the record with the given MFN.
     */
    bool actualizeRecord(string database, int mfn)
        in (mfn >= 0)
    {
        if (!connected)
            return false;

        const db = pickOne(database, this.database);
        scope auto query = ClientQuery (this, "F");
        query.addAnsi(db).newLine;
        query.add(mfn).newLine;
        scope auto response = execute(query);
        return response.ok && response.checkReturnCode;
    } // method actualizeRecord

    /**
     * Establish the server connection.
     */
    bool connect()
        in (!host.empty)
        in (port > 0)
        in (!username.empty)
        in (!password.empty)
        in (!workstation.empty)
        in (socket !is null)
    {
        if (connected)
            return true;

        AGAIN: queryId = 1;
        clientId = uniform(100_000, 999_999);
        auto query = ClientQuery(this, "A");
        query.addAnsi(username).newLine;
        query.addAnsi(password);
        auto response = execute(query);
        if (!response.ok)
            return false;

        response.getReturnCode;
        if (response.returnCode == -3337)
            goto AGAIN;

        if (response.returnCode < 0) {
            lastError = response.returnCode;
            return false;
        }

        _connected = true;
        serverVersion = response.serverVersion;
        interval = response.interval;
        auto lines = response.readRemainingAnsiLines;
        ini = new IniFile;
        ini.parse(lines);
        return true;
    } // method connect

    /// Whether the client is connected to the server?
    @property pure bool connected() const nothrow {
        return _connected;
    }

    /**
     * Create the server database.
     */
    bool createDatabase
        (
            string database,
            string description,
            bool readerAccess=true
        )
        in (!database.empty)
        in (!description.empty)
    {
        if (!connected)
            return false;

        scope auto query = ClientQuery(this, "T");
        query.addAnsi(database).newLine;
        query.addAnsi(description).newLine;
        query.add(cast(int)readerAccess).newLine;
        scope auto response = execute(query);
        return response.ok && response.checkReturnCode;
    } // method createDatabase

    /**
     * Create the dictionary for the database.
     */
    bool createDictionary(string database="") {
        if (!connected)
            return false;

        auto db = pickOne(database, this.database);
        scope auto query = ClientQuery(this, "Z");
        query.addAnsi(db).newLine;
        scope auto response = execute(query);
        return response.ok && response.checkReturnCode;
    } // method createDictionary

    /**
     * Delete the database on the server.
     */
    bool deleteDatabase(string database)
        in (!database.empty)
    {
        if (!connected)
            return false;

        scope auto query = ClientQuery(this, "W");
        query.addAnsi(database).newLine;
        scope auto response = execute(query);
        return response.ok && response.checkReturnCode;
    } // method deleteDatabase

    /**
     * Delete specified file on the server.
     */
    void deleteFile(string fileName)
    {
        if (!fileName.empty)
            formatRecord("&uf(+9K'" ~ fileName ~"')", 1);
    } // method deleteFile

    /**
     * Delete the record by MFN.
     */
    bool deleteRecord(int mfn) {
        auto record = readRawRecord(mfn);
        if (record !is null && !record.deleted) {
            record.status |= LOGICALLY_DELETED;
            return writeRawRecord(record) != 0;
        }
        return false;
    } // method deleteRecord

    /**
     * Disconnect from the server.
     */
    bool disconnect()
        out(; !connected)
    {
        if (!connected)
            return true;

        scope auto query = ClientQuery(this, "B");
        query.addAnsi(username);
        execute(query);
        _connected = false;
        return true;
    } // method disconnect

    /**
     * Execute the query.
     */
    ServerResponse execute(scope const ref ClientQuery query) {
        lastError = 0;
        auto result = ServerResponse([]);
        try {
            result = socket.talkToServer(query);
            result.connection = this;
            queryId++;
        }
        catch (Exception ex) {
            lastError = -100_000;
        }

        return result;
    } // method execute

    /**
     * Execute arbitrary command with optional parameters.
     */
    ServerResponse executeAny(string command, string[] parameters ... ) {
        if (!connected)
            return ServerResponse([]);
        auto query = ClientQuery(this, command);
        foreach (parameter; parameters)
            query.addAnsi(parameter).newLine;
        return execute(query);
    } // method executeAny

    /**
     * Format the record by MFN.
     */
    string formatRecord(string text, int mfn)
        in (mfn > 0)
    {
        if (!connected || text.empty)
            return "";

        auto query = ClientQuery(this, "G");
        query.addAnsi(database).newLine;
        if (!query.addFormat(text))
            return "";

        query.add(1).newLine;
        query.add(mfn).newLine;
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return "";

        auto result = response.readRemainingUtfText;
        result = strip(result);

        return result;
    } // method formatRecord

    /**
     * Format virtual record.
     */
    string formatRecord(string format, const MarcRecord record) {
        if (!connected || format.empty || (record is null))
            return "";

        auto db = pickOne(record.database, this.database);
        auto query = ClientQuery(this, "G");
        query.addAnsi(db).newLine;
        query.addFormat(format);
        query.add(-2).newLine;
        query.addUtf(record.encode(IRBIS_DELIMITER));
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return "";

        auto result = response.readRemainingUtfText;
        result = stripRight(result);
        return result;
    } // method formatRecord

    /**
     * Format the slice of records.
     */
    string[] formatRecords(string format, int[] list ...) {
        if (!connected || list.empty)
            return [];

        string[] result;
        result.length = list.length;
        if (format.empty)
            return result;

        if (list.length == 1) {
            result[0] = formatRecord(format, list[0]);
            return result;
        }

        auto query = ClientQuery(this, "G");
        query.addAnsi(database).newLine;
        if (!query.addFormat(format))
            return result;
        query.add(cast(int)list.length).newLine;
        foreach(mfn; list)
            query.add(mfn).newLine;

        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return result;

        auto lines = response.readRemainingUtfLines;
        for(int i = 0; i < lines.length; i++) {
            auto parts = split2(lines[i], "#");
            if (parts.length != 1)
                result[i] = irbisToUnix(parts[1]);
        }

        return result;
    } // method formatRecords

    /**
     * Get information about the database.
     */
    DatabaseInfo getDatabaseInfo(string database = "") {
        DatabaseInfo result;
        if (!connected)
            return result;

        auto db = pickOne(database, this.database);
        auto query = ClientQuery(this, "0");
        query.addAnsi(db);
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return result;
        auto lines = response.readRemainingAnsiLines;
        result = new DatabaseInfo;
        result.parse(lines);
        return result;
    } // method getDatabaseInfo

    /**
     * Get the maximal MFN for the database.
     */
    int getMaxMfn(string databaseName = "") {
        if (!connected)
            return 0;

        auto db = pickOne(databaseName, this.database);
        auto query = ClientQuery(this, "O");
        query.addAnsi(db);
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return 0;

        return response.returnCode;
    } // method getMaxMfn

    /**
     * Get server running statistics.
     */
    ServerStat getServerStat() {
        auto result = new ServerStat();
        if (!connected)
            return result;

        auto query = ClientQuery(this, "+1");
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return result;

        auto lines = response.readRemainingAnsiLines;
        result.parse(lines);
        return result;
    } // method getServerStat

    /**
     * Get the server version.
     */
    VersionInfo getServerVersion() {
        VersionInfo result;

        if (connected) {
            auto query = ClientQuery(this, "1");
            auto response = execute(query);
            if (response.ok && response.checkReturnCode) {
                auto lines = response.readRemainingAnsiLines;
                result = new VersionInfo;
                result.parse(lines);
            }
        }

        return result;
    } // method getServerVersion

    /**
     * Get the user list from the server.
     */
    UserInfo[] getUserList() {
        UserInfo[] result;
        if (!connected)
            return result;

        auto query = ClientQuery(this, "+9");
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return result;

        auto lines = response.readRemainingAnsiLines;
        result = UserInfo.parse(lines);
        return result;
    } // method getUserList

    /**
     * Global correction.
     */
    string[] globalCorrection(GblSettings settings) {
        string[] result;

        if (!connected)
            return result;

        const db = pickOne(settings.database, this.database);
        auto query = ClientQuery(this, "5");
        query.addAnsi(db).newLine;
        query.add(settings.actualize).newLine;
        if (!settings.filename.empty) {
            query.addAnsi("@" ~ settings.filename).newLine;
        }
        else {
            auto encoded = new OutBuffer();
            encoded.write("!0");
            encoded.write(IRBIS_DELIMITER);
            foreach (statement; settings.statements)
                encoded.write(statement.encode);
            encoded.write(IRBIS_DELIMITER);
            query.addUtf(encoded.toString).newLine;
        }
        query.addAnsi(settings.searchExpression).newLine; // ???
        query.add(settings.firstRecord).newLine;
        query.add(settings.numberOfRecords).newLine;
        if (settings.mfnList.empty) {
            const count = settings.maxMfn - settings.minMfn + 1;
            query.add(count).newLine;
            for (int mfn = settings.minMfn; mfn < settings.maxMfn; mfn++)
                query.add(mfn).newLine;
        }
        else {
            query.add(cast(int)settings.mfnList.length).newLine;
            foreach (mfn; settings.mfnList)
                query.add(mfn).newLine;
        }
        if (!settings.formalControl)
            query.addUtf("*").newLine;
        if (!settings.autoin)
            query.addUtf("&").newLine;

        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return result;

        result = response.readRemainingAnsiLines;

        return result;
    } // method globalCorrection

    /**
     * List server databases.
     */
    DatabaseInfo[] listDatabases(string specification = "1..dbnam2.mnu") {
        DatabaseInfo[] result;

        if (!connected || specification.empty)
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
    string[] listFiles(string[] specifications ...) {
        string[] result;
        if (!connected || specifications.empty)
            return result;

        auto query = ClientQuery(this, "!");
        foreach (spec; specifications)
            if (spec.empty)
                query.addAnsi(spec).newLine;
        auto response = execute(query);
        if (!response.ok)
            return result;

        auto lines = response.readRemainingAnsiLines;
        foreach (line; lines) {
            auto files = irbisToLines(line);
            foreach (file; files) {
                if (!file.empty)
                    result ~= file;
            }
        }
        return result;
    } // method listFiles

    /**
     * Get server process list.
     */
    ProcessInfo[] listProcesses() {
        ProcessInfo[] result;
        if (!connected)
            return result;

        auto query = ClientQuery(this, "+3");
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return result;

        auto lines = response.readRemainingAnsiLines;
        result = ProcessInfo.parse(lines);
        return result;
    } // method listProcesses

    /**
     * List all the search terms for given prefix.
     */
    string[] listTerms(string prefix) {
        string[] result;
        if (!connected)
            return result;

        prefix = capitalize(prefix);
        const prefixLength = prefix.length;
        auto startTerm = prefix;
        auto lastTerm = startTerm;
        OUTER: while (true) {
            auto terms = readTerms(startTerm, 512);
            auto first = true;
            foreach (term; terms) {
                auto text = term.text;
                if (text[0..prefixLength] != prefix)
                    break OUTER;
                if (text != startTerm) {
                    lastTerm = text;
                    text = to!string(text[prefixLength..$]);
                    if (first && (result.length != 0)) {
                        if (text == result[$-1])
                            continue;
                    }
                    result ~= text;
                }
                first = false;
            }
            startTerm = lastTerm;
        }

        return result;
    }

    /**
     * Empty operation. Confirms the client is alive.
     */
    bool noOp() {
        if (!connected)
            return false;

        auto query = ClientQuery(this, "N");
        return execute(query).ok;
    } // method noOp

    /**
     * Parse the connection string.
     */
    void parseConnectionString(string connectionString) {
        const items = split(connectionString, ";");
        foreach(item; items) {
            if (item.empty)
                continue;

            auto parts = split2(item, "=");
            if (parts.length != 2)
                continue;

            const name = toLower(strip(parts[0]));
            auto value = strip(parts[1]);

            switch(name) {
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
     * Format table on the server.
     */
    string printTable(const ref TableDefinition definition) {
        if (!connected)
            return "";

        auto db = pickOne(definition.database, this.database);
        auto query = ClientQuery(this, "7");
        query.addAnsi(db).newLine;
        query.addAnsi(definition.table).newLine;
        query.addAnsi("").newLine; // instead of headers
        query.addAnsi(definition.mode).newLine;
        query.addAnsi(definition.searchQuery).newLine;
        query.add(definition.minMfn).newLine;
        query.add(definition.maxMfn).newLine;
        query.addUtf(definition.sequentialQuery).newLine;
        query.addAnsi("").newLine; // instead of MFN list
        auto response = execute(query);
        auto result = strip (response.readRemainingUtfText);
        return result;
    } // method printTable

    /**
     * Read the MNU-file from the server.
     */
    MenuFile readMenuFile(string specification)
        in (!specification.empty)
    {
        if (!connected)
            return null;

        auto lines = readTextLines(specification);
        if (lines.empty)
            return null;

        auto result = new MenuFile;
        result.parse(lines);
        return result;
    } // method readMenuFile

    /**
     * Read postings for the term.
     */
    TermPosting[] readPostings(const ref PostingParameters parameters) {
        TermPosting[] result;
        if (!connected)
            return result;

        auto db = pickOne(parameters.database, this.database);
        auto query = ClientQuery(this, "I");
        query.addAnsi(db).newLine;
        query.add(parameters.numberOfPostings).newLine;
        query.add(parameters.firstPosting).newLine;
        query.addFormat(parameters.format);
        if (parameters.listOfTerms.empty) {
            foreach (term; parameters.listOfTerms)
                query.addUtf(term).newLine;
        }
        else
            query.addUtf(parameters.term).newLine;
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return result;

        auto lines = response.readRemainingUtfLines;
        result = TermPosting.parse(lines);
        return result;
    }

    /**
     * Read and half-decode the record.
     */
    RawRecord readRawRecord(int mfn, int versionNumber=0) {
        if (!connected)
            return null;

        auto query = ClientQuery(this, "C");
        query.addAnsi(database).newLine();
        query.add(mfn).newLine();
        query.add(versionNumber).newLine();

        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode(-201, -600, -602, -603))
            return null;

        auto result = new RawRecord;
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
        in (mfn > 0)
    {
        if (!connected)
            return null;

        auto query = ClientQuery(this, "C");
        query.addAnsi(database).newLine;
        query.add(mfn).newLine;
        query.add(versionNumber).newLine;
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode(-201, -600, -602, -603))
            return null;

        auto result = new MarcRecord;
        const lines = response.readRemainingUtfLines;
        result.decode(lines);
        result.database = database;

        if (versionNumber != 0)
            unlockRecords(database, [mfn]);

        return result;
    } // method readRecord

    /**
     * Read some records.
     */
    MarcRecord[] readRecords(int[] mfnList) {
        MarcRecord[] result;

        if (!connected || mfnList.empty)
            return result;

        if (mfnList.length == 1) {
            auto record = readRecord(mfnList[0]);
            if (record !is null)
                result ~= record;
        }
        else {
            auto query = ClientQuery(this, "G");
            query.addAnsi(database).newLine;
            query.addAnsi(ALL_FORMAT).newLine;
            query.add(cast(int)mfnList.length).newLine;
            foreach(mfn; mfnList)
                query.add(mfn).newLine();

            auto response = execute(query);
            if (!response.ok || !response.checkReturnCode)
                return result;

            const lines = response.readRemainingUtfLines;
            foreach(line; lines)
                if (!line.empty)
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
        in (number >= 0)
    {
        auto parameters = TermParameters();
        parameters.startTerm = startTerm;
        parameters.numberOfTerms = number;
        return readTerms(parameters);
    } // method readTerms

    /**
     * Read terms from the inverted file.
     */
    TermInfo[] readTerms(const ref TermParameters parameters) {
        if (!connected)
            return [];

        auto command = parameters.reverseOrder ? "P" : "H";
        auto db = pickOne(parameters.database, this.database);
        auto query = ClientQuery(this, command);
        query.addAnsi(db).newLine;
        query.addUtf(parameters.startTerm).newLine;
        query.add(parameters.numberOfTerms).newLine;
        auto prepared = prepareFormat(parameters.format);
        query.addAnsi(prepared).newLine;
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
    string readTextFile(string specification) {
        if (!connected || specification.empty)
            return "";

        auto query = ClientQuery(this, "L");
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
    string[] readTextLines(string specification) {
        if (!connected || specification.empty)
            return [];

        auto query = ClientQuery(this, "L");
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
    TreeFile readTreeFile(string specification) {
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
    bool reloadDictionary(string database) {
        if (!connected)
            return false;

        auto query = ClientQuery(this, "Y");
        query.addAnsi(database).newLine;
        return execute(query).ok;
    } // method reloadDictionary

    /**
     * Recreate master file for the database.
     */
    bool reloadMasterFile(string database) {
        if (!connected)
            return false;

        auto query = ClientQuery(this, "X");
        query.addAnsi(database).newLine;
        return execute(query).ok;
    } // method reloadMasterFile

    /**
     * Restarting the server (without losing the connected clients).
     */
    bool restartServer() {
        if (!connected)
            return false;

        auto query = ClientQuery(this, "+8");
        return execute(query).ok;
    } // method restartServer

    /**
     * Simple search for records (no more than 32k records).
     */
    int[] search(string expression) {
        if (!connected)
            return [];

        if (expression.length == 0)
            return [];

        auto query = ClientQuery(this, "K");
        query.addAnsi(database).newLine;
        query.addUtf(expression).newLine;
        query.add(0).newLine;
        query.add(1).newLine;
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode())
            return [];

        response.readInteger; // count of found records
        const lines = response.readRemainingUtfLines();
        auto result = FoundLine.parseMfn(lines);
        return result;
    } // method search

    /**
     * Extended search for records (no more than 32k records).
     */
    FoundLine[] search(const ref SearchParameters parameters) {
        if (!connected)
            return [];

        auto db = pickOne(parameters.database, this.database);
        auto query = ClientQuery(this, "K");
        query.addAnsi(db).newLine;
        query.addUtf(parameters.expression).newLine;
        query.add(parameters.numberOfRecords).newLine;
        query.add(parameters.firstRecord).newLine;
        query.addFormat(parameters.format);
        query.add(parameters.minMfn).newLine;
        query.add(parameters.maxMfn).newLine;
        query.addAnsi(parameters.sequential).newLine;
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return [];

        response.readInteger(); // count of found records
        auto lines = response.readRemainingUtfLines;
        auto result = FoundLine.parseFull(lines);
        return result;
    } // method search

    /**
     * Search all the records (even if more than 32k records).
     */
    int[] searchAll(string expression) {
        int[] result;
        if (!connected)
            return result;

        auto firstRecord = 1;
        auto totalCount = 0;
        while (true) {
            auto query = ClientQuery(this, "K");
            query.addAnsi(database).newLine;
            query.addUtf(expression).newLine;
            query.add(0).newLine;
            query.add(firstRecord).newLine;
            auto response = execute(query);
            if (!response.ok || !response.checkReturnCode)
                return result;

            if (firstRecord == 1) {
                totalCount = response.readInteger;
                if (totalCount == 0)
                    break;
            }
            else {
                response.readInteger; // eat the line
            }

            auto lines = response.readRemainingUtfLines;
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
    int searchCount(string expression) {
        if (!connected || expression.empty)
            return 0;

        auto query = ClientQuery(this, "K");
        query.addAnsi(database).newLine;
        query.addUtf(expression).newLine;
        query.add(0).newLine;
        query.add(0).newLine;
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return 0;

        auto result = response.readInteger;
        return result;
    } // method searchCount

    /**
     * Search for recods and read found ones
     * (no more than 32k records).
     */
    MarcRecord[] searchRead(string expression, int limit=0)
        in (limit >= 0)
    {
        MarcRecord[] result;
        if (!connected || expression.empty)
            return result;

        SearchParameters parameters;
        parameters.expression = expression;
        parameters.format = ALL_FORMAT;
        parameters.numberOfRecords = limit;
        auto found = search(parameters);
        if ((found is null) || found.empty)
            return result;

        foreach (item; found) {
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
    MarcRecord searchSingleRecord(string expression) {
        auto found = searchRead(expression, 1);
        return found.length != 0 ? found[0] : null;
    } // method searchSingleRecord

    /**
     * Throw exception if last operation completed with error.
     */
    void throwOnError(string file = __FILE__, size_t line = __LINE__) const {
        if (lastError < 0)
            throw new IrbisException(lastError, describeError(lastError), file, line);
    } // method throwOnError

    /**
     * Compose the connection string for current connection.
     * The connection does not have to be established.
     */
    pure string toConnectionString() const {
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
    bool truncateDatabase(string database="") {
        if (!connected)
            return false;

        auto db = pickOne(database, this.database);
        auto query = ClientQuery(this, "S");
        query.addAnsi(db).newLine;
        return execute(query).ok;
    } // method truncateDatabase

    /**
     * Restore the deleted record.
     * If the record isn't deleted, no action taken.
     */
    MarcRecord undeleteRecord(int mfn)
        in (mfn > 0)
    {
        auto result = readRecord(mfn);
        if (result is null)
            return result;

        if (result.deleted)
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
    bool unlockDatabase(string database="")
    {
        if (!connected)
            return false;

        auto db = pickOne(database, this.database);
        auto query = ClientQuery(this, "U");
        query.addAnsi(db).newLine;
        return execute(query).ok;
    } // method unlockDatabase

    /**
     * Unlock the slice of records.
     */
    bool unlockRecords(string database, int[] mfnList) {
        if (!connected)
            return false;

        if (mfnList.empty)
            return true;

        const db = pickOne(database, this.database);
        scope auto query = ClientQuery(this, "Q");
        query.addAnsi(db).newLine;
        foreach(mfn; mfnList)
            query.add(mfn).newLine;
        return execute(query).ok;
    } // method unlockRecords

    /**
     * Update server INI file lines for current user.
     */
    bool updateIniFile(string[] lines) {
        if (!connected)
            return false;

        if (lines.empty)
            return true;

        scope auto query = ClientQuery(this, "8");
        foreach (line; lines)
            query.addAnsi(line).newLine;
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
        scope auto query = ClientQuery(this, "D");
        query.addAnsi(db).newLine;
        query.add(lockFlag).newLine;
        query.add(actualize).newLine;
        query.addUtf(record.encode).newLine;
        scope auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
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
        scope auto query = ClientQuery(this, "D");
        query.addAnsi(db).newLine;
        query.add(lockFlag).newLine;
        query.add(actualize).newLine;
        query.addUtf(record.encode).newLine;
        scope auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return 0;

        if (!dontParse) {
            record.fields = [];
            auto temp = response.readRemainingUtfLines;
            auto lines = [temp[0]];
            lines ~= split(temp[1], SHORT_DELIMITER);
            record.decode(lines);
            record.database = database;
        } // if (!dontParse)

        return response.returnCode;
    } // method writeRecord

    /**
     * Write the slice of records to the server.
     */
    bool writeRecords
        (
            MarcRecord[] records,
            bool lockFlag = false,
            bool actualize = true,
            bool dontParse = false
        )
    {
        if (!connected || records.empty)
            return false;

        if (records.length == 1) {
            writeRecord(records[0]);
            return true;
        }

        scope auto query = ClientQuery(this, "6");
        query.add(lockFlag).newLine;
        query.add(actualize).newLine;
        foreach (record; records) {
            auto db = pickOne(record.database, this.database);
            query.addUtf(db)
                .addUtf(IRBIS_DELIMITER)
                .addUtf(record.encode)
                .newLine;
        }
        scope auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return false;

        if (!dontParse) {
            auto lines = response.readRemainingUtfLines;
            foreach (i, line; lines) {
                if (line.empty)
                    continue;
                auto record = records[i];
                record.clear;
                record.database = pickOne(record.database, this.database);
                auto recordLines = irbisToLines(line);
                record.decode(recordLines);
            }
        } // if (!dontParse)

        return true;
    } // method writeRecords

    /**
     * Write the text file to the server.
     */
    bool writeTextFile(string specification)
        in (!specification.empty)
    {
        if (!connected)
            return false;

        scope auto query = ClientQuery(this, "L");
        query.addAnsi(specification);
        return execute(query).ok;
    } // method writeTextFile

} // class Connection
