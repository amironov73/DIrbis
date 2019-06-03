/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

module irbis.encoding;

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

import irbis.utils;

//==================================================================

/**
 * Text encoding.
 */
export abstract class Encoding
{
    /**
     * Encode the text.
     */
    abstract ubyte[] encode(string text);

    /**
     * Decode the buffer.
     */
    abstract string decode(const ubyte[] buffer);

    private static AnsiEncoding _ansi;
    private static UtfEncoding _utf;

    static AnsiEncoding ansi() {
        if (_ansi is null)
            _ansi = new AnsiEncoding;
        return _ansi;
    } // method ansi

    static UtfEncoding utf() {
        if (_utf is null)
            _utf = new UtfEncoding;
        return _utf;
    } // method utf

} // class Encoding

/**
 * ANSI encoding (windows code page 1251).
 */
export final class AnsiEncoding : Encoding
{
    override {
        ubyte[] encode(string text) {
            return toAnsi(text);
        } // encode

        string decode(const ubyte[] buffer) {
            return fromAnsi(buffer);
        } // decode
    } // override
} // class Win1251Encoding

/**
 * UTF-8 encoding.
 */
export final class UtfEncoding : Encoding
{
    override {
        ubyte[] encode(string text) {
            return toUtf(text);
        } // encode

        string decode(const ubyte[] buffer) {
            return fromUtf(buffer);
        } // decode
    } // override
} // class UtfEncoding
