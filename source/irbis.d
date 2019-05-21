/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

//==================================================================

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

//==================================================================
//
// Constants
//

// Record status

const LOGICALLY_DELETED  = 1;  /// Logically deleted record.
const PHYSICALLY_DELETED = 2;  /// Physically deleted record.
const ABSENT             = 4;  /// Record is absent.
const NON_ACTUALIZED     = 8;  /// Record is not actualized.
const LAST_VERSION       = 32; /// Last version of the record.
const LOCKED_RECORD      = 64; /// Record is locked.

// Common formats

const ALL_FORMAT       = "&uf('+0')";  /// Full data by all the fields.
const BRIEF_FORMAT     = "@brief";     /// Short bibliographical description.
const IBIS_FORMAT      = "@ibiskw_h";  /// Old IBIS format.
const INFO_FORMAT      = "@info_w";    /// Informational format.
const OPTIMIZED_FORMAT = "@";          /// Optimized format.

// Common search prefixes

const KEYWORD_PREFIX    = "K=";  /// Keywords.
const AUTHOR_PREFIX     = "A=";  /// Individual author, editor, compiler.
const COLLECTIVE_PREFIX = "M=";  /// Collective author or event.
const TITLE_PREFIX      = "T=";  /// Title.
const INVENTORY_PREFIX  = "IN="; /// Inventory number, barcode or RFID tag.
const INDEX_PREFIX      = "I=";  /// Document index.

// Logical operators for search

const LOGIC_OR                = 0; /// OR only
const LOGIC_OR_AND            = 1; /// OR or AND
const LOGIC_OR_AND_NOT        = 2; /// OR, AND or NOT (default)
const LOGIC_OR_AND_NOT_FIELD  = 3; /// OR, AND, NOT, AND in field
const LOGIC_OR_AND_NOT_PHRASE = 4; /// OR, AND, NOT, AND in field, AND in phrase

// Workstation codes

const ADMINISTRATOR = "A"; /// Administator
const CATALOGER     = "C"; /// Cataloger
const ACQUSITIONS   = "M"; /// Acquisitions
const READER        = "R"; /// Reader
const CIRCULATION   = "B"; /// Circulation
const BOOKLAND      = "B"; /// Bookland
const PROVISION     = "K"; /// Provision

// Commands for global correction.

const ADD_FIELD        = "ADD";    /// Add field.
const DELETE_FIELD     = "DEL";    /// Delete field.
const REPLACE_FIELD    = "REP";    /// Replace field.
const CHANGE_FIELD     = "CHA";    /// Change field.
const CHANGE_WITH_CASE = "CHAC";   /// Change field with case sensitivity.
const DELETE_RECORD    = "DELR";   /// Delete record.
const UNDELETE_RECORD  = "UNDELR"; /// Recover (undelete) record.
const CORRECT_RECORD   = "CORREC"; /// Correct record.
const CREATE_RECORD    = "NEWMFN"; /// Create record.
const EMPTY_RECORD     = "EMPTY";  /// Empty record.
const UNDO_RECORD      = "UNDOR";  /// Revert to previous version.
const GBL_END          = "END";    /// Closing operator bracket.
const GBL_IF           = "IF";     /// Conditional statement start.
const GBL_FI           = "FI";     /// Conditional statement end.
const GBL_ALL          = "ALL";    /// All.
const GBL_REPEAT       = "REPEAT"; /// Repeat operator.
const GBL_UNTIL        = "UNTIL";  /// Until condition.
const PUTLOG           = "PUTLOG"; /// Save logs to file.

// Line delimiters

const IRBIS_DELIMITER = "\x1F\x1E"; /// IRBIS line delimiter.
const SHORT_DELIMITER = "\x1E";     /// Short version of line delimiter.
const ALT_DELIMITER   = "\x1F";     /// Alternative version of line delimiter.
const UNIX_DELIMITER  = "\n";       /// Standard UNIX line delimiter.

// ISO2709

const ISO_MARKER_LENGTH      = 24; /// ISO2709 record marker length, bytes.
const ISO_RECORD_DELIMITER   = cast(ubyte)0x1D; /// Record delimiter.
const ISO_FIELD_DELIMITER    = cast(ubyte)0x1E; /// Field delimiter.
const ISO_SUBFIELD_DELIMITER = cast(ubyte)0x1F; /// Subfield delimiter.

// MST/XRF

const XRF_RECORD_SIZE = 12; /// Size of XRF file record, bytes.
const MST_CONTROL_RECORD_SIZE = 36; /// Size of MST file control record, bytes.

//==================================================================
//
// Utility functions
//

/// Read 32-bit integer using network byte order.
export int readIrbisInt32(File file) {
    ubyte[4] buffer;
    file.rawRead(buffer);
    return cast(int)
        (((cast(uint)buffer[0])  << 24)
        | ((cast(uint)buffer[1]) << 16)
        | ((cast(uint)buffer[2]) << 8)
        | ((cast(uint)buffer[3]) << 0));
} // readIrbisInt32

/// Read 64-bit integer using IRBIS-specific byte order.
export ulong readIrbisInt64(File file) {
    ubyte[8] buffer;
    file.rawRead(buffer);
    return
        (((cast(ulong)buffer[0])  << 24)
        | ((cast(ulong)buffer[1]) << 16)
        | ((cast(ulong)buffer[2]) << 8)
        | ((cast(ulong)buffer[3]) << 0)
        | ((cast(ulong)buffer[4]) << 56)
        | ((cast(ulong)buffer[5]) << 48)
        | ((cast(ulong)buffer[6]) << 40)
        | ((cast(ulong)buffer[7]) << 32));
} // readIrbisInt64

/// Converts the text to ANSI encoding.
pure ubyte[] toAnsi(string text) {
    Windows1251String encoded;
    transcode(text, encoded);
    return cast(ubyte[])encoded;
}

/// Test for toAnsi
unittest {
    const source = "\u041F\u0440\u0438\u0432\u0435\u0442";
    const actual = toAnsi(source);
    const expected = [207, 240, 232, 226, 229, 242];
    assert(actual == expected);
}

/// Converts the slice of bytes from ANSI encoding to text.
pure string fromAnsi(const ubyte[] text) {
    Windows1251String s = cast(Windows1251String)text;
    string decoded;
    transcode(s, decoded);
    return decoded;
}

// Test for fromAnsi
unittest {
    ubyte[] source = [207, 240, 232, 226, 229, 242];
    const actual = fromAnsi(source);
    const expected = "\u041F\u0440\u0438\u0432\u0435\u0442";
    assert(actual == expected);
}

/// Converts the text to UTF-8 encoding.
pure ubyte[] toUtf(string text) {
    return cast(ubyte[])text;
}

/// Test for toUtf
unittest {
    const source = "\u041F\u0440\u0438\u0432\u0435\u0442";
    const actual = toUtf(source);
    const expected = [208, 159, 209, 128, 208, 184, 208, 178, 208, 181, 209, 130];
    assert(actual == expected);
}

/// Converts the slice of bytes from UTF-8 encoding to text.
pure string fromUtf(const ubyte[] text) {
    return cast(string)text;
}

// Test for fromUtf
unittest {
    ubyte[] source = [208, 159, 209, 128, 208, 184, 208, 178, 208, 181, 209, 130];
    const actual = fromUtf(source);
    const expected = "\u041F\u0440\u0438\u0432\u0435\u0442";
    assert(actual == expected);
}

/// Examines whether the characters are the same.
pure bool sameChar(char c1, char c2) nothrow {
    return toUpper(c1) == toUpper(c2);
}

/// Tesf for sameChar
unittest {
    assert(sameChar('a', 'A'));
    assert(!sameChar('a', 'B'));
}

/// Examines whether the strings are the same.
pure bool sameString(string s1, string s2) {
    return icmp(s1, s2) == 0;
}

/// Test for sameString
unittest {
    assert(sameString("test", "TEST"));
    assert(sameString("test", "Test"));
    assert(!sameString("test", "tset"));
}

/// Convert text from IRBIS representation to UNIX.
string irbisToUnix(string text) {
    return replace(text, IRBIS_DELIMITER, UNIX_DELIMITER);
}

/// Test for irbisToUnix
unittest {
    assert(irbisToUnix("1\x1F\x1E2\x1F\x1E3") == "1\n2\n3");
}

/// Split text to lines by IRBIS delimiter
string[] irbisToLines(string text) {
    return text.split(IRBIS_DELIMITER);
}

/// Test for irbisToLines
unittest {
    const source = "1\x1F\x1E2\x1F\x1E3";
    const expected = ["1", "2", "3"];
    const actual = irbisToLines(source);
    assert (expected == actual);
}

/// Fast parse integer number.
pure int parseInt(ubyte[] text) nothrow {
    int result = 0;
    foreach(c; text)
        result = result * 10 + c - 48;
    return result;
}

/// Test for parseInt(ubyte[])
unittest {
    ubyte[] arr = null;
    assert(parseInt(arr) == 0);
    arr = [49, 50, 51];
    assert(parseInt(arr) == 123);
}

/// Fast parse integer number.
export pure int parseInt(string text) nothrow {
    int result = 0;
    foreach(c; text)
        result = result * 10 + c - 48;
    return result;
}

/// Test for parseInt(string)
unittest {
    assert(parseInt("") == 0);
    assert(parseInt("0") == 0);
    assert(parseInt("1") == 1);
    assert(parseInt("111") == 111);
}

/// Split the text by the delimiter to 2 parts.
pure string[] split2(string text, string delimiter) {
    auto index = indexOf(text, delimiter);
    if (index < 0)
        return [text];

    return [to!string(text[0..index]), to!string(text[index + 1..$])];
}

