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

//==================================================================

/**
 * Simple text navigation.
 */
export final class TextNavigator
{
    int _column, _line, _position;
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
        return _text[pos];
    } // method charAt

    /// Look ahead.
    pure wchar lookAhead(int distance = 1) const {
        return _text[_position + distance];
    } // method lookAhead

    /// Look behind.
    pure wchar lookBehind(int distance = 1) const {
        return _text[_position - distance];
    } // method lookBehind

    /// Move to relative position.
    TextNavigator move(int distance) {
        _position += distance;
        return this;
    } // method move

    /// Peek one char.
    pure wchar peekChar() const {
        return 0;
    } // method peekChar()

    /// Read one char.
    wchar readChar() {
        const result = _text[_position];
        _position++;
        return result;
    } // method readChar

    /// Peek string.
    string peekString(int length) const {
        return null;
    } // method peekString

    /// Peek string.
    string peekTo(wchar stopChar) const {
        return null;
    } // method peekTo

    /// Peek string.
    string peekUntil(wchar stopChar) const {
        return null;
    } // method peekUntil

    /// Read one line.
    string readLine() {
        return null;
    } // method readLine

    /// Is control character?
    pure bool isControl() const nothrow {
        return false;
    } // method isControl

    /// Is digit?
    pure bool isDigit() const nothrow {
        return false;
    } // method isDigit

    /// Is letter?
    pure bool isLetter() const nothrow {
        return false;
    } // method isLetter

    /// Is whitespace?
    pure bool isWhitespace() const nothrow {
        return false;
    } // method isWhitespace

    /// Read integer number.
    string readInteger() {
        return null;
    } // method readInteger

    /// Read string.
    string readString(int length) {
        return null;
    } // method readString

    /// Read string.
    string readTo(wchar stopChar) {
        return null;
    } // method readTo

    /// Read string.
    string readUntil(wchar stopChar) {
        return null;
    } // method readUntil

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
        return null;
    } // method remainingText

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
        return null;
    } // method mid

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
export final class NumberText
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
