module sequalized.error_handlers;

import sequalized.pg.implementationc;
import std.conv;
import std.regex;

class QueryGeneratorException : Exception
{
    this(string message)
    {
        super(message);
    }
}

class PGSqlException : Exception
{
    string code;
    string sqlState;
    string message;
    string verboseMessage;
    this(PGconn* conn, PGresult* res = null)
    {
        if (res != null)
        {
            char* c = PQresultVerboseErrorMessage(res, PGVerbosity.PQERRORS_VERBOSE, PGContextVisibility
                    .PQSHOW_CONTEXT_ALWAYS);
            char* s = PQresultVerboseErrorMessage(res, PGVerbosity.PQERRORS_SQLSTATE, PGContextVisibility
                    .PQSHOW_CONTEXT_ALWAYS);
            string ss = to!string(c);
            import std.string : split;
            import std.array : join;

            this.code = to!string(ss.split(':')[1]);

            this.sqlState = to!string(s);
            string[] parts = ss.split(':');
            parts[2] = parts[2].split("\n")[0];
            this.verboseMessage = parts[0 .. 3].join(":");
        }
        const char* m = PQerrorMessage(conn);

        this.message = to!string(m);
        super(this.message);
    }
}

class DuplicateKeyException : Exception
{
    this(string message)
    {
        super(message);
    }
}
