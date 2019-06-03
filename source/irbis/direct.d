/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

module irbis.direct;

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

const XRF_RECORD_SIZE = 12; /// Size of XRF file record, bytes.
const MST_CONTROL_RECORD_SIZE = 36; /// Size of MST file control record, bytes.

//==================================================================

/**
 * Record in the XRF-file.
 */
struct XrfRecord
{
    int low; /// Low part of the offset.
    int high; /// High part of the offset.
    int status; /// Record status.

    /// Compute offset the record.
    pure long offset() const nothrow {
        return ((cast(long)high) << 32) + (cast(long)low);
    } // method offset

} // struct XrfRecord

/**
 * Encapsulates XRF-file.
 */
export final class XrfFile
{
    private File file;

    /// Constructor.
    this(string fileName) {
        file = File(fileName, "r");
    } // constructor

    ~this() {
        file.close();
    } // destructor

    /// Get offset for the record by MFN.
    pure long getOffset(int mfn) const {
        return (cast(long)(mfn - 1)) * cast(long)XRF_RECORD_SIZE;
    } // method getOffset

    /**
     * Read XRF record.
     */
    XrfRecord readRecord(int mfn) {
        XrfRecord result;
        const offset = getOffset(mfn);
        file.seek(offset);
        result.low = file.readIrbisInt32;
        result.high = file.readIrbisInt32;
        result.status = file.readIrbisInt32;
        return result;
    } // method readRecord

} // class XrfFile

/**
 * Leader of the MST-file record.
 */
struct MstLeader
{
    int mfn; /// Sequential number of the record.
    int length; /// Length of the record, bytes.
    int previousLow; /// Reference to previous version of the record (low part).
    int previousHigh; /// Reference to previous version of the recort (high part).
    int base; /// Base offset of the field layout.
    int nvf; /// Number of variable length field.
    int versionNumber; /// Version number of the record.
    int status; /// Record status.

    /// Compute the offset of previous version of the record.
    pure long previousOffset() const nothrow {
        return ((cast(long)previousHigh) << 32) + (cast(long)previousLow);
    } // method previousOffset

} // struct MstLeader

/**
 * Entry in the MST dictionary.
 */
struct MstDictionaryEntry
{
    int tag; /// Field tag.
    int position; /// Offset of the field data.
    int length; /// Length of the field data.
} // struct MstDictionaryEntry

/**
 * Field of the MST-record.
 */
struct MstField
{
    int tag; /// Field tag.
    string text; /// Field value (not parsed for subfields).

    /**
     * Decode the field.
     */
    RecordField decode() {
        auto result = new RecordField(tag);
        result.decodeBody(text);
        return result;
    } // method decode

} // struct MstField

/**
 * Record of MST-file.
 */
final class MstRecord
{
    MstLeader leader; /// Leader of the record.
    MstDictionaryEntry[] dictionary; /// Dictionary of the record.
    MstField[] fields; /// Fields.

    /**
     * Decode to MarcRecord.
     */
    MarcRecord decode() {
        auto result = new MarcRecord();
        result.mfn = leader.mfn;
        result.status = leader.status;
        result.versionNumber = leader.versionNumber;
        reserve(result.fields, this.fields.length);
        for (int i = 0; i < fields.length; i++) {
            result.fields[i] = this.fields[i].decode;
        }
        return result;
    } // method decode

} // class MstRecord

/**
 * Control record of the MST-file.
 */
struct MstControlRecord
{
    int ctlMfn; /// Reserved.
    int nextMfn; /// MFN to be assigned for next record created.
    int nextPositionLow; /// Pointer to free space (low part).
    int nextPositionHigh; /// Pointer to free spece (high part).
    int mftType; /// Reserved.
    int recCnt; /// Reserved.
    int reserv1; /// Reserved.
    int reserv2; /// Reserved.
    int blocked; /// Database locked indicator.

    /// Calculate offset of free space.
    pure long nextPosition() const nothrow {
        return ((cast(long)nextPositionHigh) << 32) + (cast(long)nextPositionLow);
    } // method nextPosition

} // struct MstControlRecord

/**
 * Encapsulates MST-file.
 */
export class MstFile
{
    private File file;
    MstControlRecord control; /// Control record.

    /// Constructor.
    this (string fileName) {
        // TODO implement
    } // constructor

    /// Destructor.
    ~this() {
    } // destructor

    /**
     * Read record from specified position.
     */
    MstRecord readRecord(long position) {
        // TODO implement
        return null;
    }
}
