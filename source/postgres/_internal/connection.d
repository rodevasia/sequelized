module postgres._internal.connection;

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
