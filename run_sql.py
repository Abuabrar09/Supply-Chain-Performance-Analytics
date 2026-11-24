import sys
import duckdb

con = duckdb.connect("/content/supply_chain.duckdb")  # local disk, not Drive
sql = open(sys.argv[1]).read()
for stmt in sql.split(";"):
    body = "\n".join(l for l in stmt.splitlines()
                     if not l.strip().startswith("--")).strip()
    if not body:
        continue
    print("\n>>", body.splitlines()[0][:90])
    rel = con.execute(body)
    if rel.description:
        print(rel.df().to_string(index=False))
con.close()
