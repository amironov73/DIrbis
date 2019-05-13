import std.stdio;
import irbis;

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

    auto ini = client.ini;
    auto dbnnamecat = ini.getValue("Main", "DBNNAMECAT", "???");
    writeln("DBNNAMECAT=", dbnnamecat);

    auto maxMfn = client.getMaxMfn("IBIS");
    writeln("Max MFN=", maxMfn);

    client.noOp();

    auto serverVersion = client.getServerVersion();
    writeln("Organization:", serverVersion.organization);

    auto stat = client.getServerStat();
    write(stat);

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

    auto count = client.searchCount(`"A=ПУШКИН$"`);
    writeln("COUNT=", count);

    auto found = client.search(`"A=ПУШКИН$"`);
    writeln(found);

    found = client.searchAll(`"K=БЕТОН$"`);
    writeln(found);

    auto terms = client.readTerms("J=", 10);
    writeln(terms);

    record = new MarcRecord();
    record
        .append(200)
        .append('a', "Title")
        .append('e', "Subtitle")
        .append('f', "Responsibility");
    auto format = "v200^a, | : |v200^e, | / |v200^f";
    auto text = client.formatRecord(format, record);
    writeln(text);

    auto records = client.searchRead(`"K=БЕТОН"`);
    foreach (rec; records)
        write(rec.fm(200, 'a'), " ||| ");
    writeln();
}
