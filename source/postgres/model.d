module postgres.model;

import std.stdio;
import postgres._internal.consts;
import std.traits;
import std.conv;
import postgres._internal.exceptions;
import core.stdcpp.type_traits;
import core.cpuid;
import std.variant;
import postgres.implementation.core : Postgres, QueryResult;
import postgres.implementation.exception;
import std.meta : Repeat;
import std.typecons : Tuple;
import std.string;

interface Schema
{

}

mixin template Model()
{

    this(Postgres m)
    {
        this.manager = m;
        // this.logging = loggin;
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

            writeln(i"Executing query: $(query)".text);

            auto r = this.manager.query(query);

            // Need to fix the logging implementation based on NOTICES, WARNINGS
            string log = i"Table `$(this.meta.tableName)` created successfully".text;
            writeln(log);
        }
        catch (Exception e)
        {
            writeln(e.msg);
        }
    }

    auto insert()
    {

        try
        {

            import std.conv;
            import std.meta;
            import std.typecons;

            auto query = insertQueryGenerator();
            writeln(i"Executing query: $(query[0])".text);
            string sql = query[0];

            string name = i"insert_$(this.meta.tableName)_statement".text;

            QueryResult re = this.manager.executePreparedStatement(name, sql, query[1]);

            int result = re.rows[0]["id"].to!int;

            return result;
        }
        catch (PGSqlException e)
        {
            import std.string : strip;

            if (e.code.strip() == "23505")
            {
                import postgres.implementation.exception : DuplicateKeyException;

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
                assert(to!string(where[idx]) == "postgres._internal.consts.WhereClause", "Invalid where clause");
            }
        }
        auto query = updateQueryGenerator(sep, where[0 .. $]);
        string sql = query[0];

        string prepareStmtName = i"update_$(this.meta.tableName)_stmt".text;
        Variant[] values = query[1];
        foreach (key; query[2 .. $])
        {
            values ~= key.to!Variant;
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
    ///  Function to destory the model fromthe table.
    /// 
    auto destroy(WhereClause...)(WhereClause where)
    {
        return destroyWith(Seperater.AND, where);
    }

    void destroyWith(WhereClause...)(Seperater s, WhereClause where)
    {
        if (where.length > 0)
        {
            foreach (idx, _; where)
            {
                assert(to!string(where[idx]) == "postgres._internal.consts.WhereClause", "Invalid where clause");
            }
        }
        auto query = distroyQueryGenerator(s, where[0 .. $]);
        string sql = query[0];

        string prepareStmtName = i"delete_$(this.meta.tableName)_stmt".text;
        Variant[] values = [];
        foreach (key; query[1 .. $])
        {
            values ~= key.to!Variant;
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
        writeln(i"Executing query: $(sql)".text);
        string name = i"select_$(this.meta.tableName)_statement".text;
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

        string q = i`INSERT INTO "$(this.meta.tableName)" (`.text;
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

                if (is(typeof(member) == string)
                    && (i"$(this.tupleof[index])".text == ""))
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
                    ) && (i"$(this.tupleof[index])".text == "0"))
                {
                    continue;
                }
                import postgres._internal.helpers : toSnakeCase;

                column ~= i"$(toSnakeCase(col)), ".text;
                values ~= i" $$(argIndex),".text;
                argIndex++;
                availableIndices ~= index;
            }
        }
        if (column.length == 0)
        {
            import postgres._internal.exceptions : QueryGeneratorException;

            throw new QueryGeneratorException("No columns to insert");
        }
        else
        {
            // q = q ~ column[0 .. $ - 2] ~ ") VALUES (" ~ values[0 .. $ - 1] ~ ") RETURNING ;";
            q = q ~ i"$(column[0 .. $ - 2])) VALUES ( $(values[0 .. $ - 1]) ) RETURNING $(this.meta.primaryKey);"
                .text;
        }

        auto t = this.tupleof;
        Tuple!(typeof(t)) tup = tuple(t);

        auto setValue = tup.slice!(3, tup.length);
        Variant[] valuesTuple = [];
        foreach (val; setValue)
        {
            string v = val.to!string;
            if (v != "0" && v != "" && v != null)
            {
                valuesTuple ~= val.to!Variant;
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
        string q = i`UPDATE "$(tableName)" SET `.text;

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
                    && (i"$(this.tupleof[index])".text == ""))
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
                    ) && (i"$(this.tupleof[index])".text == "0"))
                {
                    continue;
                }
                 import postgres._internal.helpers : toSnakeCase;

                setClause ~= i" $(toSnakeCase(col)) = $$(pos),".text;
                pos++;
            }
        }

        if (setClause.length == 0)
        {
            import postgres._internal.exceptions : QueryGeneratorException;

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
            q ~= i" FROM $(fromClause)".text;
        }

        // Optional WHERE clause
        if (where.length > 0)
        {

            auto whereClause = generateWhereClause(this.meta.tableName, sep, pos, where[0 .. $]);

            string whereQuery = whereClause[0];
            q ~= i" WHERE $(whereQuery)".text;
            q ~= " RETURNING CASE WHEN xmax IS NOT NULL THEN true ELSE false END AS updated;";

            return tuple(q) ~ valuesTuple ~ tuple(whereClause[1 .. $]);
        }

        q ~= " RETURNING CASE WHEN xmax IS NOT NULL THEN true ELSE false END AS updated;";

        // Is this a good way to lie to compiler?
        import std.meta : Repeat;

        Tuple!(Repeat!(where.length, string)) a;

        return tuple(q) ~ valuesTuple ~ a;
    }

    auto distroyQueryGenerator(WhereClause...)(Seperater s, WhereClause where)
    {
        import std.conv;
        import std.json;
        import std.typecons;
        import std.meta : Repeat;

        string tableName = this.meta.tableName;
        string primaryKey = this.meta.primaryKey;
        string q = i`DELETE FROM "$(tableName)"`.text;

        if (where.length > 0)
        {
            auto whereClause = generateWhereClause(this.meta.tableName, s, 1, where[0 .. $]);
            string whereQuery = whereClause[0];
            q ~= i" WHERE $(whereQuery)".text;
            return tuple(q) ~ tuple(whereClause[1 .. $]);
        }
        Tuple!(Repeat!(where.length, string)) a;
        return tuple(q) ~ a;
    }

    string syncQueryGenerator()
    {
        import std.conv;

        string q = i`CREATE TABLE IF NOT EXISTS "$(this.meta.tableName)" (`.text;
        string column = "";
        auto colObject = this.meta.columns.object;
        import std.algorithm;

        foreach (key, value; colObject)
        {

            string col = i`$(key) $(value["type"].str)$(value["properties"].str)`.text;
            if ("references" in value.object)
            {
                col ~= i`, $(value.object["references"].str)`.text;
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

        string col = i`$(tableName).*`.text;

        // Basic include columns option handling
        if (s.cols.length > 0)
        {
            import std.algorithm : map;

            col = s.cols.map!(a => i`$(tableName).$(a)`.text).join(",");
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
                    a => i`$(includeTable).$(a) AS "$(includeTable).$(a)"`.text);
                cols ~= icols.join(",");
            }
            else
            {
                cols ~= i`$(includeTable).*`.text;
            }

            // auto relationKey = meta.relations[i"$(tableName).$(includeTable)".text].str;
            import std.algorithm : canFind;
            import std.array;

            string relationKey = "";
            foreach (key; meta.relations.array)
            {
                if (canFind(key.object.keys, i"$(tableName).$(includeTable)".text))
                {
                    relationKey = key.object[i"$(tableName).$(includeTable)".text].str;
                }
            }
            string[] referenceColumns = relationKey.split(".");
            joins ~= i` LEFT JOIN "$(includeTable)" ON "$(tableName)".$(referenceColumns[0]) = "$(includeTable)".$(referenceColumns[1])`
                .text;

        }
        import std.array;

        string incCols = cols.join(",");
        if (incCols.length > 0)
        {
            col ~= "," ~ incCols;
        }
        string q = i`SELECT $(col) FROM "$(tableName)"`.text;
        q ~= joins.join(" ");
        if (where.length > 0)
        {
            auto whereClause = generateWhereClause(this.meta.tableName, s.seperator, 1, where[0 .. $]);
            string whereQuery = whereClause[0];
            q ~= i" WHERE $(whereQuery)".text;
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
            import postgres._internal.helpers : toSnakeCase;

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

                        string objectRef = i`{"type":"$(cast(string)attr.type)","properties":""}`
                            .text;
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
                            propString ~= i" DEFAULT '$(attr.defaultValue)'".text;
                            this.meta.columns[tbc]["properties"] = propString;
                        }
                        else // @suppress(dscanner.bugs.if_else_same)
                        {
                            string propString = this.meta.columns[tbc]["properties"].str;
                            propString ~= i" DEFAULT $(attr.defaultValue)".text;
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
                        j[i"$(tableName).$(attr.table)".text] = i"$(tbc).$(attr.referenceKey)".text;

                        this.meta.relations.array ~= j;

                        this.meta.columns[tbc].object["references"] = i`FOREIGN KEY ($(tbc)) REFERENCES "$(attr.table)"($(attr.referenceKey))`
                            .text;

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
                i`{"type":"SERIAL","properties":" PRIMARY KEY"}`.text);
        }
    }

}
