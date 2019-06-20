/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

module irbis.text;

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
import std.uni;

//==================================================================

/**
 * Simple text navigation.
 */
final class TextNavigator
{
    /// End of text.
    static const wchar EOT = 0;

    private int _column, _line, _position;
    private immutable int _length;
    private immutable wchar[] _text;

    /// Constructor.
    this(string text) {
        _text = to!(wchar[])(text);
        _length = cast(int)(_text.length);
        _column = 1;
        _line = 1;
    } // constructor

    /// Test for constructor.
    unittest {
        string text = null;
        auto navigator = new TextNavigator(text);
        assert(navigator.column == 1);
        assert(navigator.line == 1);
        assert(navigator.length == 0);
        assert(navigator.position == 0);

        text = "";
        navigator = new TextNavigator(text);
        assert(navigator.column == 1);
        assert(navigator.line == 1);
        assert(navigator.length == 0);
        assert(navigator.position == 0);

        text = "Hello";
        navigator = new TextNavigator(text);
        assert(navigator.column == 1);
        assert(navigator.line == 1);
        assert(navigator.length == 5);
        assert(navigator.position == 0);
    } // unittest

    /// Constructor.
    this(wstring text) {
        _text = to!(wchar[])(text);
        _length = cast(int)(_text.length);
        _column = 1;
        _line = 1;
    } // constructor

    /// Test for constructor.
    unittest {
        wstring text = null;
        auto navigator = new TextNavigator(text);
        assert(navigator.column == 1);
        assert(navigator.line == 1);
        assert(navigator.length == 0);
        assert(navigator.position == 0);

        text = "";
        navigator = new TextNavigator(text);
        assert(navigator.column == 1);
        assert(navigator.line == 1);
        assert(navigator.length == 0);
        assert(navigator.position == 0);

        text = "Hello";
        navigator = new TextNavigator(text);
        assert(navigator.column == 1);
        assert(navigator.line == 1);
        assert(navigator.length == 5);
        assert(navigator.position == 0);
    } // unittest

    /// End of text?
    pure bool eot() const nothrow {
        return _position >= length;
    } // method eot

    /// Current column number.
    pure int column() const nothrow {
        return _column;
    } // method column

    /// Current line number.
    pure int line() const nothrow {
        return _line;
    } // method line

    /// Total text length.
    pure int length() const nothrow {
        return _length;
    } // method length

    /// Current position.
    pure int position() const nothrow {
        return _position;
    } // method position

    /// Get character at specified position.
    pure wchar charAt(int pos) const {
        if (pos < 0 || pos >= _length)
            return EOT;
        return _text[pos];
    } // method charAt

    /// Test for charAt
    unittest {
        wstring text = null;
        auto navigator = new TextNavigator(text);
        assert(navigator.charAt(0) == EOT);
        assert(navigator.charAt(-1) == EOT);
        assert(navigator.charAt(1) == EOT);

        text = "";
        navigator = new TextNavigator(text);
        assert(navigator.charAt(0) == EOT);
        assert(navigator.charAt(-1) == EOT);
        assert(navigator.charAt(1) == EOT);

        text = "Hello";
        navigator = new TextNavigator(text);
        assert(navigator.charAt(0) == 'H');
        assert(navigator.charAt(-1) == EOT);
        assert(navigator.charAt(1) == 'e');
    } // unittest

    /// Look ahead.
    pure wchar lookAhead(int distance = 1) const {
        const pos = _position + distance;
        if (pos < 0 || pos >= _length)
            return EOT;
        return _text[pos];
    } // method lookAhead

    /// Test for lookAhead
    unittest {
        wstring text = null;
        auto navigator = new TextNavigator(text);
        assert(navigator.lookAhead() == EOT);
        assert(navigator.lookAhead(-1) == EOT);
        assert(navigator.lookAhead(1) == EOT);

        text = "";
        navigator = new TextNavigator(text);
        assert(navigator.lookAhead() == EOT);
        assert(navigator.lookAhead(-1) == EOT);
        assert(navigator.lookAhead(1) == EOT);

        text = "Hello";
        navigator = new TextNavigator(text);
        assert(navigator.lookAhead() == 'e');
        assert(navigator.lookAhead(-1) == EOT);
        assert(navigator.lookAhead(2) == 'l');
    } // unittest

    /// Look behind.
    pure wchar lookBehind(int distance = 1) const {
        const pos = _position - distance;
        if (pos < 0 || pos >= _length)
            return '\0';
        return _text[pos];
    } // method lookBehind

    /// Test for lookBehind
    unittest {
        wstring text = null;
        auto navigator = new TextNavigator(text);
        assert(navigator.lookBehind() == EOT);
        assert(navigator.lookBehind(-1) == EOT);
        assert(navigator.lookBehind(1) == EOT);

        text = "";
        navigator = new TextNavigator(text);
        assert(navigator.lookBehind() == EOT);
        assert(navigator.lookBehind(-1) == EOT);
        assert(navigator.lookBehind(1) == EOT);

        text = "Hello";
        navigator = new TextNavigator(text);
        assert(navigator.lookBehind() == EOT);
        assert(navigator.lookBehind(-1) == 'e');
        assert(navigator.lookBehind(2) == EOT);
    } // unittest

