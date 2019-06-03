/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

module irbis.iso;

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

import irbis.utils, irbis.records;

//==================================================================

const ISO_MARKER_LENGTH      = 24; /// ISO2709 record marker length, bytes.
const ISO_RECORD_DELIMITER   = cast(ubyte)0x1D; /// Record delimiter.
const ISO_FIELD_DELIMITER    = cast(ubyte)0x1E; /// Field delimiter.
const ISO_SUBFIELD_DELIMITER = cast(ubyte)0x1F; /// Subfield delimiter.

//==================================================================

private void encodeInt32(ubyte[] buffer, int position, int length, int value) {
    length--;
    for (position += length; length >= 0; length--) {
        buffer[position] = cast(ubyte)((value % 10) + 48);
        value /= 10;
        position--;
    }
} // encodeInt32

private int encodeText(ubyte[] buffer, int position, string text) {
    if (!text.empty) {
        const encoded = cast(ubyte[])text;
        for (int i = 0; i < encoded.length; i++) {
            buffer[position] = encoded[i];
            position++;
        }
    }
    return position;
} // encodeText

private void decodeField(RecordField field, string bodyText) {
    auto all = split(bodyText, ISO_SUBFIELD_DELIMITER);
    if (bodyText[0] != ISO_SUBFIELD_DELIMITER) {
        field.value = to!string(all[0]);
        all = all[1..$];
    }
    field.subfields.reserve(all.length);
    foreach(one; all) {
        if (!one.empty) {
            auto subfield = new SubField();
            subfield.decode(one);
            field.subfields ~= subfield;
        }
    }
} // decodeField

/**
 * Read ISO2709 record from the file.
 */
export MarcRecord readIsoRecord(File file, string function (ubyte[]) decoder) {
    auto result = new MarcRecord;
    auto marker = file.rawRead(new ubyte[5]);
    if (marker.length != 5)
        return null;

    const recordLength = parseInt(marker);
    auto record = new ubyte[recordLength];
    record.reserve(recordLength);
    const readed = file.rawRead(record[5..$]);
    if (readed.length + 5 != recordLength)
        return null;

    if (record[$-1] != ISO_RECORD_DELIMITER) {
        return null;
    }

    const lengthOfLength = parseInt(record[20..21]);
    const lengthOfOffset = parseInt(record[21..22]);
    const additionalData = parseInt(record[22..23]);
    const directoryLength = 3 + lengthOfLength + lengthOfOffset + additionalData;
    const indicatorLength = parseInt(record[10..11]);
    const baseAddress = parseInt(record[12..17]);

    int fieldCount = 0;
    for (int ofs = ISO_MARKER_LENGTH; ; ofs += directoryLength) {
        if (record[ofs] == ISO_FIELD_DELIMITER)
            break;
        fieldCount++;
    }
    result.fields.reserve(fieldCount);

    for (int directory = ISO_MARKER_LENGTH; ; directory += directoryLength) {
        if (record[directory] == ISO_FIELD_DELIMITER)
            break;

        const tag = parseInt(record[directory..directory+3]);
        int ofs = directory + 3;
        const fieldLength = parseInt(record[ofs..ofs+lengthOfLength]);
        ofs = directory + 3 + lengthOfLength;
        const fieldOffset = baseAddress + parseInt(record[ofs..ofs+lengthOfOffset]);
        auto field = new RecordField(tag);
        if (tag < 10) {
            auto temp = record[fieldOffset..fieldOffset + fieldLength];
            field.value = decoder(temp);
        }
        else {
            const start = fieldOffset + indicatorLength;
            const stop = fieldOffset + fieldLength - indicatorLength;
            auto temp = record[start..stop];
            auto text = decoder(temp);
            decodeField(field, text);
        }
        result.fields ~= field;

    }

    return result;
} // readIsoRecord

/// Test for readIsoRecord
unittest {
    auto file = File("data/test1.iso");
    scope(exit) file.close();
    const record = readIsoRecord(file, &fromAnsi);
    //assert(record.fm(1) == "RU\\NLR\\bibl\\3415");
    assert(record.fm(801, 'a') == "RU");
    assert(record.fm(801, 'b') == "NLR");
} // unittest
