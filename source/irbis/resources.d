/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

module irbis.resources;

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
 * File on the server.
 */
final class IrbisResource {
    string name; /// File name
    string content; /// Content

    /// Constructor.
    this() {
        this.name = "";
        this.content = "";
    } // constructor

    /// Constructor.
    this(string name, string content) {
        this.name = name;
        this.content = content;
    } // constructor

    override string toString() const {
        return this.name ~ ": " ~ this.content;
    } // method toString

} // class IrbisResource

/**
 * Dictionary of the server resources.
 */
final class ResourceDictionary {
    private IrbisResource[string] _dictionary;

    /// Add the resource.
    ResourceDictionary add(string name, string content) {
        _dictionary[name] = new IrbisResource(name, content);
        return this;
    } // method add

    /// Slice of all resources.
    IrbisResource[] all() const {
        IrbisResource[] result;
        reserve(result, _dictionary.length);
        foreach(key; _dictionary.keys) {
            result ~= cast(IrbisResource)_dictionary[key];
        }
        return result;
    } // method all

    /// Clear the dictionary.
    ResourceDictionary clear() {
        _dictionary.clear;
        return this;
    } // method clear

    /// Item count.
    size_t count() const {
        return _dictionary.length;
    } // method count

    /// Get the resource by name
    string get(string name) const {
        const ptr = name in _dictionary;
        return ptr is null ? "" : ptr.content;
    } // method get

    /// Whether we have resource with given name.
    bool have(string name) const {
        return (name in _dictionary) !is null;
    } // method have

    /// Put specified resource to the dictionary.
    ResourceDictionary put(string name, string content) {
        _dictionary[name] = new IrbisResource(name, content);
        return this;
    }

    /// Remove specified resource from the dictionary.
    ResourceDictionary remove(string name) {
        _dictionary.remove(name);
        return this;
    } // method remove

} // class ResourceDictionary