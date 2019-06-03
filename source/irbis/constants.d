/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

module irbis.constants;

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
