module postgres.model;


import std.stdio;
import postgres._internal.consts;
import std.traits;
import std.conv;
import postgres._internal.exceptions;
import core.stdcpp.type_traits;
import core.cpuid;
import std.variant;
import postgres.implementation.core:Postgres,QueryResult;
import postgres.implementation.exception;

interface Schema
{
}



mixin template Model()
{

    private Postgres manager;
    private ModelMetaData meta = ModelMetaData();
    private string[] reservedMembers = ["manager", "meta", "reservedMembers"];
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

    private string syncQueryGenerator()
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

    auto insert()
    {

        try
        {

            import std.conv;
            import std.meta;
            import std.typecons;

            auto query = insertQueryGenerator();
            string sql = query[0];
            string name = i"insert_$(this.meta.tableName)_statement".text;
            QueryResult re = this.manager.executePreparedStatement(name,sql, query[1 .. $]);

            int result = re.rows[0]["id"].to!int;
            
            return result;
        }
        catch (PGSqlException e)
        {
            writeln(e.code);
            return 0;
        }
    }

    private auto insertQueryGenerator()
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
        int argIndex=1;
        // writeln(this.tupleof);
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
                column ~= i"$(col), ".text;
                values ~= i" $$(argIndex),".text;
                argIndex++;
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

        // writeln(tup);
        auto t = this.tupleof;
        Tuple!(typeof(t)) tup = tuple(t);
        auto setValue = tup.slice!(4, tup.length);

        return tuple(q) ~ setValue;
    }

    auto update(WhereClause[] where)
    {
        // import arsd.database : DatabaseException;

        try
        {

            import std.conv;
            import std.meta;
            import std.typecons;

            auto query = updateQueryGenerator(where);
            string sql = query[0].to!string;
            writeln(query);
           
            string prepareStmtName = i"update_$(this.meta.tableName)_stmt".text;
            
            string prepareStmt = i"PREPARE $(prepareStmtName) AS $(sql)".text;
            
            
             
            // auto re = this.manager.db.query(sql, query[1 .. $]);


            // writeln(re);
            // int result = 0;
            // foreach (key; re)
            // {
            //     result = key[0].to!int;
            // }
            // return result;
        }
        catch (Exception e)
        {
            writeln(e.msg);
            // writeln(typeof(e).stringof);
            // throw e;
        }
    }

    private auto updateQueryGenerator(WhereClause[] where)
    {
        import std.algorithm : canFind;
        import std.conv;
        import std.json;
        import std.typecons;
        import std.array;

        string tableName = this.meta.tableName;
        string aliasString = "t"; // Adjust alias if necessary
        string primaryKey = this.meta.primaryKey;
        string q = i`UPDATE "$(tableName)" AS $(aliasString) SET `.text;

        string setClause = "";
        string fromClause = "";
        string whereClause = generateWhereClause(where);
        string returningClause = "";

        auto autoIncrementals = this.meta.autoIncrementals;
        int pos =1;
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

                setClause ~= i" $(aliasString).$(col)=\$$(pos),".text;
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

        // Optional FROM clause
        if (fromClause.length > 0)
        {
            q ~= i" FROM $(fromClause)".text;
        }

        // Optional WHERE clause
        if (whereClause.length > 0)
        {
            q ~= i" WHERE $(whereClause)".text;
        }

     
           q ~= " RETURNING CASE WHEN xmax IS NOT NULL THEN true ELSE false END AS updated;";
        

        // q ~= i" WHERE $(alias).$(primaryKey) = ?".text;

        // Handling values
        auto t = this.tupleof;
        Tuple!(typeof(t)) tup = tuple(t);
        auto setValue = tup.slice!(4, tup.length); // Adjust slicing based on actual structure

        return tuple(q) ~ setValue;
    }

    private void generateMeta()
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

                        string objectRef = i`{"type":"$(attr.type)","properties":""}`.text;
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
                        string[] textTypes = [DataTypes.VARCHAR, DataTypes.TEXT];
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

                        this.meta.columns[tbc].object["references"] = i`FOREIGN KEY ($(tbc)) REFERENCES "$(attr.table)"($(attr.referenceKey))`
                            .text;

                    }

                }
                column = column ~ ",";
            }
        }
    }
}