/// Test for split2
unittest {
    const source = "1#2#3";
    const expected = ["1", "2#3"];
    const actual = split2(source, "#");
    assert(expected == actual);
}

/// Split the text by the delimiter into N parts (no more!).
pure string[] splitN(string text, string delimiter, int limit) {
    string[] result;
    while (limit > 1) {
        auto index = indexOf(text, delimiter);
        if (index < 0)
            break;

        result ~= to!string(text[0..index]);
        text = text[index + 1..$];
        limit--;
    }

    if (!text.empty)
        result ~= to!string(text);
    return result;
}

/// Test for splitN
unittest {
    const source = "1#2#3#4";
    const expected = ["1", "2", "3#4"];
    const actual = splitN(source, "#", 3);
    assert(expected == actual);
}

/// Pick first non-empty string from the array.
pure string pickOne(string[] strings ...) {
    foreach(s; strings)
        if (!s.empty)
            return s;

    throw new Exception("No strings!");
} // method pickOne

unittest {
    assert(pickOne("first", "second") == "first");
    assert(pickOne("", "second") == "second");
    assert(pickOne(null, "second") == "second");
}

/// Remove comments from the format.
string removeComments(string text) {
    if (text.empty)
        return text;

    if (indexOf(text, "/*") < 0)
        return text;

    string result;
    char state = '\0';
    size_t index = 0;
    const length = text.length;
    reserve(result, length);

    while (index < length) {
        const c = text[index];
        switch (state) {
            case '\'', '"', '|':
                if (c == state)
                    state = '\0';
                result ~= c;
                break;

            default:
            if (c == '/') {
                if (((index + 1) < length) && (text[index + 1] == '*')) {
                    while (index < length) {
                        const c2 = text[index];
                        if ((c2 == '\r') || (c2 == '\n')) {
                            result ~= c2;
                            break;
                        }
                        index++;
                    }
                }
                else {
                    result ~= c;
                }
            }
            else if ((c == '\'') || (c == '"') || (c == '|')) {
                state = c;
                result ~= c;
            }
            else {
                result ~= c;
            }
            break;
        }
        index++;
    }

    return result;
} // method removeComments

/// Test for removeComments
unittest {
    assert(removeComments("") == "");
    assert(removeComments(" ") == " ");
    assert(removeComments("v100,/,v200") == "v100,/,v200");
    assert(removeComments("v100/*comment\r\nv200") == "v100\r\nv200");
    assert(removeComments("v100, '/* not comment', v200") == "v100, '/* not comment', v200");
    assert(removeComments("v100, \"/* not comment\", v200") == "v100, \"/* not comment\", v200");
    assert(removeComments("v100, |/* not comment|, v200") == "v100, |/* not comment|, v200");
    assert(removeComments("v100, '/* not comment', v200, /*comment\r\nv300") == "v100, '/* not comment', v200, \r\nv300");
    assert(removeComments("v100, '/* not comment', v200, /, \r\nv300") == "v100, '/* not comment', v200, /, \r\nv300");
} // unittest

/// Prepare the format.
export string prepareFormat(string text) {
    text = removeComments(text);
    const length = text.length;
    if (length == 0)
        return text;

    auto flag = false;
    for (auto i = 0; i < length; i++)
        if (text[i] < ' ')
        {
            flag = true;
            break;
        }

    if (!flag)
        return text;

    string result;
    reserve(text, length);
    for (auto i = 0; i < length; i++) {
        const c = text[i];
        if (c >= ' ')
            result ~= c;
    }

    return result;
} // method prepareFormat

/// Test for prepareFormat
unittest {
    assert(prepareFormat("") == "");
    assert(prepareFormat(" ") == " ");
    assert(prepareFormat("v100,/,v200") == "v100,/,v200");
    assert(prepareFormat("\tv100\r\n") == "v100");
    assert(prepareFormat("\r\n") == "");
    assert(prepareFormat("/* Comment") == "");
    assert(prepareFormat("v100 '\t'\r\nv200") == "v100 ''v200");
    assert(prepareFormat("v100 \"\t\"\r\nv200") == "v100 \"\"v200");
    assert(prepareFormat("v100 |\t|\r\nv200") == "v100 ||v200");
} // unittest

/**
 * Get error description by the code.
 */
export pure string describeError(int code) nothrow {
    if (code >= 0)
        return "No error";

    string result;
    switch (code) {
        case -100: result = "MFN outside the database range"; break;
        case -101: result = "Bad shelf number"; break;
        case -102: result = "Bad shelf size"; break;
        case -140: result = "MFN outsize the database range"; break;
        case -141: result = "Error during read"; break;
        case -200: result = "Field is absent"; break;
        case -201: result = "Previous version of the record is absent"; break;
        case -202: result = "Term not found"; break;
        case -203: result = "Last term in the list"; break;
        case -204: result = "First term in the list"; break;
        case -300: result = "Database is locked"; break;
        case -301: result = "Database is locked"; break;
        case -400: result = "Error during MST or XRF file access"; break;
        case -401: result = "Error during IFP file access"; break;
        case -402: result = "Error during write"; break;
        case -403: result = "Error during actualization"; break;
        case -600: result = "Record is logically deleted"; break;
        case -601: result = "Record is physically deleted"; break;
        case -602: result = "Record is locked"; break;
        case -603: result = "Record is logically deleted"; break;
        case -605: result = "Record is physically deleted"; break;
        case -607: result = "Error in autoin.gbl"; break;
        case -608: result = "Error in record version"; break;
        case -700: result = "Error during backup creation"; break;
        case -701: result = "Error during backup resore"; break;
        case -702: result = "Error during sorting"; break;
        case -703: result = "Erroneous term"; break;
        case -704: result = "Error during dictionary creation"; break;
        case -705: result = "Error during dictionary loading"; break;
        case -800: result = "Error in global correction parameters"; break;
        case -801: result = "ERR_GBL_REP"; break;
        case -802: result = "ERR_GBL_MET"; break;
        case -1111: result = "Server execution error"; break;
        case -2222: result = "Protocol error"; break;
        case -3333: result = "Unregistered client"; break;
        case -3334: result = "Client not registered"; break;
        case -3335: result = "Bad client identifier"; break;
        case -3336: result = "Workstation not allowed"; break;
        case -3337: result = "Client already registered"; break;
        case -3338: result = "Bad client"; break;
        case -4444: result = "Bad password"; break;
        case -5555: result = "File doesn't exist"; break;
        case -7777: result = "Can't run/stop administrator task"; break;
        case -8888: result = "General error"; break;
        case -100_000: result = "Network failure"; break;
        default: result = "Unknown error"; break;
    }
    return result;
} // method describeError

/// Test for describeError
unittest {
    assert(describeError(5) == "No error");
    assert(describeError(0) == "No error");
    assert(describeError(-1) == "Unknown error");
    assert(describeError(-8888) == "General error");
}

/// Insert value into the array
void arrayInsert(T)(ref T[] arr, size_t offset, T value) {
    insertInPlace(arr, offset, value);
} // method arrayInsert

/// Test for arrayInsert
unittest {
    int[] arr;
    arrayInsert(arr, 0, 1);
    assert(arr == [1]);
    arrayInsert(arr, 1, 2);
    assert(arr == [1, 2]);
} // unittest

/// Remove value from the array
void arrayRemove(T) (ref T[] arr, size_t offset) {
    remove(arr, offset);
    arr.length--;
} // method arrayRemove

/// Test for arrayRemove
unittest {
    int[] arr = [1, 2, 3];
    arrayRemove(arr, 1);
    assert(arr == [1, 3]);
} // unittest

//==================================================================

/**
 * IRBIS-specific errors.
 */
export class IrbisException : Exception {
    int code; /// Code.

    /// Constructor.
    this
        (
            int code,
            string msg = "",
            string file=__FILE__,
            size_t line = __LINE__
        )
    {
        super(msg, file, line);
        this.code = code;
    } // constructor

} // class IrbisException

//==================================================================

/**
 * Subfield consist of a code and value.
 */
export final class SubField
{
    char code; /// One-symbol code of the subfield.
    string value; /// String value of the subfield.

    /// Constructor.
    this() {
        // Nothing to do here
    } // constructor

    /// Test for default constructor
    unittest {
        auto subfield = new SubField();
        assert(subfield.code == char.init);
        assert(subfield.value is null);
    } // unittest

    /// Constructor.
    this(char code, string value) {
        this.code = code;
        this.value = value;
    } // constructor

    /// Test for parametrized constructor
    unittest {
        auto subfield = new SubField('a', "SubA");
        assert(subfield.code == 'a');
        assert(subfield.value == "SubA");
    } // unittest

    /**
     * Deep clone of the subfield.
     */
    SubField clone() const {
        return new SubField(code, value);
    } // method clone

    /// Test for clone
    unittest {
        const first = new SubField('a', "SubA");
        const second = first.clone();
        assert(first.code == second.code);
        assert(first.value == second.value);
    } // unittest

    /**
     * Decode the subfield from protocol representation.
     */
    void decode(string text)
        in (!text.empty)
    {
        code = text[0];
        value = text[1..$];
    } // method decode

    /// Test for decode
    unittest {
        auto subfield = new SubField();
        subfield.decode("aSubA");
        assert(subfield.code == 'a');
        assert(subfield.value == "SubA");
    } // unittest

    pure override string toString() const {
        return "^" ~ code ~ value;
    } // method toString

    /// Test for toString
    unittest {
        auto subfield = new SubField('a', "SubA");
        assert(subfield.toString == "^aSubA");
    } // unittest

    /**
     * Verify the subfield.
     */
    pure bool verify() const nothrow {
        return (code != 0) && !value.empty;
    } // method verify

} // class SubField

//==================================================================

