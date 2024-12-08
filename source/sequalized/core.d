module sequalized.core;

import std.stdio;
import sequalized.utils;
import std.traits;
import std.conv;
import sequalized.error_handlers;
import core.stdcpp.type_traits;
import core.cpuid;
import std.meta : Repeat;
import std.typecons : Tuple;
import std.string;

interface Schema
{

}

mixin template Model()
{
    import sequalized.pg.connection : Postgres, QueryResult;
    import sequalized.error_handlers : PGSqlException, DuplicateKeyException;
    import std.variant;
    import core.time;

    this(Postgres m)
    {
        this.manager = m;
        // this.logging = logging;
        this.generateMeta();
    }

    void sync()
    {
        import std.conv;

        try
        {
            import std.conv;
            import std.traits;

            string query = syncQueryGenerator();

            writeln("Executing query: " ~ query);

            auto r = this.manager.query(query);

            // Need to fix the logging implementation based on NOTICES, WARNINGS
            string log = "Table " ~ this.meta.tableName ~ " created successfully";
            writeln(log);
        }
        catch (Exception e)
        {
            writeln(e.msg);
        }
    }

    int insert()
    {

        try
        {

            import std.conv;
            import std.meta;
            import std.typecons;

            auto query = insertQueryGenerator();
            writeln("Executing query:" ~ query[0]);
            string sql = query[0];

            string name = "insert_" ~ this.meta.tableName ~ "_statement";
            writeln(query[1]);
            QueryResult re = this.manager.executePreparedStatement(name, sql, query[1]);

            int result = re.rows[0]["id"].to!int;

            return result;
        }
        catch (PGSqlException e)
        {
            import std.string : strip;

            if (e.code.strip() == "23505")
            {
                throw new DuplicateKeyException(e.message);
            }
            else
            {
                throw e;
            }
            return 0;
        }
    }

    auto update(WhereClause...)(WhereClause where)
    {
        return updateWith(Seperater.AND, where);
    }

    auto updateWith(WhereClause...)(Seperater sep, WhereClause where)
    {
        import std.conv;
        import std.meta;
        import std.typecons;

        if (where.length > 0)
        {
            foreach (idx, _; where)
            {
                assert(to!string(where[idx]) == "sequalized.utils.WhereClause", "Invalid where clause");
            }
        }
        auto query = updateQueryGenerator(sep, where[0 .. $]);
        string sql = query[0];

        string prepareStmtName = "update_" ~ (this.meta.tableName) ~ "_stmt";
        Variant[] values = query[1];
        foreach (key; query[2 .. $])
        {
            values ~= Variant(key);
        }
        auto re = this.manager.executePreparedStatement(prepareStmtName, sql, values);

        if (re.rows.length > 0)
        {
            return re.rows[0]["updated"] == "t";
        }
        else
        {
            return false;
        }

    }

    /// 
    /// Params:
    ///   where = WhereClause
    ///  Function to destroy the model from the table.
    /// 
    auto destroy(WhereClause...)(WhereClause where)
    {
        return destroyWith(Seperater.AND, where);
    }

    void destroyWith(WhereClause...)(Seperater s, WhereClause where)
    {
        import std.conv;
        import std.meta;
        import std.typecons;

        if (where.length > 0)
        {
            foreach (idx, _; where)
            {
                assert(to!string(where[idx]) == "sequalized.utils.WhereClause", "Invalid where clause");
            }
        }
        auto query = destroyQueryGenerator(s, where[0 .. $]);
        string sql = query[0];

        string prepareStmtName = "delete_" ~ (this.meta.tableName) ~ "_stmt";
        Variant[] values;
        foreach (key; query[1 .. $])
        {
            values ~= Variant(key);
        }

        this.manager.executePreparedStatement(prepareStmtName, sql, values);

    }

    auto select(WhereClause...)(SelectOptions s = SelectOptions(), WhereClause where)
    {
        import std.conv;
        import std.json;
        import std.typecons;
        import std.meta : Repeat;

        auto query = generateSelectQuery(s, where);
        string sql = query[0];
        writeln("Executing query: " ~ sql);
        string name = "select_" ~ (this.meta.tableName) ~ "_statement";
        Variant[] values = [];
        foreach (key; query[1 .. $])
        {
            values ~= key.to!Variant;
        }
        QueryResult re = this.manager.executePreparedStatement(name, sql, values);

        // return 0;
        return re.rows;

    }

private:
    Postgres manager;
    ModelMetaData meta = ModelMetaData();
    string[] reservedMembers = ["manager", "meta", "reservedMembers"];

    auto insertQueryGenerator()
    {

        import std.conv;
        import std.algorithm : canFind;
        import std.json;

        string q = `INSERT INTO "` ~ (this.meta.tableName) ~ `" (`;
        string column = "";
        // auto colObject = this.meta.columns.object;
        string values = "";
        import std.typecons;

        auto autoIncrementals = this.meta.autoIncrementals;
        int argIndex = 1;
        int[] availableIndices = [];
        foreach (index, member; this.tupleof)
        {
            string col = __traits(identifier, this.tupleof[index]);
            if (!canFind!(a => a == col)(reservedMembers)
                && !canFind!(a => a == col)(autoIncrementals))
            {
                import std.conv;

                if (is(typeof(member) == string)
                    && ((this.tupleof[index].to!string) == ""))
                {
                    continue;
                }

                if ((is(typeof(member) == long)
                        || is(typeof(member) == int)
                        || is(typeof(member) == short)
                        || is(typeof(member) == byte)
                        || is(typeof(member) == ubyte)
                        || is(typeof(member) == ushort)
                        || is(typeof(member) == uint)
                        || is(typeof(member) == ulong)
                        || is(typeof(member) == float)
                        || is(typeof(member) == double)
                        || is(typeof(member) == real)
                        || is(typeof(member) == bool)
                    ) && ("" ~ (this.tupleof[index].to!string) ~ "" == "0"))
                {
                    continue;
                }
                import sequalized.helpers : toSnakeCase;

                column ~= "" ~ (toSnakeCase(col)) ~ ", ";
                values ~= " $" ~ (argIndex.to!string) ~ ",";
                argIndex++;
                availableIndices ~= index;
            }
        }
        if (column.length == 0)
        {
            import sequalized.error_handlers : QueryGeneratorException;

            throw new QueryGeneratorException("No columns to insert");
        }
        else
        {
            q = q ~ column[0 .. $ - 2] ~ ") VALUES (" ~ values[0 .. $ - 1] ~ ") RETURNING " ~ this.meta.primaryKey ~ ";"; // @suppress(dscanner.style.long_line)
            // q = q ~ "$(column[0 .. $ - 2])) VALUES ( $(values[0 .. $ - 1]) ) RETURNING $(this.meta.primaryKey);"
            // .text;
        }

        auto t = this.tupleof;
        Tuple!(typeof(t)) tup = tuple(t);
        import std.variant;
        import std.traits : isDynamicArray;

        auto setValue = tup.slice!(3, tup.length);
        Variant[] valuesTuple = [];
        foreach (val; setValue)
        {
            string v = val.to!string;
            if (v != "0" && v != "" && v != null)
            {
                if (isDynamicArray!(typeof(val)) && !is(typeof(val) == string) && !is(
                        typeof(val) == enum))
                {
                    import std.regex;
                    string pgArrVal = "{" ~val.to!string ~ "}";
                    auto pattern = regex(`[\[\]"]`);
                    valuesTuple ~= replaceAll(pgArrVal, pattern, "").to!Variant;
                }else{

                valuesTuple ~= val.to!Variant;
                }
            }
        }

        return tuple(q) ~ valuesTuple;
    }

    auto updateQueryGenerator(WhereClause...)(
        Seperater sep, WhereClause where)
    {

        import std.algorithm : canFind;
        import std.conv;
        import std.json;
        import std.typecons;
        import std.array;

        string tableName = this.meta.tableName;
        string primaryKey = this.meta.primaryKey;
        string q = `UPDATE "` ~ (tableName) ~ `" SET `;

        string setClause = "";
        string fromClause = "";

        auto autoIncrementals = this.meta.autoIncrementals;
        int pos = 1;

        // Handling values
        auto t = this.tupleof;
        Tuple!(typeof(t)) tup = tuple(t);
        auto setValue = tup.slice!(3, tup.length); // Adjust slicing based on actual structure

        foreach (index, member; this.tupleof)
        {
            string col = __traits(identifier, this.tupleof[index]);

            if (!canFind!(a => a == col)(reservedMembers)
                && !canFind!(a => a == col)(autoIncrementals))
            {
                if (is(typeof(member) == string)
                    && ("" ~ (this.tupleof[index].to!string) ~ "" == ""))
                {
                    continue;
                }

                if ((is(typeof(member) == long)
                        || is(typeof(member) == int)
                        || is(typeof(member) == short)
                        || is(typeof(member) == byte)
                        || is(typeof(member) == ubyte)
                        || is(typeof(member) == ushort)
                        || is(typeof(member) == uint)
                        || is(typeof(member) == ulong)
                        || is(typeof(member) == float)
                        || is(typeof(member) == double)
                        || is(typeof(member) == real)
                        || is(typeof(member) == bool)
                    ) && ("" ~ (this.tupleof[index].to!string) ~ "" == "0"))
                {
                    continue;
                }
                import sequalized.helpers : toSnakeCase;

                setClause ~= " " ~ (toSnakeCase(col)) ~ " = $" ~ (pos.to!string) ~ ",";
                pos++;
            }
        }

        if (setClause.length == 0)
        {
            import sequalized.error_handlers : QueryGeneratorException;

            throw new QueryGeneratorException("No columns to update");
        }
        else
        {
            q ~= setClause[0 .. $ - 1]; // Remove trailing comma
        }
        Variant[] valuesTuple = [];
        foreach (key; setValue)
        {
            if (key.to!string != "0" && key.to!string != "" && key.to!string != null)
            {
                valuesTuple ~= key.to!Variant;
            }

        }
        // Optional FROM clause
        if (fromClause.length > 0)
        {
            q ~= " FROM " ~ (fromClause);
        }

        // Optional WHERE clause
        if (where.length > 0)
        {

            auto whereClause = generateWhereClause(this.meta.tableName, sep, pos, where[0 .. $]);

            string whereQuery = whereClause[0];
            q ~= " WHERE " ~ (whereQuery);
            q ~= " RETURNING CASE WHEN xmax IS NOT NULL THEN true ELSE false END AS updated;";

            return tuple(q) ~ valuesTuple ~ tuple(whereClause[1 .. $]);
        }

        q ~= " RETURNING CASE WHEN xmax IS NOT NULL THEN true ELSE false END AS updated;";

        // Is this a good way to lie to compiler?
        import std.meta : Repeat;

        Tuple!(Repeat!(where.length, string)) a;

        return tuple(q) ~ valuesTuple ~ a;
    }

    auto destroyQueryGenerator(WhereClause...)(Seperater s, WhereClause where)
    {
        import std.conv;
        import std.json;
        import std.typecons;
        import std.meta : Repeat;

        string tableName = this.meta.tableName;
        string primaryKey = this.meta.primaryKey;
        string q = `DELETE FROM "` ~ (tableName) ~ `"`;

        if (where.length > 0)
        {
            auto whereClause = generateWhereClause(this.meta.tableName, s, 1, where[0 .. $]);
            string whereQuery = whereClause[0];
            q ~= " WHERE " ~ (whereQuery);
            return tuple(q) ~ tuple(whereClause[1 .. $]);
        }
        Tuple!(Repeat!(where.length, string)) a;
        return tuple(q) ~ a;
    }

    string syncQueryGenerator()
    {
        import std.conv;

        string q = `CREATE TABLE IF NOT EXISTS "` ~ (this.meta.tableName) ~ `" (`;
        string column = "";
        auto colObject = this.meta.columns.object;
        import std.algorithm;

        foreach (key, value; colObject)
        {

            string col = (key) ~ " " ~ (value["type"].str) ~ (value["properties"].str);
            if ("references" in value.object)
            {
                col ~= `, ` ~ (value.object["references"].str);
            }
            column ~= col ~ ", ";
        }
        q = q ~ column[0 .. $ - 2] ~ ");";
        return q;
    }

    auto generateSelectQuery(WhereClause...)(SelectOptions s, WhereClause where)
    {
        import std.conv;
        import std.json;
        import std.typecons;
        import std.meta : Repeat;
        import std.array;

        string tableName = this.meta.tableName;

        string col = tableName ~ `.*`;

        // Basic include columns option handling
        if (s.cols.length > 0)
        {
            import std.algorithm : map;

            col = s.cols.map!(a => (tableName) ~ `.` ~ (a)).join(",");
        }

        string[] cols = [];
        string[] joins = [];
        // If another table is joined/included
        foreach (include; s.includes)
        {

            string includeTable = include.table;
            string includeCols = include.options.cols.length > 0 ? include.options.cols.join(
                ",") : "*";
            if (include.options.cols.length > 0)
            {
                import std.algorithm : map;
                import std.array;

                auto icols = include.options.cols.map!(
                    a => (
                        includeTable) ~ `.` ~ (a) ~ ` AS ` ~ `"` ~ (includeTable) ~ `.` ~ (a) ~ `"`);
                cols ~= icols.join(",");
            }
            else
            {
                cols ~= (includeTable) ~ `.*`;
            }

            // auto relationKey = meta.relations[i"$(tableName).$(includeTable)".text].str;
            import std.algorithm : canFind;
            import std.array;

            string relationKey = "";
            foreach (key; meta.relations.array)
            {
                if (canFind(key.object.keys, (tableName) ~ "." ~ (includeTable)))
                {
                    relationKey = key.object[(tableName) ~ "." ~ (includeTable)].str;
                }
            }
            string[] referenceColumns = relationKey.split(".");
            joins ~= ` LEFT JOIN "` ~ (includeTable) ~ `" ON "` ~ (tableName) ~ `".` ~ (
                referenceColumns[0]) ~ ` = "` ~ (includeTable) ~ `".` ~ (referenceColumns[1]);

        }
        import std.array;

        string incCols = cols.join(",");
        if (incCols.length > 0)
        {
            col ~= "," ~ incCols;
        }
        string q = `SELECT ` ~ (col) ~ ` FROM "` ~ (tableName) ~ `"`;
        q ~= joins.join(" ");
        if (where.length > 0)
        {
            auto whereClause = generateWhereClause(this.meta.tableName, s.separator, 1, where[0 .. $]);
            string whereQuery = whereClause[0];
            q ~= " WHERE " ~ (whereQuery);
            return tuple(q) ~ tuple(whereClause[1 .. $]);
        }

        Tuple!(Repeat!(where.length, string)) a;
        return tuple(q) ~ a;
    }

    void generateMeta()
    {
        string tableName = __traits(identifier, typeof(this));

        import std.string : toLower;

        // tableName =cast(string) tableName.asLowerCase();
        tableName = toLower(tableName);
        string column = "";
        this.meta.tableName = tableName;
        // this.meta.columns = [];
        static foreach (field; typeof(this).tupleof)
        {
            import sequalized.helpers : toSnakeCase;

            if (!is(typeof(field) == Postgres)
                && !is(typeof(field) == ModelMetaData))
            {

                string tbc = __traits(identifier, field);
                tbc = toSnakeCase(tbc);
                // column = column ~ toSnakeCase(tbc) ~ " ";
                foreach (attr; __traits(getAttributes, field))
                {
                    static if (is(typeof(attr) == Type))
                    {
                        if (attr.type == DataTypes.SERIAL)
                        {
                            this.meta.autoIncrementals ~= tbc;
                        }
                        import std.conv;
                        import std.json;

                        string objectRef = `{"type":"` ~ (
                            cast(string) attr.type) ~ `","properties":""}`;
                        this.meta.columns[tbc] = parseJSON(objectRef);
                    }

                    static if (is(typeof(attr) == NotNull))
                    {
                        import std.conv;
                        import std.json;

                        string propString = this.meta.columns[tbc]["properties"].str;
                        propString ~= " NOT NULL";
                        this.meta.columns[tbc]["properties"] = propString;
                    }

                    static if (is(typeof(attr) == PmKey))
                    {
                        import std.conv;
                        import std.json;

                        string propString = this.meta.columns[tbc]["properties"].str;
                        propString ~= " PRIMARY KEY";
                        this.meta.columns[tbc]["properties"] = propString;
                        this.meta.primaryKey = tbc;
                    }
                    static if (is(typeof(attr) == DefaultValue))
                    {
                        string[] textTypes = [
                            DataTypes.VARCHAR, DataTypes.TEXT
                        ];
                        import std.conv;
                        import std.algorithm;

                        bool isText = canFind!(a => a == this.meta.columns[tbc]["type"].str)(
                            textTypes);

                        if (isText)
                        {
                            string propString = this.meta.columns[tbc]["properties"].str;
                            propString ~= " DEFAULT '" ~ (attr.defaultValue) ~ "'".text;
                            this.meta.columns[tbc]["properties"] = propString;
                        }
                        else
                        {
                            string propString = this.meta.columns[tbc]["properties"].str;
                            propString ~= " DEFAULT " ~ (attr.defaultValue);
                            this.meta.columns[tbc]["properties"] = propString;
                        }
                    }

                    static if (is(typeof(attr) == Unique))
                    {
                        import std.conv;
                        import std.json;

                        string propString = this.meta.columns[tbc]["properties"].str;
                        propString ~= " UNIQUE";
                        this.meta.columns[tbc]["properties"] = propString;
                    }
                    static if (is(typeof(attr) == ForeignKey))
                    {

                        import std.conv;
                        import std.json;

                        JSONValue j;
                        j[(tableName) ~ "." ~ (attr.table)] = (tbc) ~ "." ~ (attr.referenceKey);

                        this.meta.relations.array ~= j;

                        this.meta.columns[tbc].object["references"] = `FOREIGN KEY (` ~ (
                            tbc) ~ `) REFERENCES "` ~ (attr.table) ~ `"(` ~ (attr.referenceKey) ~ `)`;

                    }

                }
                column = column ~ ",";
            }
        }
        // add pmKey if not provided
        if (this.meta.primaryKey == "")
        {
            import std.json;

            this.meta.primaryKey = "id";
            this.meta.columns["id"] = parseJSON(
                `{"type":"SERIAL","properties":" PRIMARY KEY"}`);
        }
    }

}