    /// Move to relative position.
    TextNavigator move(int distance) {
        // TODO implement properly
        _position += distance;
        _column += distance;
        return this;
    } // method move

    /// Peek one char.
    pure wchar peekChar() const nothrow {
        if ((_position < 0) || (_position >= _length))
            return EOT;
        return _text[_position];
    } // method peekChar()

    /// Test for peekChar
    unittest {
        wstring text = null;
        auto navigator = new TextNavigator(text);
        assert (navigator.peekChar() == EOT);

        text = "";
        navigator = new TextNavigator(text);
        assert (navigator.peekChar() == EOT);

        text = "Hello";
        navigator = new TextNavigator(text);
        assert (navigator.peekChar() == 'H');
    }

    /// Read one char.
    wchar readChar() {
        if ((_position < 0) || (_position >= _length))
            return EOT;
        const result = _text[_position];
        _position++;
        if (result == '\n') {
            _line++;
            _column = 1;
        } else {
            _column++;
        }
        return result;
    } // method readChar

    /// Test for readChar
    unittest {
        wstring text = null;
        auto navigator = new TextNavigator(text);
        assert (navigator.readChar() == EOT);
        assert (navigator.readChar() == EOT);

        text = "";
        navigator = new TextNavigator(text);
        assert (navigator.readChar() == EOT);
        assert (navigator.readChar() == EOT);

        text = "Hello";
        navigator = new TextNavigator(text);
        assert (navigator.readChar() == 'H');
        assert (navigator.position == 1);
        assert (navigator.readChar() == 'e');
        assert (navigator.position == 2);
        assert (navigator.readChar() == 'l');
        assert (navigator.position == 3);
        assert (navigator.readChar() == 'l');
        assert (navigator.position == 4);
        assert (navigator.readChar() == 'o');
        assert (navigator.position == 5);
        assert (navigator.readChar() == EOT);
        assert (navigator.position == 5);
        assert (navigator.readChar() == EOT);
    }

    /// Peek string.
    string peekString(int length) const {
        if (eot || length <= 0)
            return null;

        const start = _position;
        int offset = 0;
        for(offset = 0; offset < length; offset++) {
            const c = charAt(start + offset);
            if (c == EOT || c == '\r' || c == '\n')
                break;
        }

        auto result = mid(start, offset);
        return result;
    } // method peekString

    /// Test for peekString
    unittest {
        auto text = "Hello world";
        auto navigator = new TextNavigator(text);
        assert(navigator.peekString(5) == "Hello");
        navigator.readTo(' ');
        assert(navigator.peekString(10) == "world");
    } // unittest

    /// Peek string.
    string peekTo(wchar stopChar) const {
        if (eot)
            return null;

        int end = _position;
        while (end < _length) {
            const c = _text[end];
            if (c == stopChar) {
                end++;
                break;
            }
            if (c == '\r' || c == '\n')
                break;
            end++;
        }
        return mid(_position, end - _position);
    } // method peekTo

    /// Peek string.
    string peekUntil(wchar stopChar) const {
        if (eot)
            return null;

        int end = _position;
        while (end < _length) {
            const c = _text[end];
            if (c == stopChar || c == '\r' || c == '\n')
                break;
            end++;
        }
        return mid(_position, end - _position);
    } // method peekUntil

    /// Read one line.
    string readLine() {
        if (eot)
            return null;

        const start = _position;
        while (_position < _length) {
            const c = _text[_position];
            if (c == '\r' || c == '\n')
                break;
            readChar();
        }

        auto result = mid(start, _position - start);
        if (_position < _length) {
            wchar c = cast()(_text[_position]);
            if (c == '\r') {
                readChar();
                c = peekChar();
            }

            if (c == '\n')
                readChar();
        }

        return result;
    } // method readLine

    /// Is control character?
    pure bool isControl() const nothrow {
        const c = peekChar();
        return c > 0 && c < ' ';
    } // method isControl

    /// Is digit?
    pure bool isDigit() const nothrow {
        const c = peekChar();
        return isNumber(c);
    } // method isDigit

    /// Is letter?
    pure bool isLetter() const nothrow {
        const c = peekChar();
        return isAlpha(c);
    } // method isLetter

    /// Is whitespace?
    pure bool isWhitespace() const nothrow {
        const c = peekChar();
        return isWhite(c);
    } // method isWhitespace

    /// Read integer number.
    string readInteger() {
        if (eot || !isDigit)
            return null;

        const start = _position;
        while (!eot && isDigit) {
            readChar();
        }
        return mid(start, _position - start);
    } // method readInteger

    /// Test for readInteger
    unittest {
        auto text = "Hello123world";
        auto navigator = new TextNavigator(text);
        assert(navigator.readInteger() == null);
        navigator.readString(5);
        assert(navigator.readInteger() == "123");
        assert(navigator.readInteger() == null);
    } // unittest