/**
 * Field consist of a value and subfields.
 */
export final class RecordField
{
    int tag; /// Numerical tag of the field.
    string value; /// String value of the field.
    SubField[] subfields; /// Subfields.

    /// Constructor.
    this(int tag=0, string value="") {
        this.tag = tag;
        this.value = value;
        this.subfields = new SubField[0];
    } // constructor

    /// Test for constructor
    unittest {
        auto field = new RecordField(100, "Value");
        assert(field.tag == 100);
        assert(field.value == "Value");
    } // unittest

    /**
     * Append subfield with specified code and value.
     */
    RecordField append(char code, string value)
    {
        auto subfield = new SubField(code, value);
        subfields ~= subfield;
        return this;
    } // method add

    /// Test for append
    unittest {
        auto field = new RecordField();
        field.append('a', "SubA");
        assert(field.subfields.length == 1);
        assert(field.subfields[0].code == 'a');
        assert(field.subfields[0].value == "SubA");
    } // unittest

    /**
     * Clear the field (remove the value and all the subfields).
     */
    RecordField clear() {
        value = "";
        subfields = [];
        return this;
    } // method clear

    /// Test for clear
    unittest {
        auto field = new RecordField();
        field.append('a', "SubA");
        field.clear();
        assert(field.subfields.length == 0);
    } // unittest

    /**
     * Clone the field.
     */
    RecordField clone() const {
        auto result = new RecordField(tag, value);
        foreach (subfield; subfields)
        {
            result.subfields ~= subfield.clone();
        }
        return result;
    } // method clone

    /**
     * Decode body of the field from protocol representation.
     */
    void decodeBody(string bodyText) {
        auto all = bodyText.split("^");
        if (bodyText[0] != '^') {
            value = all[0];
            all = all[1..$];
        }
        foreach(one; all) {
            if (one.length != 0)
            {
                auto subfield = new SubField();
                subfield.decode(one);
                subfields ~= subfield;
            }
        }
    } // method decodeBody

    /**
     * Decode the field from the protocol representation.
     */
    void decode(string text) {
        auto parts = split2(text, "#");
        tag = parseInt(parts[0]);
        decodeBody(parts[1]);
    } // method decode

    /**
     * Get slice of the embedded fields.
     */
    RecordField[] getEmbeddedFields() const {
        RecordField[] result;
        RecordField found = null;
        foreach(subfield; subfields) {
            if (subfield.code == '1') {
                if (found) {
                    if (found.verify)
                        result ~= found;
                    found = null;
                }
                const value  = subfield.value;
                if (value.empty)
                    continue;
                const tag = parseInt(value[0..3]);
                found = new RecordField(tag);
                if (tag < 10)
                    found.value = value[3..$];
            }
            else {
                if (found)
                    found.subfields ~= cast(SubField)subfield;
            }
        }

        if (found && found.verify)
            result ~= found;

        return result;
    } // method getEmbeddedFields

    /// Test for getEmbeddedFields
    unittest {
        auto field = new RecordField(200);
        auto embedded = field.getEmbeddedFields;
        assert(embedded.empty);

        field = new RecordField(461)
            .append('1', "200#1")
            .append('a', "Golden chain")
            .append('e', "Notes. Novels. Stories")
            .append('f', "Bondarin S. A.")
            .append('v', "P. 76-132");
        embedded = field.getEmbeddedFields;
        assert(embedded.length == 1);
        assert(embedded[0].tag == 200);
        assert(embedded[0].subfields.length == 4);
        assert(embedded[0].subfields[0].code == 'a');
        assert(embedded[0].subfields[0].value == "Golden chain");

        field = new RecordField(461)
            .append('1', "200#1")
            .append('a', "Golden chain")
            .append('e', "Notes. Novels. Stories")
            .append('f', "Bondarin S. A.")
            .append('v', "P. 76-132")
            .append('1', "2001#")
            .append('a', "Ruslan and Ludmila")
            .append('f', "Pushkin A. S.");
        embedded = field.getEmbeddedFields;
        assert(embedded.length == 2);
        assert(embedded[0].tag == 200);
        assert(embedded[0].subfields.length == 4);
        assert(embedded[0].subfields[0].code == 'a');
        assert(embedded[0].subfields[0].value == "Golden chain");
        assert(embedded[1].tag == 200);
        assert(embedded[1].subfields.length == 2);
        assert(embedded[1].subfields[0].code == 'a');
        assert(embedded[1].subfields[0].value == "Ruslan and Ludmila");

    } // unittest

    /**
     * Get first subfield with given code.
     */
    SubField getFirstSubField(char code) {
        foreach (subfield; subfields)
            if (sameChar(subfield.code, code))
                return subfield;
        return null;
    } // method getFirstSubfield

    /**
     * Get value of first subfield with given code.
     */
    string getFirstSubFieldValue(char code) {
        foreach (subfield; subfields)
            if (sameChar(subfield.code, code))
                return subfield.value;
        return null;
    } // method getFirstFieldValue

    /**
     * Insert the subfield at specified position.
     */
    RecordField insertAt(size_t index, SubField subfield) {
        arrayInsert(subfields, index, subfield);
        return this;
    } // method insertAt

    /**
     * Remove subfield at specified position.
     */
    RecordField removeAt(size_t index) {
        arrayRemove(subfields, index);
        return this;
    } // method removeAt

    /**
     * Remove all subfields with specified code.
     */
    RecordField removeSubField(char code) {
        // TODO implement
        return this;
    } // method removeSubField

    pure override string toString() const {
        auto result = new OutBuffer();
        result.put(to!string(tag));
        result.put("#");
        result.put(value);
        foreach(subfield; subfields)
            result.put(subfield.toString());
        return result.toString();
    } // method toString

    /**
     * Verify the field.
     */
    pure bool verify() const {
        bool result = (tag != 0) && (!value.empty || !subfields.empty);
        if (result && !subfields.empty)
        {
            foreach (subfield; subfields)
            {
                result = subfield.verify();
                if (!result)
                    break;
            }
        }

        return result;
    } // method verify

    /// Test for verify
    unittest {
        auto field = new RecordField;
        assert(!field.verify);
        field = new RecordField(100);
        assert(!field.verify);
        field = new RecordField(100, "Field100");
        assert(field.verify);
        field = new RecordField(100).append('a', "SubA");
        assert(field.verify);
    } // unittest

} // class RecordField

//==================================================================

/**
 * Record consist of fields.
 */
export final class MarcRecord
{
    string database; /// Database name
    int mfn; /// Masterfile number
    int versionNumber; /// Version number
    int status; /// Status
    RecordField[] fields; /// Slice of fields.

    /// Test for constructor
    unittest {
        auto record = new MarcRecord;
        assert(record.database.empty);
        assert(record.mfn == 0);
        assert(record.versionNumber == 0);
        assert(record.status == 0);
        assert(record.fields.empty);
    } // unittest

    /**
     * Add the field to back of the record.
     */
    RecordField append(int tag, string value="") {
        auto field = new RecordField(tag, value);
        fields ~= field;
        return field;
    } // method append

    /// Test for append
    unittest {
        auto record = new MarcRecord;
        record.append(100);
        assert(record.fields.length == 1);
        assert(record.fields[0].tag == 100);
        assert(record.fields[0].value.empty);
    } // unittest

    /**
     * Add the field if it is non-empty.
     */
    MarcRecord appendNonEmpty(int tag, string value) {
        if (!value.empty)
            append(tag, value);
        return this;
    } // method appendNonEmpty

    /// Test for appendNonEmpty
    unittest {
        auto record = new MarcRecord;
        record.appendNonEmpty(100, "");
        assert(record.fields.length == 0);
        record.appendNonEmpty(100, "Field100");
        assert(record.fields.length == 1);
    } // unittest

    /**
     * Clear the record by removing all the fields.
     */
    MarcRecord clear() {
        fields.length = 0;
        return this;
    } // method clear

    /// Test for clear
    unittest {
        auto record = new MarcRecord;
        record.append(100);
        record.clear;
        assert(record.fields.length == 0);
    } // unittest

    /**
     * Decode the record from the protocol representation.
     */
    void decode(const string[] lines) {
        auto firstLine = split2(lines[0], "#");
        mfn = parseInt(firstLine[0]);
        status = parseInt(firstLine[1]);
        auto secondLine = split2(lines[1], "#");
        versionNumber = parseInt(secondLine[1]);
        foreach(line; lines[2..$]) {
            if (line.length != 0) {
                auto field = new RecordField();
                field.decode(line);
                fields ~= field;
            }
        }
    } // method decode

    /**
     * Encode the record to the protocol representation.
     */
    pure string encode(string delimiter=IRBIS_DELIMITER) const
        out (result; !result.empty)
    {
        auto result = new OutBuffer();
        result.put(to!string(mfn));
        result.put("#");
        result.put(to!string(status));
        result.put(delimiter);
        result.put("0#");
        result.put(to!string(versionNumber));
        result.put(delimiter);
        foreach (field;fields)
        {
            result.put(field.toString());
            result.put(delimiter);
        }

        return result.toString();
    } // method encode

    /**
     * Get value of the field with given tag
     * (or subfield if code given).
     */
    pure string fm(int tag, char code=0) const {
        foreach (field; fields) {
            if (field.tag == tag) {
                if (code != 0) {
                    foreach (subfield; field.subfields) {
                        if (sameChar(subfield.code, code))
                            if (!subfield.value.empty)
                                return subfield.value;
                    }
                }
                else {
                    if (!field.value.empty)
                        return field.value;
                }
            }
        }

        return null;
    } // method fm

