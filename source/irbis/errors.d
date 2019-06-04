/*
 * Client for IRBIS64 library system.
 * Alexey Mironov, 2019.
 * MIT License.
 */

module irbis.errors;

/**
 * Get error description by the code.
 */
pure string describeError(scope int code) nothrow {
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

//==================================================================

/**
 * IRBIS-specific errors.
 */
class IrbisException : Exception {
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
