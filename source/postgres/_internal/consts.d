module postgres._internal.consts;
import std.typecons;
import std.json;
public import std.stdio;

string[] reserveredWords = [
    "insert", "update", "delete", "findOne", "where", "findAll",
];

struct Type
{
    DataTypes type;
}

struct NotNull
{
    bool isNullable = false;
}

struct PmKey
{
    bool isPrimary = true;
}

struct DefaultValue
{
    string defaultValue;
}

struct ForeignKey
{
    string table;
    string referenceKey;
}

struct Unique
{
    bool isUnique;
}

enum DataTypes
{
    SMALLINT = "SMALLINT", // 2 bytes, range -32768 to +32767
    INTEGER = "INTEGER", // 4 bytes, range -2147483648 to +2147483647
    BIGINT = "BIGINT", // 8 bytes, range -9223372036854775808 to +9223372036854775807
    DECIMAL = "DECIMAL", // user-specified precision, exact
    NUMERIC = "NUMERIC", // user-specified precision, exact
    REAL = "REAL", // 4 bytes, variable-precision, inexact
    DOUBLE_PRECISION = "DOUBLE PRECISION", // 8 bytes, variable-precision, inexact
    SMALLSERIAL = "SMALLSERIAL", // 2 bytes, auto-incrementing
    SERIAL = "SERIAL", // 4 bytes, auto-incrementing
    BIGSERIAL = "BIGSERIAL", // 8 bytes, auto-incrementing

    MONEY = "MONEY", // currency amounts

    CHAR = "CHAR", // fixed-length, blank padded
    VARCHAR = "VARCHAR", // variable-length with limit
    TEXT = "TEXT", // variable unlimited length

    BYTEA = "BYTEA", // binary data ("byte array")

    TIMESTAMP = "TIMESTAMP", // both date and time (no time zone)
    TIMESTAMPTZ = "TIMESTAMPTZ", // both date and time, with time zone
    DATE = "DATE", // date (no time of day)
    TIME = "TIME", // time of day (no date)
    TIMETZ = "TIMETZ", // time of day, with time zone
    INTERVAL = "INTERVAL", // time span

    BOOLEAN = "BOOLEAN", // true/false

    POINT = "POINT", // geometric point '(x, y)'
    LINE = "LINE", // infinite line
    LSEG = "LSEG", // line segment
    BOX = "BOX", // rectangular box
    PATH = "PATH", // geometric path
    POLYGON = "POLYGON", // closed geometric path
    CIRCLE = "CIRCLE", // geometric circle

    CIDR = "CIDR", // IPv4 or IPv6 network
    INET = "INET", // IPv4 or IPv6 host address
    MACADDR = "MACADDR", // MAC address
    MACADDR8 = "MACADDR8", // MAC address (EUI-64 format)

    BIT = "BIT", // fixed-length bit string
    VARBIT = "VARBIT", // variable-length bit string

    UUID = "UUID", // universally unique identifier

    XML = "XML", // XML data

    JSON = "JSON", // JSON data
    JSONB = "JSONB", // binary JSON data

    HSTORE = "HSTORE", // key-value store

    ARRAY = "ARRAY", // array of any data type
    ENUM = "ENUM", // enumerated type

    TSQUERY = "TSQUERY", // text search query
    TSVECTOR = "TSVECTOR", // text search document
    TXID_SNAPSHOT = "TXID_SNAPSHOT", // user-level transaction ID snapshot

}

enum DefaultDateType
{
    date = "CURRENT_DATE",
    time = "CURRENT_TIME",
    timestamp = "CURRENT_TIMESTAMP"
}

import std.array : join;
import std.algorithm : map;
import std.variant;
import postgres._internal.helpers;
import phobos.sys.meta;

class WhereClause
{
    string symbol;
    string col;
    string val;
    this(string symbol, string col, string val)
    {
        this.symbol = symbol;
        this.col = col;
        this.val = val;
    }

    this()
    {

    }

    static WhereClause eq(T)(string column, T value)
    {
        import std.conv;

        return new WhereClause("=", column, to!string(value));
    }

    static WhereClause notEq(T)(string column, T value)
    {
        import std.conv;

        return new WhereClause("!=", column, to!string(value));
    }

    static WhereClause gt(T)(string column, T value)
    {
        import std.conv;

        return new WhereClause(">", column, to!string(value));
    }

    static WhereClause lt(T)(string column, T value)
    {
        import std.conv;

        return new WhereClause("<", column, to!string(value));
    }

