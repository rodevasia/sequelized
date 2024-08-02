module postgres._internal.connection;


// import std.stdio;
// import std.conv;
// import std.regex;
// import postgres.model;
// import postgres.implementation.core:PostgreSql;

struct DatabaseConnectionOption
{
    // STRING_CONNECTION_OPTION_MAP 
    string application_name;
    string client_encoding;
    string database;
    string host;
    string password;
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

// private struct PublicOptions
// {
//     // BOOLEAN_CONNECTION_OPTION_MAP
//     bool binary = false;
//     bool keepAlive = false;
//     bool ssl = false;

//     // NUMBER_CONNECTION_OPTION_MAP
//     long port;
//     long statement_timeout;
//     long query_timeout;
//     long keepAliveInitialDelayMillis;
//     long idle_in_transaction_session_timeout;
//     long connectionTimeoutMillis;
//     long lock_timeout;
// }

// public class PGSQLConnectionManager
// {

//     private DatabaseConnectionOption options;
//     PostgreSql db;

//     this(DatabaseConnectionOption options)
//     {

//         this.options = options;
//         this.db = null;
//         connect();
//     }

//     private void connect()
//     {
//         try
//         {
//             string connectionString =i"host=$(options.host) port=$(options.port) 
//             dbname=$(options.database) user=$(options.application_name)
//              password=$(options.password) client_encoding=$(options.client_encoding) application_name=$(options.application_name)
//               sslmode=$(options.ssl ? " require" : "disable")".text;

//             this.db = new PostgreSql(connectionString); // Assign a value to the 'db' variable
//             writeln("Connected to the database");
//         }
//         catch (Exception e)
//         {
//             writefln("Error: %s", e.msg);
//         }

//     }

//     //  Restrict the access to the options
//     PublicOptions getOptions()
//     {
//         PublicOptions publicOptions;
//         publicOptions.binary = options.binary;
//         publicOptions.keepAlive = options.keepAlive;
//         publicOptions.ssl = options.ssl;
//         publicOptions.port = options.port;
//         publicOptions.statement_timeout = options.statement_timeout;
//         publicOptions.query_timeout = options.query_timeout;
//         publicOptions.keepAliveInitialDelayMillis = options.keepAliveInitialDelayMillis;
//         publicOptions.idle_in_transaction_session_timeout = options
//             .idle_in_transaction_session_timeout;
//         publicOptions.connectionTimeoutMillis = options.connectionTimeoutMillis;
//         publicOptions.lock_timeout = options.lock_timeout;
//         return publicOptions;
//     }
   
// }