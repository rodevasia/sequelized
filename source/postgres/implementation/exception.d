module postgres.implementation.exception;

public:
import std.conv;

private import postgres.implementation.implementationc;


class PGSqlException : Throwable
{
    string code;
    string sqlState;
    string message;
    this(PGconn* conn, PGresult* res = null)
    {
        if (res != null)
        {
            char* c = PQresultVerboseErrorMessage(res, PGVerbosity.PQERRORS_VERBOSE, PGContextVisibility
                    .PQSHOW_CONTEXT_ALWAYS);
            char* s = PQresultVerboseErrorMessage(res, PGVerbosity.PQERRORS_SQLSTATE, PGContextVisibility
                    .PQSHOW_CONTEXT_ALWAYS);
           string ss = to!string(c);
           import std.string:split;
           this.code = ss.split(':')[1];

            this.sqlState = to!string(s);
        }
        const char* m = PQerrorMessage(conn);

        this.message = to!string(m);
        super(this.message);
    }
}
