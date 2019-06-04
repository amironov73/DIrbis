import std.stdio;
import std.string;
import std.algorithm.sorting;
import std.path : buildPath;
static import std.file;
import irbis;

void main() {
    auto client = new Connection;
    client.host = "localhost";
    client.username = "librarian";
    client.password = "secret";

    if (!client.connect()) {
        writeln("Can't connect!");
        writeln(describeError(client.lastError));
        return;
    }

    scope(exit) client.disconnect();

    writeln("Server version=", client.serverVersion);
    writeln("Interval=", client.interval);

    // INI-file
    {
        auto ini = client.ini;
        auto dbnnamecat = ini.getValue("Main", "DBNNAMECAT", "???");
        writeln("DBNNAMECAT=", dbnnamecat);
    }

    // Max MFN
    {
        auto maxMfn = client.getMaxMfn("IBIS");
        writeln("Max MFN=", maxMfn);
    }

    client.noOp;

    // Server version
    {
        auto serverVersion = client.getServerVersion;
        writeln("Organization=", serverVersion.organization);
    }

    // Server stat
    {
        auto stat = client.getServerStat;
        write(stat);
    }

    // Server process list
    {
        auto processes = client.listProcesses;
        writeln(processes);
    }

    // Server database list
    {
        auto databases = client.listDatabases;
        writeln(databases);
    }

    // Server database info
    {
        auto databaseInfo = client.getDatabaseInfo;
        writeln("Logically deleted records: ", databaseInfo.logicallyDeletedRecords);
    }

    // User list
    {
        auto users = client.getUserList;
        sort!((a, b) => cmp(a.name, b.name) < 0)(users);
        writeln(users);
    }

    // Read text file from the server
    {
        auto content = client.readTextFile("3.IBIS.WS.OPT");
        writeln(content);
    }

    // Format one record
    {
        auto content = client.formatRecord("@brief", 123);
        writeln(content);
    }

    // Format some records
    {
        auto contentLines = client.formatRecords("@brief", 1, 2, 3);
        writeln(contentLines);
    }

    // Read record from server
    {
        auto record = client.readRecord(123);
        writeln(record);
    }

    // Read MNU file
    {
        auto menu = client.readMenuFile("3.IBIS.FORMATW.MNU");
        writeln(menu);
    }

    // List files on the server
    {
        auto files = client.listFiles("3.IBIS.brief.*", "3.IBIS.a*.pft");
        writeln(files);
    }

    // Count found records
    {
        auto count = client.searchCount(`"A=ПУШКИН$"`);
        writeln("COUNT=", count);
    }

    // Simple record search
    {
        auto found = client.search(`"A=ПУШКИН$"`);
        writeln(found);
    }

    // Search all the records
    {
        auto found = client.searchAll(`"K=БЕТОН$"`);
        writeln(found);
    }

    // Read terms
    {
        auto terms = client.readTerms("J=", 10);
        writeln(terms);
    }

    // List terms
    {
        auto allTerms = client.listTerms("J=");
        writeln(allTerms);
    }

    // Format virtual record
    {
        auto record = new MarcRecord();
        record
            .append(200)
            .append('a', "Title")
            .append('e', "Subtitle")
            .append('f', "Responsibility");
        auto format = "v200^a, | : |v200^e, | / |v200^f";
        auto text = client.formatRecord(format, record);
        writeln(text);
    }

    // Search and read records
    {
        auto records = client.searchRead(`"K=БЕТОН"`);
        foreach (rec; records)
            write(rec.fm(200, 'a'), " ||| ");
        writeln;
    }

    // Database stat
    {
        auto item = StatItem("v200^a", 10, 100, SORT_ASCENDING);
        auto definition = new StatDefinition;
        definition.database = "IBIS";
        definition.searchExpression = `"T=A$"`;
        definition.items ~= item;
        auto text = client.getDatabaseStat(definition);
        auto fname = std.file.tempDir.buildPath("stat.rtf");
        writeln(fname);
        writeln(text);
        std.file.write(fname, toAnsi(text));
    }

    // read binary file from the server
    {
        auto spec = FileSpecification.system("logo.gif");
        writeln(spec);
        ubyte[] fileContent = client.readBinaryFile(spec);
        auto fname = std.file.tempDir.buildPath("logo.gif");
        writeln(fname);
        std.file.write(fname, fileContent);
    }

    writeln;
    writeln("THAT'S ALL, FOLKS!");
}
