import std.stdio;
import irbis;

void testEncodings()
{
    writeln(toAnsi("Hello"));
    writeln(fromAnsi([72, 101, 108, 108, 111]));
    writeln(toUtf("Hello"));
    writeln(fromUtf([72, 101, 108, 108, 111]));
    writeln(toAnsi("Привет!"));
    writeln(fromAnsi([207, 240, 232, 226, 229, 242, 33]));
    writeln(toUtf("Привет!"));
    writeln(fromUtf([208, 159, 209, 128, 208, 184, 208, 178, 208, 181, 209, 130, 33]));
}

void main()
{
    auto client = new Connection();
    client.username = "librarian";
    client.password = "secret";

    if (!client.connect())
    {
        writeln("Can't connect!");
        return;
    }

    scope(exit) client.disconnect();

    writeln("Server version=", client.serverVersion);
    writeln("Interval=", client.interval);

    auto maxMfn = client.getMaxMfn("IBIS");
    writeln("Max MFN=", maxMfn);

    client.noOp();

    auto serverVersion = client.getServerVersion();
    writeln("Organization:", serverVersion.organization);

    auto databases = client.listDatabases();
    writeln(databases);

    auto content = client.readTextFile("3.IBIS.WS.OPT");
    writeln(content);

    content = client.formatRecord("@brief", 123);
    writeln(content);

    auto record = client.readRecord(123);
    writeln(record);

    auto menu = client.readMenuFile("3.IBIS.FORMATW.MNU");
    writeln(menu);

    auto files = client.listFiles("3.IBIS.brief.*", "3.IBIS.a*.pft");
    writeln(files);

    auto count = client.searchCount("\"A=ПУШКИН$\"");
    writeln("COUNT=", count);

    auto found = client.search("\"A=ПУШКИН$\"");
    writeln(found);

    auto terms = client.readTerms("J=", 10);
    writeln(terms);
}