    static WhereClause gtOrEq(T)(string column, T value)
    {
        import std.conv;

        string a;
        if (typeof(value) == string)
        {
            a = "'" ~ to!string(value) ~ "'";
        }
        else
        {
            a = to!string(value);
        }
        return new WhereClause(">=", column,);
    }

    static WhereClause ltOrEq(T)(string column, T value)
    {
        import std.conv;

        string a;
        if (typeof(value) == string)
        {
            a = "'" ~ to!string(value) ~ "'";
        }
        else
        {
            a = to!string(value);
        }

        return new WhereClause("<=", column, to!string(value));
    }

    static WhereClause like(string column, string pattern)
    {
        return new WhereClause("LIKE", column, "'" ~ pattern ~ "'");
    }

    static WhereClause notLike(string column, string pattern)
    {
        return new WhereClause("NOT LIKE", column, "'" ~ pattern ~ "'");
    }

    static WhereClause isNull(string column)
    {
        return new WhereClause("IS NULL", column, "");
    }

    static WhereClause isNotNull(string column)
    {
        return new WhereClause("IS NOT NULL", column, "");
    }

    static WhereClause inValues(T)(string column, T[] values)
    {
        import std.conv;
        import std.array;

        auto formattedValues = values.map!(v => () {
            string a;
            if (is(typeof(v) == string))
            {
                return a = "'" ~ to!string(v) ~ "'";
            }
            else
            {
                return to!string(v);
            }
        }).join(",");
        return new WhereClause("IN", column, "(" ~ formattedValues ~ ")");
    }

    static WhereClause notInValues(T)(string column, T[] values)
    {
        import std.conv;
        import std.array;

        auto formattedValues = values.map!(v => () {
            string a;
            if (is(typeof(v) == string))
            {
                return a = "'" ~ to!string(v) ~ "'";
            }
            else
            {
                return to!string(v);
            }
        }).join(",");
        return new WhereClause("NOT IN", column, "(" ~ formattedValues ~ ")");
    }

    static WhereClause between(T)(string column, T lower, T upper)
    {
        import std.conv;

        string a;
        string b;
        if (is(typeof(lower)) == string)
        {
            a = "'" ~ to!string(lower) ~ "'";
        }
        else
        {
            a = to!string(lower);
        }
        if (is(typeof(lower)) == string)
        {
            b = "'" ~ to!string(upper) ~ "'";
        }
        else
        {
            b = to!string(upper);
        }
        return new WhereClause("BETWEEN", column, lower ~ " AND " ~ upper);
    }

    static WhereClause notBetween(T)(string column, T lower, T upper)
    {
        import std.conv;

        string a;
        string b;
        if (is(typeof(lower)) == string)
        {
            a = "'" ~ to!string(lower) ~ "'";
        }
        else
        {
            a = to!string(lower);
        }
        if (is(typeof(lower)) == string)
        {
            b = "'" ~ to!string(upper) ~ "'";
        }
        else
        {
            b = to!string(upper);
        }

        return new WhereClause("NOT BETWEEN", column, lower ~ " AND " ~ upper);
    }

}

enum Seperater
{
    AND = "AND",
    OR = "OR"
}

auto generateWhereClause(WhereClause...)(string tableName, Seperater separator = Seperater.AND,
    int count = 0, WhereClause args)
{
    import std.conv;
    import std.meta : Repeat;

    string[] c;
    Tuple!(Repeat!(args.length, string)) a;

    foreach (i, condition; args)
    {
        c ~= `"`~tableName~`"`~"."~condition.col ~ " " ~ condition.symbol ~ " " ~ "$" ~ to!string(count) ~ " ";
        a[i] = condition.val;
        auto tup = condition.tupleof;

        // valuesTuple[i] = tup;
        count++;
    }

    string q = c.join("" ~ separator ~ " ");
    return tuple(q) ~ a;
}

struct ModelMetaData
{
    string tableName;
    string primaryKey;
    JSONValue relations = parseJSON("[]");
    JSONValue columns;
    string[string] colValues;
    // string[string] meta = null;
    string[] autoIncrementals = [];
}

struct InsertionOptions
{
}

struct UpdateOptions
{

}

struct SelectOptions
{
    string[] cols;
    Includes[] includes;
    Seperater seperator = Seperater.AND;
    int limit;
    int offset;
    string orderBy;
    string order;
    string groupBy;
    string having;
    // SelectOptions exclude;
}

import postgres.model;

struct Includes
{
    // Schema table;
    string table;
    SelectOptions options;
}
// Tuple!() arrayToTuple(T)(T[] arr, size_t idx = 0) {
//     return tuple();
// }
