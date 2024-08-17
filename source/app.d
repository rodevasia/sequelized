import std.string;
import std.bitmanip;

import std.stdio;
import std.format;

// import postgres._internal.connection : DatabaseConnectionOption, PGSQLConnectionManager;
import postgres.model : Model, Schema;
import postgres._internal.consts;

import postgres.implementation.core;
import std.sumtype;

void main()
{
	try
	{

		DatabaseConnectionOption options = DatabaseConnectionOption();
		options.application_name = "postgres";
		options.client_encoding = "UTF8";
		options.database = "postgres";
		options.host = "localhost";
		options.password = "12345";
		options.port = 5432;
		options.binary = false;
		options.keepAlive = false;
		options.ssl = false;
		options.statement_timeout = 0;
		options.query_timeout = 0;
		options.keepAliveInitialDelayMillis = 0;
		options.idle_in_transaction_session_timeout = 0;
		options.connectionTimeoutMillis = 0;
		options.lock_timeout = 0;
		Postgres c = new Postgres(options);

		Users user = new Users(c);
		Includes inc = Includes("users");
		inc.options.cols = ["id",];
		SelectOptions s = SelectOptions();
		// s.include

		s.includes = [inc];
		s.cols = [ "content"];
		WhereClause exp = new WhereClause();
		// post.select(s, exp.eq("id", 1));
		// user.select(s,exp.eq("id", 1));

		Post post = new Post(c);
		writeln(post.select(s, exp.eq("id", 2)));

		// post.title = "Hello";
		post.content = "World updated";
		// post.userId = 2;
		// post.insert();
		// user.sync();
		// post.sync();

		// post.distroy(exp.eq("id", 1));

	}
	catch (PGSqlException e)
	{
		writeln(e);
	}

}

class Users : Schema
{
	mixin Model;

	@Type(DataTypes.SERIAL)
	@PmKey()
	@NotNull()
	long id;

	@Type(DataTypes.VARCHAR)
	@NotNull()
	 // @Unique()
	string name = null;

	// @Type(DataTypes.NUMERIC)
	// @NotNull()
	// int age;
}

class Post
{
	mixin Model;

	@Type(DataTypes.SERIAL)
	@PmKey()
	long id;

	@Type(DataTypes.VARCHAR)
	string title;

	@Type(DataTypes.TEXT)
	string content;

	@Type(DataTypes.TIMESTAMP)
	@DefaultValue(DefaultDateType.timestamp)
	string createdAt;

	@Type(DataTypes.SERIAL)
	@ForeignKey("users", "id",)
	long userId;

}
