/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

module irbis.records;

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

import irbis.constants, irbis.utils;

//==================================================================

/**
 * Subfield consist of a code and value.
 */
final class SubField
{
    char code; /// One-symbol code of the subfield.
    string value; /// String value of the subfield.

    /// Constructor.
    this() {
        // Nothing to do here
    } // constructor

    /// Test for default constructor
    unittest {
        auto subfield = new SubField;
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
        const second = first.clone;
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
        value = text[1..$]; // TODO: dup?
    } // method decode

    /// Test for decode
    unittest {
        auto subfield = new SubField;
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
final class RecordField
{
    int tag; /// Numerical tag of the field.
    string value; /// String value of the field.
    SubField[] subfields; /// Subfields.

    /// Constructor.
    this(int tag=0, string value="") {
        this.tag = tag;
        this.value = value;
    } // constructor

    /// Test for constructor
    unittest {
        auto field = new RecordField(100, "Value");
        assert(field.tag == 100);
        assert(field.value == "Value");
        assert(field.subfields.empty);
    } // unittest

    /**
     * Append subfield with specified code and value.
     */
    RecordField append(char code, string value) {
        auto subfield = new SubField(code, value);
        subfields ~= subfield;
        return this;
    } // method append

    /// Test for append
    unittest {
        auto field = new RecordField;
        field.append('a', "SubA");
        assert(field.subfields.length == 1);
        assert(field.subfields[0].code == 'a');
        assert(field.subfields[0].value == "SubA");
    } // unittest

    /**
     * Append subfield with specified code and value
     * if value is non-empty.
     */
    RecordField adppendNonEmpty(char code, string value) {
        return value.empty ? this : append(code, value);
    } // method appendNonEmpty

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
        auto field = new RecordField;
        field.append('a', "SubA");
        field.clear;
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
    pure SubField getFirstSubField(char code) {
        foreach (subfield; subfields)
            if (sameChar(subfield.code, code))
                return subfield;
        return null;
    } // method getFirstSubfield

    /**
     * Get value of first subfield with given code.
     */
    pure string getFirstSubFieldValue(char code) {
        foreach (subfield; subfields)
            if (sameChar(subfield.code, code))
                return subfield.value;
        return null;
    } // method getFirstFieldValue

    /**
     * Computes value for ^*.
     */
    pure string getValueOrFirstSubField() {
        auto result = value;
        if (result.empty)
            if (!subfields.empty)
                result = subfields[0].value;
        return result;
    } // method getValueOrFirstSubField

    /**
     * Do we have any subfield with given code?
     */
    pure bool haveSubField(char code) const {
        foreach (subfield; subfields)
            if (sameChar(subfield.code, code))
                return true;
        return false;
    } // method haveSubField

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
        size_t index = 0;
        while (index < subfields.length) {
            if (sameChar(subfields[index].code, code))
                removeAt (index);
            else
                index++;
        }
        return this;
    } // method removeSubField

    /**
     * Replace value for subfields with specified code.
     */
    RecordField replaceSubField(char code, string oldValue, string newValue) {
        foreach(subfield; subfields)
            if (sameChar(subfield.code, code)
                && sameString(subfield.value, oldValue))
                subfield.value = newValue;
        return this;
    } // method replaceSubField

    /**
     * Set the value of first occurence of the subfield.
     */
    RecordField setSubField(char code, string value) {
        if (value.empty)
            return removeSubField(code);
        auto subfield = getFirstSubField(code);
        if (subfield is null) {
            subfield = new SubField(code, value);
            subfields ~= subfield;
        }
        subfield.value = value;
        return this;
    } // method setSubField

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
        if (result && !subfields.empty) {
            foreach (subfield; subfields) {
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
final class MarcRecord
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
     * Create deep clone of the record.
     */
    MarcRecord clone() const {
        auto result = new MarcRecord;
        result.database = this.database;
        result.mfn = this.mfn;
        result.versionNumber = this.versionNumber;
        result.status = this.status;
        result.fields.reserve(this.fields.length);
        foreach(field; fields)
            result.fields ~= field.clone;
        return result;
    } // method clone

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
     * Determine whether the record is marked as deleted.
     */
    pure bool deleted() const {
        return (status & 3) != 0;
    } // method deleted

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
     * Do we have any field with specified tag?
     */
    pure bool haveField(int tag) const {
        foreach(field; fields)
            if  (field.tag == tag)
                return true;
        return false;
    } // method haveField

    /**
     * Do we have any subfield with specified tag and code?
     */
    pure bool haveSubField(int tag, char code) const {
        foreach (field; fields)
            if (field.tag == tag)
                foreach (subfield; field.subfields)
                    if (sameChar(subfield.code, code))
                        return true;
        return false;
    } // method haveSubField

    /**
     * Insert the field at given index.
     */
    MarcRecord insertAt(size_t index, RecordField field) {
        arrayInsert(fields, index, field);
        return this;
    } // method insertAt

    /**
     * Remove field at specified index.
     */
    MarcRecord removeAt(size_t index) {
        arrayRemove(fields, index);
        return this;
    } // method removeAt

    /**
     * Remove all fields with specified tag.
     */
    MarcRecord removeField(int tag) {
        size_t index = 0;
        while (index < fields.length) {
            if (fields[index].tag == tag)
                removeAt (index);
            else
                index++;
        }
        return this;
    } // method removeField

    /**
     * Reset record state, unbind from database.
     * Fields remains untouched.
     */
    MarcRecord reset() nothrow {
        mfn = 0;
        status = 0;
        versionNumber = 0;
        database = "";
        return this;
    } // method reset

    /**
     * Set the value of first occurence of the field.
     */
    MarcRecord setField(int tag, string value) {
        if (value.empty)
            return removeField(tag);
        auto field = getField(tag);
        if (field is null) {
            field = new RecordField(tag, value);
            fields ~= field;
        }
        field.value = value;
        return this;
    } // method setField

    /**
     * Set the value of first occurence of the subfield.
     */
    MarcRecord setSubField(int tag, char code, string value) {
        auto field = getField(tag);
        if (field is null) {
            if (value.empty)
                return this;
            field = new RecordField(tag, value);
            fields ~= field;
        }
        field.setSubField(code, value);
        return this;
    } // method setField

    pure override string toString() const {
        return encode("\n");
    } // method toString

    /**
     * Verify all the fields.
     */
    pure bool verify() const {
        if (fields.empty)
            return false;
        foreach (field; fields)
            if (!field.verify)
                return false;
        return true;
    } // method verify

} // class MarcRecord

//==================================================================

/**
 * Half-parsed record.
 */
final class RawRecord
{
    string database; /// Database name.
    int mfn; /// Masterfile number
    int versionNumber; /// Version number
    int status; /// Status.
    string[] fields; /// Slice of fields.

    /**
     * Append the field.
     */
    RawRecord append(int tag, string value) {
        const text = to!string(tag) ~ "#" ~ value;
        fields ~= text;
        return this;
    } // method append

    /**
     * Creates deep clone of the record.
     */
    RawRecord clone() const {
        auto result = new RawRecord;
        result.database = this.database;
        result.mfn = this.mfn;
        result.versionNumber = this.versionNumber;
        result.status = this.status;
        result.fields = this.fields.dup;
        return result;
    } // method clone

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
        fields = lines[2..$]; // TODO dup?

        return true;
    } // method decode

    /**
     * Determine whether the record is marked as deleted.
     */
    pure bool deleted() const {
        return (status & 3) != 0;
    } // method deleted

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

        foreach (field; fields) {
            result.put(field);
            result.put(delimiter);
        }

        return result.toString;
    } // method encode

    /**
     * Insert the field at given index.
     */
    RawRecord insertAt(size_t index, string field) {
        arrayInsert(fields, index, field);
        return this;
    } // method insertAt

    /**
     * Remove field at specified index.
     */
    RawRecord removeAt(size_t index) {
        arrayRemove(fields, index);
        return this;
    } // method removeAt

    /**
     * Reset record state, unbind from database.
     * Fields remains untouched.
     */
    RawRecord reset() nothrow {
        mfn = 0;
        status = 0;
        versionNumber = 0;
        database = "";
        return this;
    } // method reset

    /**
     * Convert to MarcRecord.
     */
    MarcRecord toMarcRecord() const {
        auto result = new MarcRecord;
        result.database = this.database;
        result.mfn = this.mfn;
        result.status = this.status;
        result.versionNumber = this.versionNumber;
        result.fields.reserve(this.fields.length);
        foreach (line; fields) {
            auto field = new RecordField;
            field.decode(line);
            result.fields ~= field;
        }
        return result;
    } // method toMarcRecord

    pure override string toString() const {
        return encode("\n");
    } // method toString

} // class RawRecord
