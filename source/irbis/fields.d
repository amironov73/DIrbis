/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

module irbis.fields;

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

/**
 * Information about book.
 */
final class BookInfo
{
    MarcRecord record; /// Record.
    int amount; /// Count of copies.
    string firstAuthor; /// First author.
    string[] authors; /// All authors.
    string description; /// Bibliographical description.

    /// Document character.
    string documentCharacter() const {
        return record.fm(900, 'c');
    } // method documentCharacter

    /// Document type.
    string documentType() const {
        return record.fm(900, 't');
    } // method documentType

    /// Electronic document?
    bool electronic() const {
        // TODO implement
        return false;
    } // method electronic

    /// Exemplars
    ExemplarInfo[] exemplars() const {
        // TODO implement
        return [];
    } // method exemplars

    /// Count of copies.
    int exemplarCount() const {
        int result = 0;
        foreach(exemplar; exemplars) {
            const status = exemplar.status;
            if (status != "0" && status != "1"
                && status != "5" && status != "9")
                continue;

            auto amount = exemplar.amount.parseInt();
            if (!amount)
                amount = 1;

            result += amount;
        }
        return result;
    } // method exemplarCount

    /// Foreign language?
    bool foreign() const {
        const langs = languages;
        if (langs.empty)
            return false;

        return !sameString(languages[0], "rus");
    } // method foreign

    /// Slice of languages.
    string[] languages() const {
        return record.fma(101);
    } // method languages

} // class BookInfo

//==================================================================

/**
 * Information about document exemplar (field 910).
 */
final class ExemplarInfo
{
    string status; /// Status. Subfield a.
    string number; /// Inventory number. Subfield b.
    string date; /// Receipt date. Subfield c.
    string place; /// Storage. Subfield d.
    string collection; /// Collection. Subfield q.
    string shelfIndex; /// Shelf index. Subfield r.
    string price; /// Price of the exemplar. Subfield e.
    string barcode; /// Barcode or RFID. Subfield h.
    string amount; /// Copies count. Subfield 1.
    string purpose; /// Purpose. Subfield t.
    string coefficient; /// Reusable coefficient. Subfield =.
    string offBalance; /// Off-balance exemplar. Subfield 4.
    string ksuNumber1; /// KSU record number. Subfield u.
    string actNumber1; /// Number of act. Subfield y.
    string channel; /// Income channel. Subfield f.
    string onHand; /// Loaned copies count. Subfield 2.
    string actNumber2; /// Number of cancellation act. Subfield v.
    string writeOff; /// Cancelled copies count. Subfield x.
    string completion; /// Complete copies count. Subfield k.
    string actNumber3; /// Transfer act number. Subfield w.
    string moving; /// Transfer copies count. Subfield z.
    string newPlace; /// New storage place. Subfield m.
    string checkDate; /// Date of the inventarization. Subfield s.
    string checkAmount; /// Checked copies count. Subfield 0.
    string realPlace; /// Real storage place. Subfield !.
    string bindingIndex; /// Binding index. Subfield p.
    string bindingNumber; /// Binding number. Subfield i.

    /// Apply to the field.
    void applyTo(RecordField field) {
        field
            .setSubField('a', status)
            .setSubField('b', number)
            .setSubField('c', date)
            .setSubField('d', place)
            .setSubField('q', collection)
            .setSubField('r', shelfIndex)
            .setSubField('e', price)
            .setSubField('h', barcode)
            .setSubField('1', amount)
            .setSubField('t', purpose)
            .setSubField('=', coefficient)
            .setSubField('4', offBalance)
            .setSubField('u', ksuNumber1)
            .setSubField('y', actNumber1)
            .setSubField('f', channel)
            .setSubField('2', onHand)
            .setSubField('v', actNumber2)
            .setSubField('x', writeOff)
            .setSubField('k', completion)
            .setSubField('w', actNumber3)
            .setSubField('z', moving)
            .setSubField('m', newPlace)
            .setSubField('s', checkDate)
            .setSubField('0', checkAmount)
            .setSubField('!', realPlace)
            .setSubField('p', bindingIndex)
            .setSubField('i', bindingNumber);
    } // method applyTo

    /// Parse the field.
    static ExemplarInfo parse(RecordField field) {
        auto result = new ExemplarInfo;
        result.status = field.getFirstSubFieldValue('a');
        result.number = field.getFirstSubFieldValue('b');
        result.date = field.getFirstSubFieldValue('c');
        result.place = field.getFirstSubFieldValue('d');
        result.collection = field.getFirstSubFieldValue('q');
        result.shelfIndex = field.getFirstSubFieldValue('r');
        result.price = field.getFirstSubFieldValue('e');
        result.barcode = field.getFirstSubFieldValue('h');
        result.amount = field.getFirstSubFieldValue('1');
        result.purpose = field.getFirstSubFieldValue('t');
        result.coefficient = field.getFirstSubFieldValue('=');
        result.offBalance = field.getFirstSubFieldValue('4');
        result.ksuNumber1 = field.getFirstSubFieldValue('u');
        result.actNumber1 = field.getFirstSubFieldValue('y');
        result.channel = field.getFirstSubFieldValue('f');
        result.onHand = field.getFirstSubFieldValue('2');
        result.actNumber2 = field.getFirstSubFieldValue('v');
        result.writeOff = field.getFirstSubFieldValue('x');
        result.completion = field.getFirstSubFieldValue('k');
        result.actNumber3 = field.getFirstSubFieldValue('w');
        result.moving = field.getFirstSubFieldValue('z');
        result.newPlace = field.getFirstSubFieldValue('m');
        result.checkDate = field.getFirstSubFieldValue('s');
        result.checkAmount = field.getFirstSubFieldValue('0');
        result.realPlace = field.getFirstSubFieldValue('!');
        result.bindingIndex = field.getFirstSubFieldValue('p');
        result.bindingNumber = field.getFirstSubFieldValue('i');
        return result;
    } // method parse

    /// Parse the record.
    static ExemplarInfo[] parse(MarcRecord record) {
        ExemplarInfo[] result;
        auto fields = record.getFields(910);
        foreach(field; fields) {
            auto exemplar = parse(field);
            result ~= exemplar;
        }
        return result;
    } // method parse

    /// Convert to record field.
    RecordField toField() {
        auto result = new RecordField(910)
            .appendNonEmpty('a', status)
            .appendNonEmpty('b', number)
            .appendNonEmpty('c', date)
            .appendNonEmpty('d', place)
            .appendNonEmpty('q', collection)
            .appendNonEmpty('r', shelfIndex)
            .appendNonEmpty('e', price)
            .appendNonEmpty('h', barcode)
            .appendNonEmpty('1', amount)
            .appendNonEmpty('t', purpose)
            .appendNonEmpty('=', coefficient)
            .appendNonEmpty('4', offBalance)
            .appendNonEmpty('u', ksuNumber1)
            .appendNonEmpty('y', actNumber1)
            .appendNonEmpty('f', channel)
            .appendNonEmpty('2', onHand)
            .appendNonEmpty('v', actNumber2)
            .appendNonEmpty('x', writeOff)
            .appendNonEmpty('k', completion)
            .appendNonEmpty('w', actNumber3)
            .appendNonEmpty('z', moving)
            .appendNonEmpty('m', newPlace)
            .appendNonEmpty('s', checkDate)
            .appendNonEmpty('0', checkAmount)
            .appendNonEmpty('!', realPlace)
            .appendNonEmpty('p', bindingIndex)
            .appendNonEmpty('i', bindingNumber);

            return result;
    } // method toField

} // class ExemplarInfo
