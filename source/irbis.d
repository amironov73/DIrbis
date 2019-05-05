import std.stdio;
import std.encoding: transcode, Windows1251String;
import std.random: uniform;
import std.socket;

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

final class ClientQuery
{
    this(Connection connection, string command)
    {
        // TODO implement
    }

    ClientQuery addAnsi(string text)
    {
        return this;
    }

    ClientQuery addUtf(string text)
    {
        return this;
    }

    ClientQuery newLine()
    {
        return this;
    }
}

//==================================================================

final class ServerResponse
{
    string command;
    int clientId;
    int queryId;
    int answerSize;
    int returnCode;
    string serverVersion;
    int interval;

    bool checkReturnCode()
    {
        return false;
    }

    ubyte[] getLine()
    {
        return new ubyte[0];
    }

    int getReturnCode()
    {
        return 0;
    }

    string readAnsi()
    {
        return "";
    }

    int readInteger()
    {
        return 0;
    }

    string[] readRemainingAnsiLines()
    {
        return new string[0];
    }

    string readRemainingAnsiText()
    {
        return "";
    }

    string[] readRemainingUtfLines()
    {
        return new string[0];
    }

    string readRemainingUtfText()
    {
        return "";
    }

    string readUtf()
    {
        return "";
    }
}

//==================================================================

final class Connection
{
    string host;
    uint port;
    string username;
    string password;
    string database;
    string workstation;
    int clientId;
    int queryId;
    string serverVersion;
    int interval;
    bool connected;

    this()
    {
        host = "127.0.0.1";
        port = 6666;
        database = "IBIS";
        workstation = "C";
    }

    bool connect()
    {
        if (connected)
        {
            return true;
        }

        clientId = 123456;
        queryId = 1;
        auto query = new ClientQuery(this, "A");
        query.addAnsi(username).newLine();
        query.addAnsi(password);
        auto response = execute(query);

        connected = true;
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
        connected = false;

        return true;
    }

    ServerResponse execute(ClientQuery query)
    {
        return new ServerResponse();
    }

    int getMaxMfn(string database)
    {
        if (!connected)
        {
            return 0;
        }

        auto query = new ClientQuery(this, "O");
        query.addAnsi(database);
        auto response = execute(query);

        return response.returnCode;
    }

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
}

//==================================================================