    /**
     * Get slice of values of the fields with given tag
     * (or subfield values if code given).
     */
    pure string[] fma(int tag, char code=0) {
        string[] result;
        foreach (field; fields) {
            if (field.tag == tag) {
                if (code != 0) {
                    foreach (subfield; field.subfields) {
                        if (sameChar (subfield.code, code))
                            if (!subfield.value.empty)
                                result ~= subfield.value;
                    }
                }
                else {
                    if (!field.value.empty)
                        result ~= field.value;
                }
            }
        }

        return result;
    } // method fma

    /**
     * Get field by tag and occurrence number.
     */
    pure RecordField getField(int tag, int occurrence=0) {
        foreach (field; fields) {
            if (field.tag == tag) {
                if (occurrence == 0)
                    return field;
                occurrence--;
            }
        }

        return null;
    } // method getField

    /**
     * Get slice of fields with given tag.
     */
    pure RecordField[] getFields(int tag) {
        RecordField[] result;
        foreach (field; fields) {
            if (field.tag == tag)
                result ~= field;
        }

        return result;
    } // method getFields

    /**
     * Insert the field at given index.
     */
    MarcRecord insertAt(size_t index, RecordField field) {
        arrayInsert(fields, index, field);
        return this;
    }

    /**
     * Determine whether the record is marked as deleted.
     */
    @property pure bool deleted() const {
        return (status & 3) != 0;
    } // method isDeleted

    /**
     * Remove field at specified index.
     */
    MarcRecord removeAt(size_t index) {
        arrayRemove(fields, index);
        return this;
    } // method removeAt

    /**
     * Reset record state, unbind from database.
     * Fields remains untouched.
     */
    MarcRecord reset() nothrow
    {
        mfn = 0;
        status = 0;
        versionNumber = 0;
        database = "";
        return this;
    } // method reset

    pure override string toString() const
    {
        return encode("\n");
    } // method toString

} // class MarcRecord

//==================================================================

/**
 * Half-parsed record.
 */
export final class RawRecord
{
    string database; /// Database name.
    int mfn; /// Masterfile number
    int versionNumber; /// Version number
    int status; /// Status.
    string[] fields; /// Slice of fields.

    /**
     * Decode the text representation.
     */
    bool decode(string[] lines) {
        if (lines.length < 3)
            return false;

        const firstLine = split2(lines[0], "#");
        if (firstLine.length != 2)
            return false;

        mfn = parseInt(firstLine[0]);
        status = parseInt(firstLine[1]);

        const secondLine = split2(lines[1], "#");
        if (secondLine.length != 2)
            return false;

        versionNumber = parseInt(secondLine[1]);
        fields = lines[2..$];

        return true;
    } // method decode

    /**
     * Determine whether the record is marked as deleted.
     */
    @property pure bool deleted() const {
        return (status & 3) != 0;
    } // method isDeleted

    /**
     * Encode to the text representation.
     */
    pure string encode(string delimiter = IRBIS_DELIMITER) const {
        auto result = new OutBuffer();
        result.put(to!string(mfn));
        result.put("#");
        result.put(to!string(status));
        result.put(delimiter);
        result.put("0#");
        result.put(to!int(versionNumber));
        result.put(delimiter);

        foreach (field; fields)
        {
            result.put(field);
            result.put(delimiter);
        }

        return result.toString();
    } // method encode

} // class RawRecord

//==================================================================

/**
 * Two lines in the MNU-file.
 */
export final class MenuEntry
{
    string code; /// Code.
    string comment; /// Comment.

    /// Constructor.
    this()
    {
    } // constructor

    /// Constructor.
    this(string code, string comment)
    {
        this.code = code;
        this.comment = comment;
    } // constructor

    override string toString() const
    {
        return code ~ " - " ~ comment;
    } // method toString

} // class MenuEntry

//==================================================================

/**
 * MNU-file wrapper.
 */
export final class MenuFile
{
    MenuEntry[] entries; /// Slice of entries.

    /**
     * Add an entry.
     */
    MenuFile append(string code, string comment)
    {
        auto entry = new MenuEntry(code, comment);
        entries ~= entry;
        return this;
    } // method append

    /**
     * Clear the menu.
     */
    MenuFile clear()
    {
        entries = [];
        return this;
    } // method clear

    /**
     * Get entry.
     */
    MenuEntry getEntry(string code)
    {
        if (entries.length == 0)
            return null;

        foreach (entry; entries)
            if (sameString(entry.code, code))
                return entry;

        code = strip(code);
        foreach (entry; entries)
            if (sameString(entry.code, code))
                return entry;

        code = strip(code, "-=:");
        foreach (entry; entries)
            if (sameString(entry.code, code))
                return entry;

        return null;
    } // method getEntry

    /**
     * Get value.
     */
    string getValue(string code, string defaultValue="")
    {
        auto entry = getEntry(code);
        if (entry is null)
            return defaultValue;
        return entry.comment;
    } // method getValue

    /**
     * Parse text representation.
     */
    void parse(string[] lines)
    {
        for(int i=0; i < lines.length; i += 2)
        {
            auto code = lines[i];
            if (code.length == 0 || code.startsWith("*****"))
                break;
            auto comment = lines[i+1];
            auto entry = new MenuEntry(code, comment);
            entries ~= entry;
        }
    } // method parse

    override string toString() const
    {
        auto result = new OutBuffer();
        foreach(entry; entries)
        {
            result.put(entry.toString());
            result.put("\n");
        }
        result.put("*****");

        return result.toString;
    } // method toString

} // class MenuFile

//==================================================================

/**
 * Line of INI-file. Consist of a key and value.
 */
export final class IniLine
{
    string key; /// Key string.
    string value; /// Value string

    pure override string toString() const
    {
        return this.key ~ "=" ~ this.value;
    } // method toString

} // class IniLine

//==================================================================

/**
 * Section of INI-file. Consist of lines (see IniLine).
 */
export final class IniSection
{
    string name; /// Name of the section.
    IniLine[] lines; /// Lines.

    /**
     * Find INI-line with specified key.
     */
    pure IniLine find(string key)
    {
        foreach (line; lines)
            if (sameString(line.key, key))
                return line;
        return null;
    }

    /**
     * Get value for specified key.
     * If no entry found, default value used.
     */
    pure string getValue(string key, string defaultValue="")
    {
        auto found = find(key);
        return (found is null) ? defaultValue : found.value;
    }

    /**
     * Remove line with specified key.
     */
    void remove(string key)
    {
        // TODO implement
    } // method remove

    /**
     * Set the value for specified key.
     */
    IniSection setValue(string key, string value) {
        if (value is null)
        {
            remove(key);
        }
        else
        {
            auto item = find(key);
            if (item is null)
            {
                item = new IniLine();
                lines ~= item;
                item.key = key;
            }
            item.value = value;
        }

        return this;
    } // method setValue

    pure override string toString() const {
        auto result = new OutBuffer();
        if (!name.empty) {
            result.put("[");
            result.put(name);
            result.put("]");
        }
        foreach (line; lines) {
            result.put(line.toString());
            result.put("\n");
        }
        return result.toString();
    } // method toString

} // class IniSection

//==================================================================

/**
 * INI-file. Consist of sections (see IniSection).
 */
export final class IniFile
{
    IniSection[] sections; /// Slice of sections.

    /**
     * Find section with specified name.
     */
    pure IniSection findSection(string name)
    {
        foreach (section; sections)
            if (sameString(section.name, name))
                return section;
        return null;
    }

    /**
     * Get section with specified name.
     * Create the section if it doesn't exist.
     */
    IniSection getOrCreateSection(string name)
    {
        auto result = findSection(name);
        if (result is null)
        {
            result = new IniSection();
            result.name = name;
            sections ~= result;
        }
        return result;
    }

    /**
     * Get the value from the specified section and key.
     */
    pure string getValue(string sectionName, string key, string defaultValue="")
    {
        auto section = findSection(sectionName);
        return (section is null)
            ? defaultValue : section.getValue(key, defaultValue);
    }

    /**
     * Parse the text representation of the INI-file.
     */
    void parse(string[] lines) {
        IniSection section = null;
        foreach (line; lines) {
            auto trimmed = strip(line);
            if (line.empty)
                continue;

            if (trimmed[0] == '[') {
                auto name = trimmed[1..$-1];
                section = getOrCreateSection(name);
            }
            else if (!(section is null)) {
                auto parts = split2(trimmed, "=");
                if (parts.length != 2)
                    continue;
                auto key = strip(parts[0]);
                if (key.empty)
                    continue;
                auto value = strip(parts[1]);
                auto item = new IniLine();
                item.key = key;
                item.value = value;
                section.lines ~= item;
            }
        }
    } // method parse

    /**
     * Set the value for specified key in specified section.
     */
    IniFile setValue(string sectionName, string key, string value) {
        auto section = getOrCreateSection(sectionName);
        section.setValue(key, value);
        return this;
    } // method setValue

    pure override string toString() const
    {
        auto result = new OutBuffer();
        auto first = true;
        foreach (section; sections)
        {
            if (!first)
                result.put("\n");
            result.put(section.toString());
            first = false;
        }
        return result.toString();
    } // method toString

} // class IniFile

//==================================================================

/**
 * Node of TRE-file.
 */
export final class TreeNode
{
    TreeNode[] children; /// Slice of children.
    string value; /// Value of the node.
    int level; /// Level of the node.

    /**
     * Constructor.
     */
    this(string value="")
    {
        this.value = value;
    } // constructor

    /**
     * Add child node with specified value.
     */
    TreeNode add(string value)
    {
        auto child = new TreeNode(value);
        child.level = this.level + 1;
        children ~= child;
        return this;
    } // method add

    pure override string toString() const
    {
        return value;
    } // method toString

} // class TreeNode

//==================================================================

/**
 * TRE-file.
 */
