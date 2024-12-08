module sequalized.pg.connection;

import std.string;

import std.conv;
import std.stdio;
import sequalized.pg.implementationc;
import std.variant;
import sequalized.error_handlers;

struct DatabaseConnectionOption
{

    // STRING_CONNECTION_OPTION_MAP 
    string application_name;

    string client_encoding;
    string database;
    string host;
    string password;
    string user;
    // BOOLEAN_CONNECTION_OPTION_MAP
    bool binary = false;
    bool keepAlive = false;
    bool ssl = false;

    // NUMBER_CONNECTION_OPTION_MAP
    long port;
    long statement_timeout;
    long query_timeout;
    long keepAliveInitialDelayMillis;
    long idle_in_transaction_session_timeout;
    long connectionTimeoutMillis;
    long lock_timeout;
}

class Postgres
{
    private PGconn* conn;

    private string connection;
    this(DatabaseConnectionOption dco)
    {
        connection = "host=" ~ (dco.host) ~
            " port=" ~ (
                dco.port.to!string) ~
            " dbname=" ~ (
                dco.database) ~
            " user=" ~ (dco.user) ~
            " password=" ~ (
                dco.password) ~
            " client_encoding=" ~ (dco.client_encoding ? dco.client_encoding
                    : `utf8`) ~
            " application_name=" ~ (
                dco.application_name) ~
            " sslmode=" ~ (dco.ssl ? `require` : `disable`);
        connect(connection);
    }

    ~this()
    {
        PQfinish(this.conn);
    }

    private void connect(string connectionString)
    {
        this.conn = PQconnectdb(toStringz(connectionString));

        if (PQstatus(this.conn) != CONNECTION_OK)
        {
            throw new PGSqlException(this.conn);
        }
        else
        {
            query("SET NAMES 'utf8'");
            import std.stdio : writeln;

            writeln("Connected to database");
        }
    }

    QueryResult query(string sql)
    {
        bool first_retry = true;
    retry:
        PGresult* res = PQexec(this.conn, toStringz(sql));

        int status = PQresultStatus(res);
        if (status == PGRES_COMMAND_OK || status == PGRES_TUPLES_OK)
        {
            import std.stdio;

            QueryResult result = new QueryResult(res);
            return result;
        }
        else
        {
            if (first_retry && to!string(PQerrorMessage(conn)) == "no connection to server\n")
            {
                first_retry = false;
                // try to reconnect...
                PQfinish(conn);
                connect(connection);
                goto retry;
            }
            throw new PGSqlException(this.conn, res);
        }

    }

    QueryResult executePreparedStatement(string name, string sql, Variant[] args)
    {
        const(char)*[] argsStrings;

        for (int i = 0; i < args.length; i++)
        {
            Variant arg = args[i];
            if (!is(typeof(arg) == typeof(null))) // auto str = to!string(arg);
            {
                argsStrings ~= toStringz(to!string(arg));
            }

        }

        //  paramTypes set to null; for postgres to infer types; Need fix if project become advanced
        PGresult* pres = PQprepare(conn, toStringz(name), toStringz(sql), argsStrings.length, null);
        int press = PQresultStatus(pres);
        if (press != PGRES_TUPLES_OK
            && press != PGRES_COMMAND_OK)
        {
            throw new PGSqlException(conn, pres);
        }
        else
        {
            PGresult* res = PQexecPrepared(conn, toStringz(name),
                argsStrings.length.to!int, argsStrings.ptr, null, null, 0);
            int res_s = PQresultStatus(res);
            query("DEALLOCATE " ~ (name));
            if (res_s != PGRES_TUPLES_OK
                && res_s != PGRES_COMMAND_OK)
                throw new PGSqlException(conn, res);

            return new QueryResult(res);
        }

    }

}

class QueryResult
{

    private int rowSize;
    private int colSize;
    string[string][] rows;
    private PGresult* res;

    this(PGresult* r)
    {
        this.res = r;
        rowSize = PQntuples(r);
        colSize = PQnfields(r);
        generateRows();
    }

    ~this()
    {
        PQclear(res);
    }

    private void generateRows()
    {
        import std.typecons : Tuple;

        for (int j = 0; j < rowSize; j++)
        {
            string[string] r;
            for (int i = 0; i < colSize; i++)
            {
                string a;

                if (PQgetisnull(res, j, i))
                    a = null;
                else
                {

                    switch (PQfformat(res, i))
                    {
                    case 0: // text representation
                    {
                            switch (PQftype(res, i))
                            {
                            case BYTEAOID:
                                size_t len;
                                char* c = PQunescapeBytea(PQgetvalue(res, j, i), &len);
                                a = cast(string) c[0 .. len].idup;

                                PQfreemem(c);
                                break;
                            default:
                                a = to!string(PQgetvalue(res, j, i));
                            }
                            break;
                        }
                    case 1: // binary representation
                        throw new Exception("unexpected format returned by pq");
                    default:
                        throw new Exception("unknown pq format");
                    }
                }
                // import std.stdio;
                r[to!string(PQfname(res, i))] = a;

            }
            rows ~= r;
        }

    }
}
