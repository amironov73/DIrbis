/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

module irbis.builder;

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

/// Search expresssion builder.
final class Search
{
    private string _buffer;

    /// All documents in the database.
    static Search all() {
        auto result = new Search;
        result._buffer = "I=$";
        return result;
    } // method all

    /// Logical AND.
    Search and(string[] items...) {
        _buffer = "(" ~ _buffer;
        foreach(item; items) {
            _buffer = _buffer
                ~ " * "
                ~ wrapIfNeeded(item);
        }
        _buffer = _buffer ~ ")";
        return this;
    } // method and

    /// Logical AND.
    Search and(Search[] items...) {
        _buffer = "(" ~ _buffer;
        foreach(item; items) {
            _buffer = _buffer
                ~ " * "
                ~ wrapIfNeeded(item);
        }
        _buffer = _buffer ~ ")";
        return this;
    } // method and

    /// Need to wrap the text?
    static bool needWrap(string text) {
        if (text.empty)
            return true;

        const c = text[0];
        if (c == '"' || c == '(')
            return false;

        if (canFind(text, ' ')
            || canFind(text, '+')
            || canFind(text, '*')
            || canFind(text, '(')
            || canFind(text, ')')
            || canFind(text, '"'))
            return true;

        return false;
    } // method needWrap

    /// Search for matching records.
    static Search equals(string prefix, string[] values...) {
        auto result = new Search;
        auto text = wrapIfNeeded(prefix ~ values[0]);
        if (values.length > 1) {
            text = "(" ~ text;
            for (int i = 1; i < values.length; i++)
                text = text ~ " + " ~ wrapIfNeeded(prefix ~ values[i]);
            text ~= ")";
        }
        result._buffer = text;
        return result;
    } // method equals

    /// Logical NOT.
    Search not(string text) {
        _buffer = "(" ~ _buffer ~ " ^ " ~ wrapIfNeeded(text) ~ ")";
        return this;
    } // method not

    /// Logical NOT.
    Search not(Search search) {
        return not(search.toString);
    } // method not

    /// Logical OR.
    Search or(string[] items...) {
        _buffer = "(" ~ _buffer;
        foreach(item; items) {
            _buffer = _buffer
                ~ " + "
                ~ wrapIfNeeded(item);
        }
        _buffer = _buffer ~ ")";
        return this;
    } // method or

    /// Logical OR.
    Search or(Search[] items...) {
        _buffer = "(" ~ _buffer;
        foreach(item; items) {
            _buffer = _buffer
                ~ " + "
                ~ wrapIfNeeded(item);
        }
        _buffer = _buffer ~ ")";
        return this;
    } // method or

    /// Logical "Same Field".
    Search sameField(string[] items...) {
        _buffer = "(" ~ _buffer;
        foreach(item; items) {
            _buffer = _buffer
                ~ " (G) "
                ~ wrapIfNeeded(item);
        }
        _buffer = _buffer ~ ")";
        return this;
    } // method sameField

    /// Logical "Same Field".
    Search sameField(Search[] items...) {
        _buffer = "(" ~ _buffer;
        foreach(item; items) {
            _buffer = _buffer
                ~ " (G) "
                ~ wrapIfNeeded(item);
        }
        _buffer = _buffer ~ ")";
        return this;
    } // method sameField

    /// Logical "Same Field Repeat".
    Search sameRepeat(string[] items...) {
        _buffer = "(" ~ _buffer;
        foreach(item; items) {
            _buffer = _buffer
                ~ " (F) "
                ~ wrapIfNeeded(item);
        }
        _buffer = _buffer ~ ")";
        return this;
    } // method sameRepeat

    /// Logical "Same Field Repeat".
    Search sameRepeat(Search[] items...) {
        _buffer = "(" ~ _buffer;
        foreach(item; items) {
            _buffer = _buffer
                ~ " (F) "
                ~ wrapIfNeeded(item);
        }
        _buffer = _buffer ~ ")";
        return this;
    } // method sameRepeat


    /// Wrap the text if needed.
    static string wrapIfNeeded(string text) {
        if (needWrap(text))
            return "\"" ~ text ~ "\"";
        return text;
    } // method wrapIfNeeded

    /// Wrap the text if needed.
    static string wrapIfNeeded(Search search) {
        const text = search.toString;
        return wrapIfNeeded(text);
    } // method wrapIfNeeded

    override string toString() const {
        return _buffer;
    } // method toString

} // class Search

/// Search by keyword.
Search keyword(string[] values...) {
    return Search.equals("K=", values);
} // function keyword

/// Search by author.
Search author(string[] values...) {
    return Search.equals("A=", values);
} // function author

/// Search by title.
Search title(string[] values...) {
    return Search.equals("T=", values);
} // function title

/// Search by number.
Search number(string[] values...) {
    return Search.equals("IN=", values);
} // function number

/// Search by publisher.
Search publisher(string[] values...) {
    return Search.equals("O=", values);
} // function publisher

/// Search by place.
Search place(string[] values...) {
    return Search.equals("MI=", values);
} // function place

/// Search by subject.
Search subject(string[] values...) {
    return Search.equals("S=", values);
} // function subject

/// Search by language.
Search language(string[] values...) {
    return Search.equals("J=", values);
} // function language

/// Search by year.
Search year(string[] values...) {
    return Search.equals("G=", values);
} // function year

/// Search by magazine.
Search magazine(string[] values...) {
    return Search.equals("TJ=", values);
} // function magazine

/// Search by document kind.
Search documentKind(string[] values...) {
    return Search.equals("V=", values);
} // function documentKind

/// Search by UDC.
Search udc(string[] values...) {
    return Search.equals("U=", values);
} // function udc

/// Search by BBK.
Search bbk(string[] values...) {
    return Search.equals("BBK=", values);
} // function bbk

/// Search by section of knowledge.
Search rzn(string[] values...) {
    return Search.equals("RZN=", values);
} // function rzn

/// Search by storage place.
Search mhr(string[] values...) {
    return Search.equals("MHR=", values);
} // function mhr

/// Tests for functions: keyword, author, title, number
unittest {
    assert("K=1" == keyword("1").toString);
    assert("(K=1 * T=2)" == keyword("1").and(title("2")).toString);
    assert("(K=1 + A=2)" == keyword("1").or(author("2")).toString);
    assert("(K=1 ^ IN=2)" == keyword("1").not(number("2")).toString);
} // unittest
