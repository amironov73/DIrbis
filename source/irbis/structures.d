/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

module irbis.structures;

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

import irbis.constants, irbis.utils, irbis.menus;

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

    private static int[] parseLine(string line) {
        int[] result;
        auto parts = split(line, SHORT_DELIMITER);
        foreach(item; parts) {
            if (!item.empty) {
                const mfn = parseInt(item);
                if (mfn != 0)
                    result ~= mfn;
            }
        }
        return result;
    }

    /**
     * Parse the server response.
     */
    void parse(string[] lines) {
        logicallyDeletedRecords = parseLine(lines[0]);
        physicallyDeletedRecords = parseLine(lines[1]);
        nonActualizedRecords = parseLine(lines[2]);
        lockedRecords = parseLine(lines[3]);
        maxMfn = parseInt(lines[4]);
        databaseLocked = parseInt(lines[5]) != 0;
    }

    /**
     * Parse the menu.
     */
    static DatabaseInfo[] parseMenu(const MenuFile menu) {
        DatabaseInfo[] result;

        foreach(entry; menu.entries) {
            string entryName = entry.code;
            if ((entryName.length == 0) || entryName.startsWith("*****"))
                break;

            auto description = entry.comment;
            auto readOnly = false;
            if (entryName[0] == '-') {
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

    override string toString() const {
        return name;
    } // method toString

} // class DatabaseInfo

//==================================================================

/**
 * Information about server process.
 */
final class ProcessInfo
{
    string number; /// Just sequential number.
    string ipAddress; /// Client IP address.
    string name; /// User name
    string clientId; /// Client identifier.
    string workstation; /// Workstation kind.
    string started; /// Started at.
    string lastCommand; /// Last executed command.
    string commandNumber; /// Command number.
    string processId; /// Process identifier.
    string state; /// Process state.

    /**
     * Parse the textual representation.
     */
    static ProcessInfo[] parse(string[] lines) {
        ProcessInfo[] result;
        if (lines.empty)
            return result;

        const processCount = parseInt(lines[0]);
        const linesPerProcess = parseInt(lines[1]);
        if ((processCount == 0) || (linesPerProcess == 0))
            return result;

        lines = lines[2..$];
        for (auto i = 0; i < processCount; i++) {
            auto process = new ProcessInfo;
            process.number = lines[0];
            process.ipAddress = lines[1];
            process.name = lines[2];
            process.clientId = lines[3];
            process.workstation = lines[4];
            process.started = lines[5];
            process.lastCommand = lines[6];
            process.commandNumber = lines[7];
            process.processId = lines[8];
            process.state = lines[9];

            result ~= process;
            lines = lines[linesPerProcess..$];
        }

        return result;
    } // method parse

    pure override string toString() const {
        return format("%s %s %s", number, ipAddress, name);
    } // method toString

} // class ProcessInfo

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
    this() {
        organization = "";
        serverVersion = "";
        maxClients = 0;
        connectedClients = 0;
    }

    /**
     * Parse the server response.
     */
    void parse(string[] lines) {
        if (lines.length == 3) {
            serverVersion = lines[0];
            connectedClients = to!int(lines[1]);
            maxClients = to!int(lines[2]);
        }
        else {
            organization = lines[0];
            serverVersion = lines[1];
            connectedClients = to!int(lines[2]);
            maxClients = to!int(lines[3]);
        }
    } // method parse

} // class VersionInfo

//==================================================================

/**
 * Information about the registered user of the system
 * (according to client_m.mnu).
 */
struct UserInfo
{
    string number; /// Just sequential number.
    string name; /// User login.
    string password; /// User password.
    string cataloger; /// Have access to Cataloger?
    string reader; /// Have access to Reader?
    string circulation; /// Have access to Circulation?
    string acquisitions; /// Have access to Acquisitions?
    string provision; /// Have access to Provision?
    string administrator; /// Have access to Administrator?

    pure private static string formatPair
        (
            string prefix,
            string value,
            string defaultValue
        )
        in (!prefix.empty)
        in (!defaultValue.empty)
    {
        if (sameString(value, defaultValue)) {
            return "";
        }
        return prefix ~ "=" ~ value ~ ";";
    }

    /**
     * Encode to the text representation.
     */
    pure string encode() const {
        return name ~ "\n"
            ~ password ~ "\n"
            ~ formatPair("C", cataloger,     "irbisc.ini")
            ~ formatPair("R", reader,        "irbisr.ini")
            ~ formatPair("B", circulation,   "irbisb.ini")
            ~ formatPair("M", acquisitions,  "irbism.ini")
            ~ formatPair("K", provision,     "irbisk.ini")
            ~ formatPair("A", administrator, "irbisa.ini");
    } // method encode

    /**
     * Parse the server response.
     */
    static UserInfo[] parse (string[] lines)
    {
        UserInfo[] result;
        const userCount = parseInt(lines[0]);
        const linesPerUser = parseInt(lines[1]);
        if (!userCount || !linesPerUser)
            return result;

        lines = lines[2..$];
        reserve(result, userCount);
        for (int i = 0; i < userCount; i++) {
            if ((lines.length < 9) || (lines[0].empty))
                break;

            UserInfo user;
            user.number = lines[0];
            user.name = lines[1];
            user.password = lines[2];
            user.cataloger = lines[3];
            user.reader = lines[4];
            user.circulation = lines[5];
            user.acquisitions = lines[6];
            user.provision = lines[7];
            user.administrator = lines[8];
            result ~= user;

            lines = lines[linesPerUser + 1 .. $];
        }

        return result;
    } // method parse

    pure string toString() const nothrow {
        return name;
    } // method toString

} // struct UserInfo

//==================================================================

/**
 * Parameters for search method.
 */
struct SearchParameters
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

    pure string toString() const nothrow {
        return expression;
    } // method toString

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
    void parse(string text) {
        auto parts = split2(text, "#");
        mfn = parseInt(parts[0]);
        if (parts.length > 1)
            description = parts[1];
    } // method parse

    /**
     * Parse server response for descriptions.
     */
    static string[] parseDesciptions(const string[] lines) {
        string[] result;
        result.reserve(lines.length);
        foreach(line; lines) {
            if (line.length != 0) {
                auto index = indexOf(line, '#');
                if (index >= 0) {
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
    static FoundLine[] parseFull(const string[] lines) {
        FoundLine[] result;
        result.reserve(lines.length);
        foreach(line; lines) {
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
    static int[] parseMfn(const string[] lines) {
        int[] result;
        result.reserve(lines.length);
        foreach(line; lines) {
            if (line.length != 0)
            {
                auto item = parseInt(split(line, "#")[0]);
                result ~= item;
            }
        }

        return result;
    } // method parseMfn

    /// Test for parseMfn
    unittest {
        const arr = ["1#", "2#", "3"];
        const expected = [1, 2, 3];
        const actual = parseMfn(arr);
        assert(expected == actual);
    } // unittest

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
    static TermPosting[] parse(string[] lines)
    {
        TermPosting[] result;
        foreach(line; lines)
        {
            auto parts = splitN(line, "#", 5);
            if (parts.length < 4)
                break;

            TermPosting item;
            item.mfn = parseInt(parts[0]);
            item.tag = parseInt(parts[1]);
            item.occurrence = parseInt(parts[2]);
            item.count = parseInt(parts[3]);
            item.text = parts[4];
            result ~= item;
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
    } // method toString
} // class TermPosting

//==================================================================

/**
 * Parameters for readTerms method.
 */
struct TermParameters
{
    string database; /// Database name.
    int numberOfTerms; /// Number of terms to read.
    bool reverseOrder; /// Return terms in reverse order?
    string startTerm; /// Start term.
    string format; /// Format specification (optional).

    pure string toString() const nothrow {
        return startTerm;
    } // method toString

} // class TermParameters

//==================================================================

/**
 * Parameters for posting reading.
 */
struct PostingParameters
{
    string database; /// Database name.
    int firstPosting = 1; /// Number of first posting.
    string format; /// Format specification (optional).
    int numberOfPostings; /// Required numer of posting.
    string term; /// Search term.
    string[] listOfTerms; /// List of terms.

    pure string toString() const nothrow {
        return term;
    } // method toString
}

//==================================================================

/**
 * Data for printTable method.
 */
struct TableDefinition
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

    pure string toString() const nothrow {
        return table;
    } // method toString

} // class TableDefinition

//==================================================================

/**
 * Information about connected client
 * (not necessarily current client).
 */
final class ClientInfo
{
    string number; /// Sequential number.
    string ipAddress; /// Client IP address.
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
    void parse(string[] lines) {
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

    pure override string toString() const {
        return ipAddress;
    } // method toString
} // class ClientInfo

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
    void parse(string[] lines) {
        totalCommandCount = parseInt(lines[0]);
        clientCount = parseInt(lines[1]);
        auto linesPerClient = parseInt(lines[2]);
        lines = lines[3..$];
        for(int i = 0; i < clientCount; i++)
        {
            auto client = new ClientInfo;
            client.parse(lines);
            runningClients ~= client;
            lines = lines[linesPerClient + 1..$];
        } // for
    } // method parse

    pure override string toString() const {
        auto result = new OutBuffer;
        result.put(to!string(totalCommandCount));
        result.put("\n");
        result.put(to!string(clientCount));
        result.put("\n8\n");
        foreach(client; runningClients) {
            result.put(client.toString());
            result.put("\n");
        }
        return result.toString();
    } // method toString

} // class ServerStat

//==================================================================

/**
 * Statement of global correction.
 */
final class GblStatement
{
    string command; /// Command, e. g. ADD or DEL.
    string parameter1; /// First parameter, e. g. field specification.
    string parameter2; /// Second parameter, e. g. repeat specification.
    string format1; /// First format, e. g. expression to search.
    string format2; /// Second format, e. g. value for replacement.

    /**
     * Encode the statement.
     */
    pure string encode(string delimiter=IRBIS_DELIMITER) const {
        return command ~ delimiter
            ~ parameter1 ~ delimiter
            ~ parameter2 ~ delimiter
            ~ format1 ~ delimiter
            ~ format2 ~ delimiter;
    } // method encode

    pure override string toString() const {
        return encode("\n");
    } // method toString

} // class GblStatement

/**
 * Settings for global correction.
 */
final class GblSettings
{
    bool actualize; /// Actualize records?
    bool autoin; /// Run autoin.gbl?
    string database; /// Database name.
    string filename; /// File name.
    int firstRecord; /// MFN of first record.
    bool formalControl; /// Apply formal control?
    int maxMfn; /// Maximal MFN.
    int[] mfnList; /// List of MFN to process.
    int minMfn; /// Minimal MFN.
    int numberOfRecords; /// Number of records to process.
    string searchExpression; /// Search expression.
    GblStatement[] statements; /// Slice of statements.
}