export final class TreeFile
{
    TreeNode[] roots; /// Slice of root nodes.

    private static void arrange1(TreeNode[] list, int level)
    {
        int count = cast(int)list.length;
        auto index = 0;
        while (index < count)
        {
            const next = arrange2(list, level, index, count);
            index = next;
        }
    } // method arrange1

    private static int arrange2(TreeNode[] list, int level, int index, int count)
    {
        int next = index + 1;
        const level2 = level + 1;
        auto parent = list[index];
        while (next < count)
        {
            auto child = list[next];
            if (child.level < level)
                break;
            if (child.level == level2)
                parent.children ~= child;
            next++;
        }

        return next;
    } // method arrange2

    private static int countIndent(string text)
    {
        auto result = 0;
        const length = text.length;
        for (int i = 0; i < length; i++)
            if (text[i] == '\t')
                result++;
            else
                break;
        return result;
    } // method countIndent

    /**
     * Add root node.
     */
    TreeFile addRoot(string value)
    {
        auto root = new TreeNode(value);
        roots ~= root;
        return this;
    } // method addRoot

    /**
     * Parse the text representation.
     */
    void parse(string[] lines)
    {
        if (lines.length == 0)
            return;

        TreeNode[] list = [];
        int currentLevel = 0;
        auto firstLine = lines[0];
        if (firstLine.empty || (countIndent(firstLine) != 0))
            throw new Exception("Wrong TRE");

        list ~= new TreeNode(firstLine);
        foreach (line; lines)
        {
            if (line.empty)
                continue;

            auto level = countIndent(line);
            if (level > (currentLevel + 1))
                throw new Exception("Wrong TRE");

            currentLevel = level;
            auto node = new TreeNode(line[level..$]);
            node.level = level;
            list ~= node;
        } // foreach

        int maxLevel = 0;
        foreach (item; list)
            if (item.level > maxLevel)
                maxLevel = item.level;

        for (int level = 0; level < maxLevel; level++)
            arrange1(list, level);

        foreach (item; list)
            if (item.level == 0)
                roots ~= item;
    } // method parse

} // class TreeFile

//==================================================================

/**
 * Information about IRBIS database.
 */
export final class DatabaseInfo
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
export final class ProcessInfo
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
export final class VersionInfo
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
export struct UserInfo
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
export struct SearchParameters
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
export struct FoundLine
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
export struct TermInfo
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
export struct TermPosting
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
export struct TermParameters
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
export struct PostingParameters
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
export struct TableDefinition
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
export final class ClientInfo
{
    string number; /// Sequential number.
    string ipAddress; /// Clien IP address.
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
    void parse(string[] lines)
    {
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

    pure override string toString() const
    {
        return ipAddress;
    } // method toString
} // class ClientInfo

//==================================================================

/**
 * IRBIS64 server working statistics.
 */
export final class ServerStat
{
    ClientInfo[] runningClients; /// Slice of running clients.
    int clientCount; /// Actual client count.
    int totalCommandCount; /// Total command count.

    /**
     * Parse the server response.
     */
    void parse(string[] lines)
    {
        totalCommandCount = parseInt(lines[0]);
        clientCount = parseInt(lines[1]);
        auto linesPerClient = parseInt(lines[2]);
        lines = lines[3..$];
        for(int i = 0; i < clientCount; i++)
        {
            auto client = new ClientInfo();
            client.parse(lines);
            runningClients ~= client;
            lines = lines[linesPerClient + 1..$];
        } // for
    } // method parse

    pure override string toString() const
    {
        auto result = new OutBuffer();
        result.put(to!string(totalCommandCount));
        result.put("\n");
        result.put(to!string(clientCount));
        result.put("\n8\n");
        foreach(client; runningClients)
        {
            result.put(client.toString());
            result.put("\n");
        }
        return result.toString();
    } // method toString

} // class ServerStat

//==================================================================

/**
 * Client query encoder.
 */
struct ClientQuery
{
    private OutBuffer _buffer;

    @disable this();

    /// Constructor.
    this(Connection connection, string command)
        in (connection !is null)
        in (!connection.username.empty)
        in (!connection.password.empty)
        in (!command.empty)
    {
        _buffer = new OutBuffer;
        addAnsi(command).newLine;
        addAnsi(connection.workstation).newLine;
        addAnsi(command).newLine;
        add(connection.clientId).newLine;
        add(connection.queryId).newLine;
        addAnsi(connection.password).newLine;
        addAnsi(connection.username).newLine;
        newLine;
        newLine;
        newLine;
    } // this

    /// Add integer value.
    ref ClientQuery add(int value)
    {
        auto text = to!string(value);
        return addUtf(text);
    } // method add

    /// Add boolean value.
    ref ClientQuery add(bool value)
    {
        auto text = value ? "1" : "0";
        return addUtf(text);
    } // method add

    /// Add text in ANSI encoding.
    ref ClientQuery addAnsi(string text)
    {
        auto bytes = toAnsi(text);
        _buffer.write(bytes);
        return this;
    } // method addAnsi

    /// Add format specification
    bool addFormat(string text)
    {
        const stripped = strip(text);

        if (stripped.empty)
        {
            newLine;
            return false;
        }

        auto prepared = prepareFormat(text);
        if (prepared[0] == '@')
        {
            addAnsi(prepared);
        }
        else if (prepared[0] == '!')
        {
            addUtf(prepared);
        }
        else
        {
            addUtf("!");
            addUtf(prepared);
        }
        newLine;
        return true;
    } // method addFormat

    /// Add text in UTF-8 encoding.
    ref ClientQuery addUtf(string text)
    {
        auto bytes = toUtf(text);
        _buffer.write(bytes);
        return this;
    } // method addUtf

    /// Encode the query.
    ubyte[] encode() const
    {
        auto bytes = _buffer.toBytes();
        auto result = new OutBuffer();
        result.printf("%d\n", bytes.length);
        result.write(bytes);
        return result.toBytes();
    } // method encode

    /// Add line delimiter symbol.
    ref ClientQuery newLine()
    {
        _buffer.write(cast(byte)10);
        return this;
    } // method newLine

} // class ClientQuery

//==================================================================

/**
 * Server response decoder.
 */
struct ServerResponse
{
    private bool _ok;
    private ubyte[] _buffer;
    private ptrdiff_t _offset;

    Connection connection; /// Connection used.

    string command; /// Command code.
    int clientId; /// Client id.
    int queryId; /// Query id.
    int answerSize; /// Answer size.
    int returnCode; /// Return code.
    string serverVersion; /// Server version.
    int interval; /// Auto-ack interval.

    @disable this();

    /// Constructor.
    this(ubyte[] buffer)
    {
        _ok = !buffer.empty;
        _buffer = buffer;
        _offset=0;

        if (_ok)
        {
            command = readAnsi;
            clientId = readInteger;
            queryId = readInteger;
            answerSize = readInteger;
            serverVersion = readAnsi;
            interval = readInteger;
            readAnsi;
            readAnsi;
            readAnsi;
            readAnsi;
        }
    } // this

    /// Whether all data received?
    pure bool ok() const nothrow
    {
        return _ok;
    }

    /// Whether end of response reached?
    pure bool eof() const nothrow
    {
        return _offset >= _buffer.length;
    }

    /// Check return code.
    bool checkReturnCode(int[] allowed ...)
    {
        if (getReturnCode < 0)
            return canFind(allowed, returnCode);
        return true;
    }

    /// Get raw line (no encoding applied).
    ubyte[] getLine()
    {
        if (_offset >= _buffer.length)
            return null;

        auto result = new OutBuffer;
        while (_offset < _buffer.length)
        {
            auto symbol = _buffer[_offset++];
            if (symbol == 13)
            {
                if (_buffer[_offset] == 10)
                {
                    _offset++;
                }
                break;
            }
            result.write(symbol);
        }

        return result.toBytes;
    } // method getLine

    /// Get return code.
    int getReturnCode()
    {
        returnCode = readInteger;
        connection.lastError = returnCode;
        return returnCode;
    }

    /// Read line in ANSI encoding.
    string readAnsi()
    {
        return fromAnsi(getLine);
    } // method readAnsi

    /// Read integer value
    int readInteger()
    {
        auto line = readUtf;
        auto result = 0;
        if (!line.empty)
        {
            result = to!int(line);
        }
        return result;
    } // method readInteger

    /// Read remaining lines in ANSI encoding.
    string[] readRemainingAnsiLines()
    {
        string[] result;
        while (!eof)
        {
            auto line = readAnsi;
            result ~= line;
        }
        return result;
    } // method readRemainingAnsiLines

    /// Read remaining text in ANSI encoding.
    string readRemainingAnsiText()
    {
        auto chunk = _buffer[_offset..$];
        return fromAnsi(chunk);
    } // method readRemainingAnsiText

    /// Read remaining lines in UTF-8 encoding.
    string[] readRemainingUtfLines()
    {
        string[] result;
        while (!eof)
        {
            auto line = readUtf;
            result ~= line;
        }
        return result;
    } // method readRemainingUtfLines

    /// Read remaining text in UTF-8 encoding.
    string readRemainingUtfText()
    {
        auto chunk = _buffer[_offset..$];
        return fromUtf(chunk);
    } // method readRemainingUtfText

    /// Read line in UTF-8 encoding.
    string readUtf()
    {
        return fromUtf(getLine);
    } // method readUtf

} // class ServerResponse

//==================================================================

/**
 * Abstract client socket.
 */
class ClientSocket
{
    /**
     * Talk to server and get response.
     */
    abstract ServerResponse talkToServer(const ref ClientQuery query);
} // class ClientSocket

//==================================================================

/**
 * Client socket implementation for TCP/IP v4.
 */
final class Tcp4ClientSocket : ClientSocket
{
    private Connection _connection;

