module postgres._internal.consts;
import std.typecons;
import std.json;

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

struct WhereClause
{
    string clause;
    this(string clause)
    {
        this.clause = clause;
    }

    static WhereClause equals(T)(string column, T value)
    {
        import std.conv;

        Variant a;
        bool isString = is(typeof(value) == string);

        if (isString)
        {
            a = i"'$(value)'".text;
        }
        else
        {
            a = value;
        }
        return WhereClause(i"$(column)=$(a)".text);
    }

    static WhereClause notEquals(T)(string column, T value)
    {
        import std.conv;

        Variant a;
        bool isString = is(typeof(value) == string);
        if (isString)
        {
            a = i"'$(value)'".text;
        }
        else
        {
            a = value;
        }
        return WhereClause(i"$(column)!=$(a)".text);
    }

    static WhereClause greaterThan(T)(string column, T value)
    {
        import std.conv;

        Variant a;
        bool isString = is(typeof(value) == string);
        if (isString)
        {
            a = i"'$(value)'".text;
        }
        else
        {
            a = value;
        }
        return WhereClause(i"$(column) > $(a)".text);
    }

    static WhereClause lessThan(T)(string column, T value)
    {
        import std.conv;

        Variant a;
        bool isString = is(typeof(value) == string);
        if (isString)
        {
            a = i"'$(value)'".text;
        }
        else
        {
            a = value;
        }
        return WhereClause(i"$(column) < $(a)".text);
    }

    static WhereClause greaterThanOrEqual(T)(string column, T value)
    {
        import std.conv;

        Variant a;
        bool isString = is(typeof(value) == string);
        if (isString)
        {
            a = i"'$(value)'".text;
        }
        else
        {
            a = value;
        }
        return WhereClause(i"$(column) >= $(a)".text);
    }

    static WhereClause lessThanOrEqual(T)(string column, T value)
    {
        import std.conv;

        Variant a;
        bool isString = is(typeof(value) == string);
        if (isString)
        {
            a = i"'$(value)'".text;
        }
        else
        {
            a = value;
        }
        return WhereClause(i"$(column) <= $(a)".text);
    }

    static WhereClause like(string column, string pattern)
    {
        import std.conv;

        return WhereClause(i"$(column) LIKE '$(pattern)'".text);
    }

    static WhereClause notLike(string column, string pattern)
    {
        import std.conv;

        return WhereClause(i"$(column) NOT LIKE '$(pattern)'".text);
    }

    static WhereClause isNull(string column)
    {
        import std.conv;

        return WhereClause(i"$(column) IS NULL".text);
    }

    static WhereClause isNotNull(string column)
    {
        import std.conv;

        return WhereClause(i"$(column) IS NOT NULL".text);
    }

    static WhereClause inValues(T)(string column, T[] values)
    {
        import std.conv;
        import std.array;

        bool isString = is(typeof(values[0]) == string);
        auto formattedValues = values.map!(v => isString ? i"'$(v)'".text : v.to!string).join(",");
        return WhereClause(i"$(column) IN ($(formattedValues))".text);
    }

    static WhereClause notInValues(T)(string column, T[] values)
    {
        import std.conv;
        import std.array;

        bool isString = is(typeof(values[0]) == string);
        auto formattedValues = values.map!(v => isString ? i"'$(v)'".text : v.to!string).join(",");
        return WhereClause(i"$(column) NOT IN ($(formattedValues))".text);
    }

    static WhereClause between(T)(string column, T lower, T upper)
    {
        import std.conv;

        Variant a, b;
        bool isString = is(typeof(lower) == string);
        if (isString)
        {
            a = i"'$(lower)'".text;
            b = i"'$(upper)'".text;
        }
        else
        {
            a = lower;
            b = upper;
        }
        return WhereClause(i"$(column) BETWEEN $(a) AND $(b)".text);
    }

    static WhereClause notBetween(T)(string column, T lower, T upper)
    {
        import std.conv;

        Variant a, b;
        bool isString = is(typeof(lower) == string);
        if (isString)
        {
            a = i"'$(lower)'".text;
            b = i"'$(upper)'".text;
        }
        else
        {
            a = lower;
            b = upper;
        }
        return WhereClause(i"$(column) NOT BETWEEN $(a) AND $(b)".text);
    }

    static WhereClause and(WhereClause left, WhereClause right)
    {
        import std.conv;

        return WhereClause(i"($(left.clause)) AND ($(right.clause))".text);
    }

    static WhereClause or(WhereClause left, WhereClause right)
    {
        import std.conv;

        return WhereClause(i"($(left.clause)) OR ($(right.clause))".text);
    }

    static WhereClause custom(string expression)
    {
        return WhereClause(expression);
    }

}

string generateWhereClause(WhereClause[] conditions)
{
    return conditions.map!(c => c.clause).join(" AND ");
}

struct ModelMetaData
{
    string tableName;
    string primaryKey;
    string[] relations;
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
