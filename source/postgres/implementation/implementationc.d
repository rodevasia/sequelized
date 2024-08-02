module postgres.implementation.implementationc;

extern (C)
{
    struct PGconn
    {
    }

    struct PGresult
    {
    }

    void PQfinish(PGconn*);
    
    PGconn* PQconnectdb(const char*);

    int PQstatus(PGconn*); // FIXME check return value

    const(char*) PQerrorMessage(PGconn*);

    char* PQresultVerboseErrorMessage(const PGresult* res,
        PGVerbosity verbosity,
        PGContextVisibility show_context);
    PGresult* PQexec(PGconn*, const char*);
    void PQclear(PGresult*);

    PGresult* PQprepare(PGconn*, const char* stmtName, const char* query,
        int nParams, const void* paramTypes);

    PGresult* PQexecPrepared(PGconn*, const char* stmtName,
        int nParams, const char** paramValues,
        const int* paramLengths, const int* paramFormats, int resultFormat);

    int PQresultStatus(PGresult*); // FIXME check return value

    int PQnfields(PGresult*); // number of fields in a result
    const(char*) PQfname(PGresult*, int); // name of field

    int PQntuples(PGresult*); // number of rows in result
    const(char*) PQgetvalue(PGresult*, int row, int column);

    size_t PQescapeString(char* to, const char* from, size_t length);

    enum int CONNECTION_OK = 0;
    enum int PGRES_COMMAND_OK = 1;
    enum int PGRES_TUPLES_OK = 2;
    enum int PGRES_FATAL_ERROR = 7;
    enum PGContextVisibility
    {
        PQSHOW_CONTEXT_NEVER,
        PQSHOW_CONTEXT_ERRORS,
        PQSHOW_CONTEXT_ALWAYS
    }

    enum PGVerbosity
    {
        PQERRORS_TERSE,
        PQERRORS_DEFAULT,
        PQERRORS_VERBOSE,
        PQERRORS_SQLSTATE
    }

    int PQgetlength(const PGresult* res,
        int row_number,
        int column_number);
    int PQgetisnull(const PGresult* res,
        int row_number,
        int column_number);

    int PQfformat(const PGresult* res, int column_number);

    alias Oid = int;
    enum BYTEAOID = 17;
    Oid PQftype(const PGresult* res, int column_number);

    char* PQescapeByteaConn(PGconn* conn,
        const ubyte* from,
        size_t from_length,
        size_t* to_length);
    char* PQunescapeBytea(const char* from, size_t* to_length);
    void PQfreemem(void* ptr);

    char* PQcmdTuples(PGresult* res);

}
