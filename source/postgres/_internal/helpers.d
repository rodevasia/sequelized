module postgres._internal.helpers;

void generateQuery(attrs...)()
{
    static foreach (uda; attrs)
    {
        writeln(uda.stringof);
    }
}

string toSnakeCase(string str)
{
    string snakeCase = "";
    foreach (c; str)
    {
        if (c >= 'A' && c <= 'Z')
        {
            snakeCase ~= "_" ~ cast(char)(c + 32);
        }
        else
        {
            snakeCase ~= c;
        }
    }
    return snakeCase;
}