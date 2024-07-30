import std.stdio;
import arsd.postgres;
import std.format;
import postgres._internal.connection : DatabaseConnectionOption, PGSQLConnectionManager;
import postgres.model : Model, Schema;
import postgres._internal.consts;

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
		PGSQLConnectionManager manager = new PGSQLConnectionManager(options);

		User user = new User(manager);
		Post post = new Post(manager);
		user.name = "John";
		user.age = 25;
		// user.insert();
		WhereClause exp= WhereClause();
		user.update([exp.equals("id", 1),exp.equals("name", "John")]);
		// user.sync();
		// post.sync();

	}
	catch (Exception e)
	{
		writeln(e.msg);
	}
}

class User : Schema
{
	mixin Model;

	@Type(DataTypes.SERIAL)
	@PmKey()
	@NotNull()
	long id;

	@Type(DataTypes.VARCHAR)
	@NotNull()
	// @Unique()
	string name=null;

	@Type(DataTypes.NUMERIC)
	@NotNull()
	int age;
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

	@Type(DataTypes.NUMERIC)
	@ForeignKey("user", "id",)
	long userId;

}