    /// Read string.
    string readString(int length) {
        if (eot || length <= 0)
            return null;

        const start = _position;
        for(int i = 0; i < length; i++) {
            const c = readChar();
            if (c == EOT || c == '\r' || c == '\n')
                break;
        }

        auto result = mid(start, _position-start);
        return result;
    } // method readString

    /// Test for readString
    unittest {
        auto text = "Hello world";
        auto navigator = new TextNavigator(text);
        assert(navigator.readString(5) == "Hello");
        assert(navigator.readChar() == ' ');
        assert(navigator.readString(10) == "world");
    } // unittest

    /// Read string.
    string readTo(wchar stopChar) {
        if (eot)
            return null;

        const start = _position;
        auto end = _position;
        while (true) {
            const c = readChar();
            if (c == EOT || c == stopChar)
                break;
            end = _position;
        }

        auto result = mid(start, end-start);
        return result;
    } // method readTo

    /// Test for readTo
    unittest {
        auto text = "Hello world";
        auto navigator = new TextNavigator(text);
        assert(navigator.readTo(' ') == "Hello");
        assert(navigator.readTo(' ') == "world");
        assert(navigator.readTo(' ') == null);
    } // unittest

    /// Read string.
    string readUntil(wchar stopChar) {
        if (eot)
            return null;

        const start = _position;
        while (true) {
            const c = peekChar();
            if (c == EOT || c == stopChar)
                break;
            readChar();
        }

        auto result = mid(start, _position - start);
        return result;
    } // method readUntil

    /// Test for readUntil
    unittest {
        auto text = "Hello world";
        auto navigator = new TextNavigator(text);
        assert(navigator.readUntil(' ') == "Hello");
        assert(navigator.readChar() == ' ');
        assert(navigator.readUntil(' ') == "world");
        assert(navigator.readUntil(' ') == null);
    } // unittest

    /// Read string.
    string readWhile(wchar goodChar) {
        return null;
    } // method readWhile

    /// Read string.
    string readWord() {
        return null;
    } // method readWord

    /// Read string.
    string recentText(int length) {
        return null;
    } // method recentText

    /// Get remaining text.
    pure string remainingText() const {
        if (eot)
            return null;

        return mid(_position, _length - _position);
    } // method remainingText

    /// Test for remainingText()
    unittest {
        auto text = "Hello world";
        auto navigator = new TextNavigator(text);
        navigator.readTo(' ');
        assert(navigator.remainingText() == "world");
        navigator.readTo(' ');
        assert(navigator.remainingText() == null);
    } // unittest

    /// Skip whitespace.
    TextNavigator skipWhitespace() {
        while (!eot && isWhitespace)
            readChar;
        return this;
    } // method skipWhitespace

    /// Skip punctuaction.
    TextNavigator skipPunctuaction() {
        return this;
    } // method skipPunctuation

    /// Get substring.
    pure string mid(int offset, int length) const {
        auto result = _text[offset..offset+length];
        return to!string(result);
    } // method mid

    /// Test for mid.
    unittest {
        auto navigator = new TextNavigator("Hello");
        assert(navigator.mid(0, 0) == "");
        assert(navigator.mid(0, 4) == "Hell");
    } // unittest

} // class TextNavigator

//==================================================================

/**
 * Part of NumberText (see).
 */
struct NumberChunk
{
    string prefix; /// Prefix.
    long value; /// Numeric value.
    int length; /// Length.
    bool haveValue; /// Have value?
} // struct NumberChunk

//==================================================================

/**
 * Text with numbers.
 */
final class NumberText
{
    private NumberChunk[] chunks; /// Slice of chunks.
    private ref NumberChunk lastChunk() {
        return chunks[$-1];
    }

    /// Constructor.
    this() {
    } // constructor

    /// Test for default constructor
    unittest {
        auto number = new NumberText;
        assert(number.empty);
        assert(number.length == 0);
    } // unittest

    /// Constructor.
    this(string text) {
    } // constructor

    /// Append chunk.
    NumberText append
        (
            string prefix="",
            bool haveValue=true,
            long value=0,
            int length=0
        )
    {
        NumberChunk chunk;
        chunk.prefix = prefix;
        chunk.haveValue = haveValue;
        chunk.value = value;
        chunk.length = length;
        chunks ~= chunk;
        return this;
    } // method append

    /// Whether the number is empty?
    pure bool empty() const {
        return chunks.empty;
    } // method empty

    /// Get prefix for index.
    pure string getPrefix(int index) const {
        return null;
    } // method getPrefix

    /// Get value for index.
    pure long getValue(int index) const {
        return 0;
    } // method getValue

    /// Increment the last chunk.
    NumberText increment(int delta=1) {
        return this;
    } // method increment

    /// Increment the given chunk.
    NumberText increment(int index, int delta=1) {
        return this;
    } // method increment

    /// Get the length.
    pure int length() const {
        return cast(int)(chunks.length);
    } // method length

    override string toString() const {
        return null;
    } // method toString

} // class NumberText