    /// Constructor.
    this(Connection connection)
    {
        _connection = connection;
    }

    override ServerResponse talkToServer(const ref ClientQuery query)
    {
        auto socket = new Socket(AddressFamily.INET, SocketType.STREAM);
        auto address = new InternetAddress(_connection.host, _connection.port);
        socket.connect(address);
        scope(exit) socket.close;
        auto outgoing = query.encode;
        socket.send(outgoing);

        ptrdiff_t amountRead;
        auto incoming = new OutBuffer;
        incoming.reserve(2048);
        auto buffer = new ubyte[2056];
        while((amountRead = socket.receive(buffer)) != 0)
        {
            incoming.write(buffer[0..amountRead]);
        }

        auto result = ServerResponse(incoming.toBytes);

        return result;
    } // method talkToServer

} // class Tcp4ClientSocket

//==================================================================

/**
 * IRBIS-sever connection.
 */
export final class Connection
{
    private bool _connected;

    string host; /// Host name or address.
    ushort port; /// Port number.
    string username; /// User login.
    string password; /// User password.
    string database; /// Current database name.
    string workstation; /// Workstation code.
    int clientId; /// Unique client identifier.
    int queryId; /// Sequential query number.
    string serverVersion; /// Server version.
    int interval; /// Auto-ack interval.
    IniFile ini; /// INI-file.
    ClientSocket socket; /// Socket.
    int lastError; /// Last error code.

    /// Constructor.
    this() {
        host = "127.0.0.1";
        port = 6666;
        database = "IBIS";
        workstation = CATALOGER;
        socket = new Tcp4ClientSocket(this);
        _connected = false;
    } // constructor

    ~this() {
        disconnect();
    } // destructor

    /**
     * Actualize all the non-actualized records in the database.
     */
    bool actualizeDatabase(string database="") {
        const db = pickOne(database, this.database);
        return actualizeRecord(db, 0);
    } // method actualizeDatabase

    /**
     * Actualize the record with the given MFN.
     */
    bool actualizeRecord(string database, int mfn)
        in (mfn >= 0)
    {
        if (!connected)
            return false;

        const db = pickOne(database, this.database);
        auto query = ClientQuery (this, "F");
        query.addAnsi(db).newLine;
        query.add(mfn).newLine;
        auto response = execute(query);
        return response.ok && response.checkReturnCode;
    } // method actualizeRecord

    /**
     * Establish the server connection.
     */
    bool connect()
        in (!host.empty)
        in (port > 0)
        in (!username.empty)
        in (!password.empty)
        in (!workstation.empty)
        in (socket !is null)
    {
        if (connected)
            return true;

        AGAIN: queryId = 1;
        clientId = uniform(100_000, 999_999);
        auto query = ClientQuery(this, "A");
        query.addAnsi(username).newLine;
        query.addAnsi(password);
        auto response = execute(query);
        if (!response.ok)
            return false;

        response.getReturnCode;
        if (response.returnCode == -3337)
            goto AGAIN;

        if (response.returnCode < 0) {
            lastError = response.returnCode;
            return false;
        }

        _connected = true;
        serverVersion = response.serverVersion;
        interval = response.interval;
        auto lines = response.readRemainingAnsiLines;
        ini = new IniFile;
        ini.parse(lines);
        return true;
    } // method connect

    /// Whether the client is connected to the server?
    @property pure bool connected() const nothrow {
        return _connected;
    }

    /**
     * Create the server database.
     */
    bool createDatabase
        (
            string database,
            string description,
            bool readerAccess=true
        )
        in (!database.empty)
        in (!description.empty)
    {
        if (!connected)
            return false;

        auto query = ClientQuery(this, "T");
        query.addAnsi(database).newLine;
        query.addAnsi(description).newLine;
        query.add(cast(int)readerAccess).newLine;
        auto response = execute(query);
        return response.ok && response.checkReturnCode;
    } // method createDatabase

    /**
     * Create the dictionary for the database.
     */
    bool createDictionary(string database="") {
        if (!connected)
            return false;

        auto db = pickOne(database, this.database);
        auto query = ClientQuery(this, "Z");
        query.addAnsi(db).newLine;
        auto response = execute(query);
        return response.ok && response.checkReturnCode;
    } // method createDictionary

    /**
     * Delete the database on the server.
     */
    bool deleteDatabase(string database)
        in (!database.empty)
    {
        if (!connected)
            return false;

        auto query = ClientQuery(this, "W");
        query.addAnsi(database).newLine;
        auto response = execute(query);
        return response.ok && response.checkReturnCode;
    } // method deleteDatabase

    /**
     * Delete specified file on the server.
     */
    void deleteFile(string fileName)
    {
        if (!fileName.empty)
            formatRecord("&uf(+9K'" ~ fileName ~"')", 1);
    } // method deleteFile

    /**
     * Delete the record by MFN.
     */
    bool deleteRecord(int mfn) {
        auto record = readRawRecord(mfn);
        if (record !is null && !record.deleted) {
            record.status |= LOGICALLY_DELETED;
            return writeRawRecord(record) != 0;
        }
        return false;
    } // method deleteRecord

    /**
     * Disconnect from the server.
     */
    bool disconnect()
        out(; !connected)
    {
        if (!connected)
            return true;

        auto query = ClientQuery(this, "B");
        query.addAnsi(username);
        execute(query);
        _connected = false;
        return true;
    } // method disconnect

    /**
     * Execute the query.
     */
    ServerResponse execute(const ref ClientQuery query) {
        lastError = 0;
        auto result = ServerResponse([]);
        try {
            result = socket.talkToServer(query);
            result.connection = this;
            queryId++;
        }
        catch (Exception ex) {
            lastError = -100_000;
        }

        return result;
    } // method execute

    /**
     * Execute arbitrary command with optional parameters.
     */
    ServerResponse executeAny(string command, string[] parameters ... ) {
        if (!connected)
            return ServerResponse([]);
        auto query = ClientQuery(this, command);
        foreach (parameter; parameters)
            query.addAnsi(parameter).newLine;
        return execute(query);
    } // method executeAny

    /**
     * Format the record by MFN.
     */
    string formatRecord(string text, int mfn)
        in (mfn > 0)
    {
        if (!connected || text.empty)
            return "";

        auto query = ClientQuery(this, "G");
        query.addAnsi(database).newLine;
        if (!query.addFormat(text))
            return "";

        query.add(1).newLine;
        query.add(mfn).newLine;
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return "";

        auto result = response.readRemainingUtfText;
        result = strip(result);

        return result;
    } // method formatRecord

    /**
     * Format virtual record.
     */
    string formatRecord(string format, const MarcRecord record) {
        if (!connected || format.empty || (record is null))
            return "";

        auto db = pickOne(record.database, this.database);
        auto query = ClientQuery(this, "G");
        query.addAnsi(db).newLine;
        query.addFormat(format);
        query.add(-2).newLine;
        query.addUtf(record.encode(IRBIS_DELIMITER));
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return "";

        auto result = response.readRemainingUtfText;
        result = stripRight(result);
        return result;
    } // method formatRecord

    /**
     * Format the slice of records.
     */
    string[] formatRecords(string format, int[] list ...) {
        if (!connected || list.empty)
            return [];

        string[] result;
        result.length = list.length;
        if (format.empty)
            return result;

        if (list.length == 1) {
            result[0] = formatRecord(format, list[0]);
            return result;
        }

        auto query = ClientQuery(this, "G");
        query.addAnsi(database).newLine;
        if (!query.addFormat(format))
            return result;
        query.add(cast(int)list.length).newLine;
        foreach(mfn; list)
            query.add(mfn).newLine;

        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return result;

        auto lines = response.readRemainingUtfLines;
        for(int i = 0; i < lines.length; i++) {
            auto parts = split2(lines[i], "#");
            if (parts.length != 1)
                result[i] = irbisToUnix(parts[1]);
        }

        return result;
    } // method formatRecords

    /**
     * Get information about the database.
     */
    DatabaseInfo getDatabaseInfo(string database = "") {
        DatabaseInfo result;
        if (!connected)
            return result;

        auto db = pickOne(database, this.database);
        auto query = ClientQuery(this, "0");
        query.addAnsi(db);
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return result;
        auto lines = response.readRemainingAnsiLines;
        result = new DatabaseInfo;
        result.parse(lines);
        return result;
    } // method getDatabaseInfo

    /**
     * Get the maximal MFN for the database.
     */
    int getMaxMfn(string databaseName = "") {
        if (!connected)
            return 0;

        auto db = pickOne(databaseName, this.database);
        auto query = ClientQuery(this, "O");
        query.addAnsi(db);
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return 0;

        return response.returnCode;
    } // method getMaxMfn

    /**
     * Get server running statistics.
     */
    ServerStat getServerStat() {
        auto result = new ServerStat();
        if (!connected)
            return result;

        auto query = ClientQuery(this, "+1");
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return result;

        auto lines = response.readRemainingAnsiLines;
        result.parse(lines);
        return result;
    } // method getServerStat

    /**
     * Get the server version.
     */
    VersionInfo getServerVersion() {
        VersionInfo result;

        if (connected) {
            auto query = ClientQuery(this, "1");
            auto response = execute(query);
            if (response.ok && response.checkReturnCode) {
                auto lines = response.readRemainingAnsiLines;
                result = new VersionInfo;
                result.parse(lines);
            }
        }

        return result;
    } // method getServerVersion

    /**
     * Get the user list from the server.
     */
    UserInfo[] getUserList() {
        UserInfo[] result;
        if (!connected)
            return result;

        auto query = ClientQuery(this, "+9");
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return result;

        auto lines = response.readRemainingAnsiLines;
        result = UserInfo.parse(lines);
        return result;
    } // method getUserList

