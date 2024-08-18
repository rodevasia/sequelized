# Sequelized  ( WIP ) ( Tested only on windows)

This is a simple postgre based ORM based on JS sequelize

Support: pg 16

Must be added this on `dub.json` for windows 
```json
"libs": [ "pq" ],
    "lflags-windows-x86_64": [ "-LIBPATH:C:/Program Files/PostgreSQL/16/lib/" ],
    "copyFiles-windows-x86_64": [
        "C:/Program Files/PostgreSQL/16/lib/libpq.dll",
        "C:/Program Files/PostgreSQL/16/bin/libintl-9.dll",
        "C:/Program Files/PostgreSQL/16/bin/libssl-3-x64.dll",
        "C:/Program Files/PostgreSQL/16/bin/libcrypto-3-x64.dll",
		"C:/Program Files/PostgreSQL/16/bin/libwinpthread-1.dll",
		"C:/Program Files/PostgreSQL/16/bin/libiconv-2.dll"
    ],
```

### Initialize Connection

```d
  import postgre._internal.connection;
  Postgres c = new Postgres(DatabaseConnectionOption);
```

### Creating Models

```d

class Users : Schema
{
	mixin Model;

	@Type(DataTypes.SERIAL)
	@PmKey()
	@NotNull()
	long id;

	@Type(DataTypes.VARCHAR)
	@NotNull()
	string name = null;
}
```

