## DuckDB SQL & external interface

### Direct call
- When a SQL file is executed at a duckdb file, use pipe as below:

```bash
duckdb < my_script.sql
# to make a persistent duckdb, call below and find test.duckdb
# duckdb test.duckdb < my_script.sql
```


### `duckplyr`

```bash
install.packages('duckplyr')
```

- `duckplyr` is a drop-in replacement of `dplyr` for DuckDB in R


### `ibis`
```bash
# after activating your env
uv pip install 'ibis-framework[duckdb]'
```

