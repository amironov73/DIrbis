/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

module irbis.plain;

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

import irbis.records;

//==================================================================

/// Export the record in plain text format.
void exportPlainText(const MarcRecord record, File file) {
    file.write(record.toPlainText);
    file.writeln("*****");
} // exportPlainText

/// Convert the record to plain text format.
string toPlainText(const MarcRecord record) {
    auto result = new OutBuffer();
    foreach (field; record.fields) {
        result.write(to!string(field.tag));
        result.write("#");
        result.write(field.value);
        foreach (subfield; field.subfields)
            result.write(subfield.toString);
        result.write("\n");
    }
    return result.toString();
} // toPlainText

/// Test for toPlainText
unittest {
    auto record = new MarcRecord();
    assert(record.toPlainText.empty);
    record.append(200)
        .append('a', "Title")
        .append('e', "subtitle")
        .append('f', "Responsibility");
    assert(record.toPlainText == "200#^aTitle^esubtitle^fResponsibility\n");
    record.append(300, "Comment");
    assert(record.toPlainText == "200#^aTitle^esubtitle^fResponsibility\n300#Comment\n");
} // unittest