    /**
     * List server databases.
     */
    DatabaseInfo[] listDatabases(string specification = "1..dbnam2.mnu") {
        DatabaseInfo[] result;

        if (!connected || specification.empty)
            return result;

        auto menu = readMenuFile(specification);
        if (menu is null)
            return result;

        result = DatabaseInfo.parseMenu(menu);
        return result;
    } // method listDatabase

    /**
     * List server files by specification.
     */
    string[] listFiles(string[] specifications ...) {
        string[] result;
        if (!connected || specifications.empty)
            return result;

        auto query = ClientQuery(this, "!");
        foreach (spec; specifications)
            if (spec.empty)
                query.addAnsi(spec).newLine;
        auto response = execute(query);
        if (!response.ok)
            return result;

        auto lines = response.readRemainingAnsiLines;
        foreach (line; lines) {
            auto files = irbisToLines(line);
            foreach (file; files) {
                if (!file.empty)
                    result ~= file;
            }
        }
        return result;
    } // method listFiles

    /**
     * Get server process list.
     */
    ProcessInfo[] listProcesses() {
        ProcessInfo[] result;
        if (!connected)
            return result;

        auto query = ClientQuery(this, "+3");
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return result;

        auto lines = response.readRemainingAnsiLines;
        result = ProcessInfo.parse(lines);
        return result;
    } // method listProcesses

    /**
     * List all the search terms for given prefix.
     */
    string[] listTerms(string prefix) {
        string[] result;
        if (!connected)
            return result;

        prefix = capitalize(prefix);
        const prefixLength = prefix.length;
        auto startTerm = prefix;
        auto lastTerm = startTerm;
        OUTER: while (true) {
            auto terms = readTerms(startTerm, 512);
            auto first = true;
            foreach (term; terms) {
                auto text = term.text;
                if (text[0..prefixLength] != prefix)
                    break OUTER;
                if (text != startTerm) {
                    lastTerm = text;
                    text = to!string(text[prefixLength..$]);
                    if (first && (result.length != 0)) {
                        if (text == result[$-1])
                            continue;
                    }
                    result ~= text;
                }
                first = false;
            }
            startTerm = lastTerm;
        }

        return result;
    }

    /**
     * Empty operation. Confirms the client is alive.
     */
    bool noOp() {
        if (!connected)
            return false;

        auto query = ClientQuery(this, "N");
        return execute(query).ok;
    } // method noOp

    /**
     * Parse the connection string.
     */
    void parseConnectionString(string connectionString) {
        const items = split(connectionString, ";");
        foreach(item; items) {
            if (item.empty)
                continue;

            auto parts = split2(item, "=");
            if (parts.length != 2)
                continue;

            const name = toLower(strip(parts[0]));
            auto value = strip(parts[1]);

            switch(name) {
                case "host", "server", "address":
                    host = value;
                    break;

                case "port":
                    port = to!ushort(value);
                    break;

                case "user", "username", "name", "login":
                    username = value;
                    break;

                case "pwd", "password":
                    password = value;
                    break;

                case "db", "database", "catalog":
                    database = value;
                    break;

                case "arm", "workstation":
                    workstation = value;
                    break;

                default:
                    throw new Exception("Unknown key");
            }
        }
    } // method parseConnectionString

    /**
     * Format table on the server.
     */
    string printTable(const ref TableDefinition definition) {
        if (!connected)
            return "";

        auto db = pickOne(definition.database, this.database);
        auto query = ClientQuery(this, "7");
        query.addAnsi(db).newLine;
        query.addAnsi(definition.table).newLine;
        query.addAnsi("").newLine; // instead of headers
        query.addAnsi(definition.mode).newLine;
        query.addAnsi(definition.searchQuery).newLine;
        query.add(definition.minMfn).newLine;
        query.add(definition.maxMfn).newLine;
        query.addUtf(definition.sequentialQuery).newLine;
        query.addAnsi("").newLine; // instead of MFN list
        auto response = execute(query);
        auto result = strip (response.readRemainingUtfText);
        return result;
    } // method printTable

    /**
     * Read the MNU-file from the server.
     */
    MenuFile readMenuFile(string specification)
        in (!specification.empty)
    {
        if (!connected)
            return null;

        auto lines = readTextLines(specification);
        if (lines.empty)
            return null;

        auto result = new MenuFile;
        result.parse(lines);
        return result;
    } // method readMenuFile

    /**
     * Read postings for the term.
     */
    TermPosting[] readPostings(const ref PostingParameters parameters) {
        TermPosting[] result;
        if (!connected)
            return result;

        auto db = pickOne(parameters.database, this.database);
        auto query = ClientQuery(this, "I");
        query.addAnsi(db).newLine;
        query.add(parameters.numberOfPostings).newLine;
        query.add(parameters.firstPosting).newLine;
        query.addFormat(parameters.format);
        if (parameters.listOfTerms.empty) {
            foreach (term; parameters.listOfTerms)
                query.addUtf(term).newLine;
        }
        else
            query.addUtf(parameters.term).newLine;
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return result;

        auto lines = response.readRemainingUtfLines;
        result = TermPosting.parse(lines);
        return result;
    }

    /**
     * Read and half-decode the record.
     */
    RawRecord readRawRecord(int mfn, int versionNumber=0) {
        if (!connected)
            return null;

        auto query = ClientQuery(this, "C");
        query.addAnsi(database).newLine();
        query.add(mfn).newLine();
        query.add(versionNumber).newLine();

        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode(-201, -600, -602, -603))
            return null;

        auto result = new RawRecord;
        auto lines = response.readRemainingUtfLines();
        result.decode(lines);
        result.database = database;

        if (versionNumber != 0)
            unlockRecords(database, [mfn]);

        return result;
    } // method readRawRecord

    /**
     * Read the record from the server by MFN.
     */
    MarcRecord readRecord(int mfn, int versionNumber=0)
        in (mfn > 0)
    {
        if (!connected)
            return null;

        auto query = ClientQuery(this, "C");
        query.addAnsi(database).newLine;
        query.add(mfn).newLine;
        query.add(versionNumber).newLine;
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode(-201, -600, -602, -603))
            return null;

        auto result = new MarcRecord;
        const lines = response.readRemainingUtfLines;
        result.decode(lines);
        result.database = database;

        if (versionNumber != 0)
            unlockRecords(database, [mfn]);

