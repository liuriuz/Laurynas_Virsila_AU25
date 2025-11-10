--   TASK 2 — DELETE vs TRUNCATE performance and space comparison

DROP TABLE IF EXISTS table_to_delete;

CREATE TABLE table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1,(10^7)::int) x;

-- Check row count
SELECT COUNT(*) AS total_rows FROM table_to_delete;


-- 2. Check space consumption of the table
-- table_size 575 MB, total_bytes 602,415,104

SELECT *,
       pg_size_pretty(total_bytes) AS total,
       pg_size_pretty(index_bytes) AS index,
       pg_size_pretty(toast_bytes) AS toast,
       pg_size_pretty(table_bytes) AS table_size
FROM (
  SELECT *,
         total_bytes - index_bytes - COALESCE(toast_bytes,0) AS table_bytes
  FROM (
    SELECT c.oid,
           nspname AS table_schema,
           relname AS table_name,
           c.reltuples AS row_estimate,
           pg_total_relation_size(c.oid)        AS total_bytes,
           pg_indexes_size(c.oid)               AS index_bytes,
           pg_total_relation_size(reltoastrelid) AS toast_bytes
    FROM pg_class c
    LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE relkind = 'r'
  ) a
) a
WHERE table_name LIKE '%table_to_delete%';



-- 3. Perform DELETE operation
-- 3a. time taken for the DELETE - 29s.

DELETE FROM public.table_to_delete
WHERE REPLACE(col, 'veeeeeeery_long_string','')::int % 3 = 0;


-- 3b. Check table space usage again (after DELETE)
-- 602,611,712 total_bytes, table size 575 MB

SELECT *,
       pg_size_pretty(total_bytes) AS total,
       pg_size_pretty(index_bytes) AS index,
       pg_size_pretty(toast_bytes) AS toast,
       pg_size_pretty(table_bytes) AS table_size
FROM (
  SELECT *,
         total_bytes - index_bytes - COALESCE(toast_bytes,0) AS table_bytes
  FROM (
    SELECT c.oid,
           nspname AS table_schema,
           relname AS table_name,
           c.reltuples AS row_estimate,
           pg_total_relation_size(c.oid)        AS total_bytes,
           pg_indexes_size(c.oid)               AS index_bytes,
           pg_total_relation_size(reltoastrelid) AS toast_bytes
    FROM pg_class c
    LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE relkind = 'r'
  ) a
) a
WHERE table_name LIKE '%table_to_delete%';


-- 3c. Reclaim space — VACUUM FULL VERBOSE
-- "public.table_to_delete": found 1461248 removable, 6666667 nonremovable row versions in 73536 pages

VACUUM FULL VERBOSE public.table_to_delete;


-- 3d. Check space again (After VACUUM FULL)
-- total_bytes after VACUUM - 401,653,760, table size 383 MB

SELECT *,
       pg_size_pretty(total_bytes) AS total,
       pg_size_pretty(index_bytes) AS index,
       pg_size_pretty(toast_bytes) AS toast,
       pg_size_pretty(table_bytes) AS table_size
FROM (
  SELECT *,
         total_bytes - index_bytes - COALESCE(toast_bytes,0) AS table_bytes
  FROM (
    SELECT c.oid,
           nspname AS table_schema,
           relname AS table_name,
           c.reltuples AS row_estimate,
           pg_total_relation_size(c.oid)        AS total_bytes,
           pg_indexes_size(c.oid)               AS index_bytes,
           pg_total_relation_size(reltoastrelid) AS toast_bytes
    FROM pg_class c
    LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE relkind = 'r'
  ) a
) a
WHERE table_name LIKE '%table_to_delete%';


-- 3e. Recreate the table for TRUNCATE test


DROP TABLE IF EXISTS public.table_to_delete;

CREATE TABLE public.table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1,(10^7)::int) x;



-- 4. Perform TRUNCATE operation
-- 4a. time taken for TRUNCATE - 1.0s.
-- 4b. Truncate is faster since removes all rows at once not like delete which does it row by row

TRUNCATE public.table_to_delete;


-- 4c. Check table space again after TRUNCATE
-- table size after TRUNCATE - 0 bytes, total_bytes - 8,192

SELECT *,
       pg_size_pretty(total_bytes) AS total,
       pg_size_pretty(index_bytes) AS index,
       pg_size_pretty(toast_bytes) AS toast,
       pg_size_pretty(table_bytes) AS table_size
FROM (
  SELECT *,
         total_bytes - index_bytes - COALESCE(toast_bytes,0) AS table_bytes
  FROM (
    SELECT c.oid,
           nspname AS table_schema,
           relname AS table_name,
           c.reltuples AS row_estimate,
           pg_total_relation_size(c.oid)        AS total_bytes,
           pg_indexes_size(c.oid)               AS index_bytes,
           pg_total_relation_size(reltoastrelid) AS toast_bytes
    FROM pg_class c
    LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE relkind = 'r'
  ) a
) a
WHERE table_name LIKE '%table_to_delete%';



/*   5. Conclusions
table_size:
after DELETE 575 MB
after VACUUM FULL 383 MB
after TRUNCATE 0 bytes

Duration of each operation:
DELETE 29s
TRUNCATE 1.0s
*/
