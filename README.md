# DIrbis

ManagedClient ported to D language

Currently supporting:

* DMD 2.082
* 32-bit and 64-bit Windows

### Build status

[![Build status](https://img.shields.io/appveyor/ci/AlexeyMironov/dirbis.svg)](https://ci.appveyor.com/project/AlexeyMironov/dirbis/)

### Sample program

```d
import std.stdio;
import irbis;

void main()
{
    // Connect to the server
    auto client = new Connection();
    client.host = "localhost";
    client.username = "librarian";
    client.password = "secret";

    if (!client.connect())
    {
        writeln("Can't connect!");
        return;
    }

    // Will be disconnected at exit
    scope(exit) client.disconnect();

    // General server information
    writeln("Server version=", client.serverVersion);
    writeln("Interval=", client.interval);
    
    // Proposed client settings from INI-file
    auto ini = client.ini;
    auto dbnnamecat = ini.getValue("Main", "DBNNAMECAT", "???");
    writeln("DBNNAMECAT=", dbnnamecat);
    
    // Search for books written by Byron
    auto found = client.search("\"A=Byron, George$\"");
    writeln("Records found: ", found);

    // get database list from the server
    auto databases = client.listDatabases();
    writeln(databases);

    // get file content from the server
    auto content = client.readTextFile("3.IBIS.WS.OPT");
    writeln(content);

    // read MNU-file from the server
    auto menu = client.readMenuFile("3.IBIS.FORMATW.MNU");
    writeln(menu);

    // list server files
    auto files = client.listFiles("3.IBIS.brief.*", "3.IBIS.a*.pft");
    writeln(files);

	foreach(mfn; found) 
	{
        // Read the record
        auto record = client.readRecord(mfn);

        // Get field/subfield value
        auto title = record.fm(200, 'a');
        writeln("Title: ", title);

        // Formatting (at the server)
        auto description = client.formatRecord("@brief", mfn);
        writeln("Description: ", description);
	}    
}
```