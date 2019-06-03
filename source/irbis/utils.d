/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

module irbis.utils;

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

import irbis.constants;

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
pure int parseInt(scope ubyte[] text) nothrow {
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
export pure int parseInt(scope string text) nothrow {
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
