module postgres.implementation.core;

import std.string;

public:
import std.conv;
import std.stdio;

private import postgres.implementation.implementationc;

import postgres._internal.connection;
import postgres.implementation.exception : PGSqlException;
import std.variant;

class Postgres
{
    private PGconn* conn;
    private string connection;
    this(DatabaseConnectionOption dco)
    {
        connection = i"host=$(dco.host) 
                              port=$(dco.port) 
                              dbname=$(dco.database) 
                              user=$(dco.application_name)
                              password=$(dco.password) 
                              client_encoding=$(dco.client_encoding) 
                              application_name=$(dco.application_name)
                              sslmode=$(dco.ssl ? `require` : `disable`)".text;
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

    QueryResult executePreparedStatement(T...)(string name, string sql, T args)
    {
        const(char)*[args.length] argsStrings;

        foreach (idx, arg; args)
        {

            if (!is(typeof(arg) == typeof(null))) // auto str = to!string(arg);
            {
                argsStrings[idx] = toStringz(to!string(arg));
            }
            // else make it null
        }

        //  paramTypes set to null; for postgres to infer types; Need fix if project become advanceds
        PGresult* pres = PQprepare(conn, toStringz(name), toStringz(sql), argsStrings.length, null);
        int press = PQresultStatus(pres);
        if (press != PGRES_TUPLES_OK
            && press != PGRES_COMMAND_OK)
        {
            throw new PGSqlException(conn, pres);
        }
        else
        {
            PGresult* res = PQexecPrepared(conn, toStringz(name), argsStrings.length, argsStrings.ptr, null, null, 0);
            int ress = PQresultStatus(res);
            if (ress != PGRES_TUPLES_OK
                && ress != PGRES_COMMAND_OK)
                throw new PGSqlException(conn, res);

            query(i"DEALLOCATE $(name)".text);
            return new QueryResult(res);
        }

    }

}

class QueryResult
{

    private int rowSize;
    private int colSize;
    string[string][size_t] rows;
    private PGresult* res;
    private int position;

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

                if (PQgetisnull(res, position, i))
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
                                char* c = PQunescapeBytea(PQgetvalue(res, position, i), &len);
                                a = cast(string) c[0 .. len].idup;

                                PQfreemem(c);
                                break;
                            default:
                                a = to!string(PQgetvalue(res, position, i));
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
            rows[j] = r;
        }

    }
}

// struct Row {

// }
