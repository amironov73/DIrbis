/*
 * Simple program that removes all completed orders
 * from the RQST database (to reduce network traffic
 * from the Book Loan Workstation).
 */

import std.datetime;
import std.stdio;
import irbis;

void main(string[] args) {
    if (args.length != 2) {
        writeln("USAGE: ", args[0], " <connectionString>");
        return;
    }

    const stopwatch = StopWatch(AutoStart.yes);
    auto connectionString = args[0];
    auto client = new Connection();
    client.parseConnectionString(connectionString);

    if (!client.connect) {
        writeln("Can't connect!");
        return;
    }

    scope (exit)
        client.disconnect();

    if (client.workstation != ADMINISTRATOR) {
        writeln("Not administrator, exiting");
        return;
    }

    const maxMfn = client.getMaxMfn(client.database);
    auto expression = `"I=0" + "I=2"`;
    auto found = client.searchAll(expression);
    if (found.length == maxMfn) {
        writeln("No truncation needed, exiting");
        return;
    }

    auto goodRecords = client.readRecords(found);
    writeln("Good records loaded: ", goodRecords.length);
    foreach (record; goodRecords) {
        record.reset;
        record.database = client.database;
    }

    client.truncateDatabase(client.database);
    if (client.getMaxMfn(client.database) > 1) {
        writeln("Error while truncating database, exiting");
        return;
    }

    client.writeRecords(goodRecords);
    writeln("Good records restored");

    stopwatch.stop;
    auto elapsed = stopwatch.peek.seconds;
    writeln("Elapsed seconds: ", elapsed);
}
