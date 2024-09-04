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

enum DataTypes : string
{
    // Basic Types
    SERIAL = "SERIAL",
    INTEGER = "INTEGER",
    BIGINT = "BIGINT",
    SMALLINT = "SMALLINT",
    FLOAT = "FLOAT",
    REAL = "REAL",
    DOUBLE_PRECISION = "DOUBLE PRECISION",
    NUMERIC = "NUMERIC",
    BOOLEAN = "BOOLEAN",
    CHAR = "CHAR",
    VARCHAR = "VARCHAR",
    TEXT = "TEXT",
    DATE = "DATE",
    TIME = "TIME",
    TIMESTAMP = "TIMESTAMP",
    BYTEA = "BYTEA",

    // 1D Array Types
    INTEGER_ARRAY = "INTEGER[]",
    BIGINT_ARRAY = "BIGINT[]",
    SMALLINT_ARRAY = "SMALLINT[]",
    FLOAT_ARRAY = "FLOAT[]",
    REAL_ARRAY = "REAL[]",
    DOUBLE_PRECISION_ARRAY = "DOUBLE PRECISION[]",
    NUMERIC_ARRAY = "NUMERIC[]",
    BOOLEAN_ARRAY = "BOOLEAN[]",
    CHAR_ARRAY = "CHAR[]",
    VARCHAR_ARRAY = "VARCHAR[]",
    TEXT_ARRAY = "TEXT[]",
    DATE_ARRAY = "DATE[]",
    TIME_ARRAY = "TIME[]",
    TIMESTAMP_ARRAY = "TIMESTAMP[]",
    BYTEA_ARRAY = "BYTEA[]",

    // 2D Array Types
    INTEGER_ARRAY_2D = "INTEGER[][]",
    BIGINT_ARRAY_2D = "BIGINT[][]",
    SMALLINT_ARRAY_2D = "SMALLINT[][]",
    FLOAT_ARRAY_2D = "FLOAT[][]",
    REAL_ARRAY_2D = "REAL[][]",
    DOUBLE_PRECISION_ARRAY_2D = "DOUBLE PRECISION[][]",
    NUMERIC_ARRAY_2D = "NUMERIC[][]",
    BOOLEAN_ARRAY_2D = "BOOLEAN[][]",
    CHAR_ARRAY_2D = "CHAR[][]",
    VARCHAR_ARRAY_2D = "VARCHAR[][]",
    TEXT_ARRAY_2D = "TEXT[][]",
    DATE_ARRAY_2D = "DATE[][]",
    TIME_ARRAY_2D = "TIME[][]",
    TIMESTAMP_ARRAY_2D = "TIMESTAMP[][]",
    BYTEA_ARRAY_2D = "BYTEA[][]"
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
