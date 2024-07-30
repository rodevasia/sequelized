module postgres._internal.exceptions;
 import std.stdio;
 class SQLException : Exception
 {
     long code;
     string sqlState;
     string message;
     string detail;
     this(Exception e)
     {
         super(e.msg);
         
     }
 }

 class QueryGeneratorException : Exception
 {
     this(string message)
     {
         super("QueryGeneratorException: " ~ message);
     }
 }