        return result;
    } // method readRecord

    /**
     * Read some records.
     */
    MarcRecord[] readRecords(int[] mfnList) {
        MarcRecord[] result;

        if (!connected || mfnList.empty)
            return result;

        if (mfnList.length == 1) {
            auto record = readRecord(mfnList[0]);
            if (record !is null)
                result ~= record;
        }
        else {
            auto query = ClientQuery(this, "G");
            query.addAnsi(database).newLine;
            query.addAnsi(ALL_FORMAT).newLine;
            query.add(cast(int)mfnList.length).newLine;
            foreach(mfn; mfnList)
                query.add(mfn).newLine();

            auto response = execute(query);
            if (!response.ok || !response.checkReturnCode)
                return result;

            const lines = response.readRemainingUtfLines;
            foreach(line; lines)
                if (!line.empty)
                {
                    auto parts = split2(line, "#");
                    parts = split(parts[1], ALT_DELIMITER);
                    parts = parts[1..$];
                    auto record = new MarcRecord();
                    record.decode(parts);
                    record.database = database;
                    result ~= record;
                }
        }

        return result;
    } // method readRecords

    /**
     * Read terms from the inverted file.
     */
    TermInfo[] readTerms(string startTerm, int number)
        in (number >= 0)
    {
        auto parameters = TermParameters();
        parameters.startTerm = startTerm;
        parameters.numberOfTerms = number;
        return readTerms(parameters);
    } // method readTerms

    /**
     * Read terms from the inverted file.
     */
    TermInfo[] readTerms(const ref TermParameters parameters) {
        if (!connected)
            return [];

        auto command = parameters.reverseOrder ? "P" : "H";
        auto db = pickOne(parameters.database, this.database);
        auto query = ClientQuery(this, command);
        query.addAnsi(db).newLine;
        query.addUtf(parameters.startTerm).newLine;
        query.add(parameters.numberOfTerms).newLine;
        auto prepared = prepareFormat(parameters.format);
        query.addAnsi(prepared).newLine;
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode(-202, -203, -204))
            return [];

        auto lines = response.readRemainingUtfLines();
        auto result = TermInfo.parse(lines);
        return result;
    } // method readTerms

    /**
     * Read the text file from the server.
     */
    string readTextFile(string specification) {
        if (!connected || specification.empty)
            return "";

        auto query = ClientQuery(this, "L");
        query.addAnsi(specification).newLine();
        auto response = execute(query);
        if (!response.ok)
            return "";

        auto result = response.readAnsi();
        result = irbisToUnix(result);
        return result;
    } // method readTextFile

    /**
    * Read the text file from the server as the array of lines.
    */
    string[] readTextLines(string specification) {
        if (!connected || specification.empty)
            return [];

        auto query = ClientQuery(this, "L");
        query.addAnsi(specification).newLine();
        auto response = execute(query);
        if (!response.ok)
            return [];

        auto content = response.readAnsi();
        auto result = irbisToLines(content);
        return result;
    } // method readTextLines

    /**
     * Read TRE-file from the server.
     */
    TreeFile readTreeFile(string specification) {
        auto lines = readTextLines(specification);
        if (lines.length == 0)
            return null;

        auto result = new TreeFile();
        result.parse(lines);
        return result;
    }

    /**
    * Recreate dictionary for the database.
    */
    bool reloadDictionary(string database) {
        if (!connected)
            return false;

        auto query = ClientQuery(this, "Y");
        query.addAnsi(database).newLine;
        return execute(query).ok;
    } // method reloadDictionary

    /**
     * Recreate master file for the database.
     */
    bool reloadMasterFile(string database) {
        if (!connected)
            return false;

        auto query = ClientQuery(this, "X");
        query.addAnsi(database).newLine;
        return execute(query).ok;
    } // method reloadMasterFile

    /**
     * Restarting the server (without losing the connected clients).
     */
    bool restartServer() {
        if (!connected)
            return false;

        auto query = ClientQuery(this, "+8");
        return execute(query).ok;
    } // method restartServer

    /**
     * Simple search for records (no more than 32k records).
     */
    int[] search(string expression) {
        if (!connected)
            return [];

        if (expression.length == 0)
            return [];

        auto query = ClientQuery(this, "K");
        query.addAnsi(database).newLine;
        query.addUtf(expression).newLine;
        query.add(0).newLine;
        query.add(1).newLine;
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode())
            return [];

        response.readInteger; // count of found records
        const lines = response.readRemainingUtfLines();
        auto result = FoundLine.parseMfn(lines);
        return result;
    } // method search

    /**
     * Extended search for records (no more than 32k records).
     */
    FoundLine[] search(const ref SearchParameters parameters) {
        if (!connected)
            return [];

        auto db = pickOne(parameters.database, this.database);
        auto query = ClientQuery(this, "K");
        query.addAnsi(db).newLine;
        query.addUtf(parameters.expression).newLine;
        query.add(parameters.numberOfRecords).newLine;
        query.add(parameters.firstRecord).newLine;
        query.addFormat(parameters.format);
        query.add(parameters.minMfn).newLine;
        query.add(parameters.maxMfn).newLine;
        query.addAnsi(parameters.sequential).newLine;
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return [];

        response.readInteger(); // count of found records
        auto lines = response.readRemainingUtfLines;
        auto result = FoundLine.parseFull(lines);
        return result;
    } // method search

    /**
     * Search all the records (even if more than 32k records).
     */
    int[] searchAll(string expression) {
        int[] result;
        if (!connected)
            return result;

        auto firstRecord = 1;
        auto totalCount = 0;
        while (true) {
            auto query = ClientQuery(this, "K");
            query.addAnsi(database).newLine;
            query.addUtf(expression).newLine;
            query.add(0).newLine;
            query.add(firstRecord).newLine;
            auto response = execute(query);
            if (!response.ok || !response.checkReturnCode)
                return result;

            if (firstRecord == 1) {
                totalCount = response.readInteger;
                if (totalCount == 0)
                    break;
            }
            else {
                response.readInteger; // eat the line
            }

            auto lines = response.readRemainingUtfLines;
            auto found = FoundLine.parseMfn(lines);
            if (found.length == 0)
                break;

            result ~= found;
            firstRecord += found.length;
            if (firstRecord >= totalCount)
                break;
        } // while

        return result;
    } // method searchAll

    /**
     * Determine the number of records matching the search expression.
     */
    int searchCount(string expression) {
        if (!connected || expression.empty)
            return 0;

        auto query = ClientQuery(this, "K");
        query.addAnsi(database).newLine;
        query.addUtf(expression).newLine;
        query.add(0).newLine;
        query.add(0).newLine;
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return 0;

        auto result = response.readInteger;
        return result;
    } // method searchCount

    /**
     * Search for recods and read found ones
     * (no more than 32k records).
     */
    MarcRecord[] searchRead(string expression, int limit=0)
        in (limit >= 0)
    {
        MarcRecord[] result;
        if (!connected || expression.empty)
            return result;

        SearchParameters parameters;
        parameters.expression = expression;
        parameters.format = ALL_FORMAT;
        parameters.numberOfRecords = limit;
        auto found = search(parameters);
        if ((found is null) || found.empty)
            return result;

        foreach (item; found) {
            auto lines = split(item.description, ALT_DELIMITER);
            if (lines.length == 0)
                continue;
            lines = lines[1..$];
            if (lines.length == 0)
                continue;
            auto record = new MarcRecord();
            record.decode(lines);
            record.database = database;
            result ~= record;
        }

        return result;
    } // method searchRead

    /**
     * Search and read for single record satisfying the expression.
     * If many records found, any of them will be returned.
     * If no records found, null will be returned.
     */
    MarcRecord searchSingleRecord(string expression) {
        auto found = searchRead(expression, 1);
        return found.length != 0 ? found[0] : null;
    } // method searchSingleRecord

    /**
     * Throw exception if last operation completed with error.
     */
    void throwOnError(string file = __FILE__, size_t line = __LINE__) const {
        if (lastError < 0)
            throw new IrbisException(lastError, describeError(lastError), file, line);
    } // method throwOnError

    /**
     * Compose the connection string for current connection.
     * The connection does not have to be established.
     */
    pure string toConnectionString() const {
        return format
            (
                "host=%s;port=%d;username=%s;password=%d;database=%s;arm=%s;",
                host,
                port,
                username,
                password,
                database,
                workstation
            );
    } // method toConnectionString

    /**
     * Empty the database.
     */
    bool truncateDatabase(string database="") {
        if (!connected)
            return false;

        auto db = pickOne(database, this.database);
        auto query = ClientQuery(this, "S");
        query.addAnsi(db).newLine;
        return execute(query).ok;
    } // method truncateDatabase

    /**
     * Restore the deleted record.
     * If the record isn't deleted, no action taken.
     */
    MarcRecord undeleteRecord(int mfn)
        in (mfn > 0)
    {
        auto result = readRecord(mfn);
        if (result is null)
            return result;

        if (result.deleted)
        {
            result.status &= ~LOGICALLY_DELETED;
            if (writeRecord(result) == 0)
                return null;
        }

        return result;
    } // method undeleteRecord

    /**
     * Unlock the database.
     */
    bool unlockDatabase(string database="")
    {
        if (!connected)
            return false;

        auto db = pickOne(database, this.database);
        auto query = ClientQuery(this, "U");
        query.addAnsi(db).newLine;
        return execute(query).ok;
    } // method unlockDatabase

    /**
     * Unlock the slice of records.
     */
    bool unlockRecords(string database, int[] mfnList) {
        if (!connected)
            return false;

        if (mfnList.empty)
            return true;

        const db = pickOne(database, this.database);
        auto query = ClientQuery(this, "Q");
        query.addAnsi(db).newLine;
        foreach(mfn; mfnList)
            query.add(mfn).newLine;
        return execute(query).ok;
    } // method unlockRecords

    /**
     * Update server INI file lines for current user.
     */
    bool updateIniFile(string[] lines) {
        if (!connected)
            return false;

        if (lines.empty)
            return true;

        auto query = ClientQuery(this, "8");
        foreach (line; lines)
            query.addAnsi(line).newLine;
        return execute(query).ok;
    } // method updateIniFile

    /**
     * Write the raw record to the server.
     */
    int writeRawRecord
        (
            const RawRecord record,
            bool lockFlag=false,
            bool actualize=true
        )
    {
        if (!connected || (record is null))
            return 0;

        auto db = pickOne(record.database, this.database);
        auto query = ClientQuery(this, "D");
        query.addAnsi(db).newLine;
        query.add(lockFlag).newLine;
        query.add(actualize).newLine;
        query.addUtf(record.encode).newLine;
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return 0;

        return response.returnCode;
    } // method writeRawRecord

    /**
     * Write the record to the server.
     */
    int writeRecord
        (
            MarcRecord record,
            bool lockFlag=false,
            bool actualize=true,
            bool dontParse=false
        )
    {
        if (!connected || (record is null))
            return 0;

        auto db = pickOne(record.database, this.database);
        auto query = ClientQuery(this, "D");
        query.addAnsi(db).newLine;
        query.add(lockFlag).newLine;
        query.add(actualize).newLine;
        query.addUtf(record.encode).newLine;
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return 0;

        if (!dontParse)
        {
            record.fields = [];
            auto temp = response.readRemainingUtfLines;
            auto lines = [temp[0]];
            lines ~= split(temp[1], SHORT_DELIMITER);
            record.decode(lines);
            record.database = database;
        }

        return response.returnCode;
    } // method writeRecord

    /**
     * Write the slice of records to the server.
     */
    bool writeRecords
        (
            MarcRecord[] records,
            bool lockFlag = false,
            bool actualize = true,
            bool dontParse = false
        )
    {
        if (!connected || records.empty)
            return false;

        if (records.length == 1)
        {
            writeRecord(records[0]);
            return true;
        }

        auto query = ClientQuery(this, "6");
        query.add(lockFlag).newLine;
        query.add(actualize).newLine;
        foreach (record; records)
        {
            auto db = pickOne(record.database, this.database);
            query.addUtf(db)
                .addUtf(IRBIS_DELIMITER)
                .addUtf(record.encode)
                .newLine;
        }
        auto response = execute(query);
        if (!response.ok || !response.checkReturnCode)
            return false;

        if (!dontParse)
        {
            auto lines = response.readRemainingUtfLines;
            foreach (i, line; lines)
            {
                if (line.empty)
                    continue;
                auto record = records[i];
                record.clear;
                record.database = pickOne(record.database, this.database);
                auto recordLines = irbisToLines(line);
                record.decode(recordLines);
            }
        }

        return true;
    } // method writeRecords

    /**
     * Write the text file to the server.
     */
    bool writeTextFile(string specification)
        in (!specification.empty)
    {
        if (!connected)
            return false;

        auto query = ClientQuery(this, "L");
        query.addAnsi(specification);
        return execute(query).ok;
    } // method writeTextFile

} // class Connection

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

//==================================================================
