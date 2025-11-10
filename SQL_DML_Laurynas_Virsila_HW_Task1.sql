-- Subtask 1: Insert your 3 favorite movies into public.film
BEGIN;

WITH english_lang AS (
  SELECT language_id
  FROM public.language
  WHERE UPPER(name) = 'ENGLISH'
  LIMIT 1
),
to_insert AS (
  SELECT
    'Inception'::text                                  AS title,
    'A thief who steals corporate secrets via dreams.' AS description,
    2010::integer                                      AS release_year,
    (SELECT language_id FROM english_lang)             AS language_id,
    NULL::integer                                      AS original_language_id,
    7::smallint                                        AS rental_duration,  -- 1 week
    4.99::numeric(4,2)                                 AS rental_rate,
    148::smallint                                      AS length,
    19.99::numeric(5,2)                                AS replacement_cost,
    'PG-13'::mpaa_rating                               AS rating,
    ARRAY['Behind the Scenes']::text[]                 AS special_features
  UNION ALL
  SELECT
    'The Godfather',
    'A patriarch of a crime dynasty transfers control to his son.',
    1972,
    (SELECT language_id FROM english_lang),
    NULL,
    14,                                                -- 2 weeks
    9.99,
    175,
    24.99,
    'R'::mpaa_rating,
    ARRAY['Trailers','Deleted Scenes']
  UNION ALL
  SELECT
    'Ocean''s Eleven',
    'Danny Ocean and his crew plan a Las Vegas heist.',
    2001,
    (SELECT language_id FROM english_lang),
    NULL,
    21,                                                -- 3 weeks
    19.99,
    116,
    24.99,
    'PG-13'::mpaa_rating,
    ARRAY['Trailers']
)
INSERT INTO public.film
(title, description, release_year, language_id, original_language_id,
 rental_duration, rental_rate, length, replacement_cost, rating, last_update, special_features)
SELECT ti.title, ti.description, ti.release_year, ti.language_id, ti.original_language_id,
       ti.rental_duration, ti.rental_rate, ti.length, ti.replacement_cost, ti.rating,
       current_date, ti.special_features
FROM to_insert ti
WHERE NOT EXISTS (
  SELECT 1 FROM public.film f
  WHERE f.title = ti.title AND f.release_year = ti.release_year
)
RETURNING film_id, title, release_year, rental_duration, rental_rate;

-- Quick check
SELECT film_id, title, release_year, rental_duration, rental_rate
FROM public.film
WHERE title IN ('Inception','The Godfather','Ocean''s Eleven')
ORDER BY title;

COMMIT;

-- Subtask 2: Insert real actors and link them via public.film_actor

BEGIN;

-- Insert ≥ 6 real actors idempotently
WITH actors(first_name, last_name) AS (
  VALUES
  ('Leonardo','DiCaprio'),
  ('Joseph','Gordon-Levitt'),
  ('Marlon','Brando'),
  ('Al','Pacino'),
  ('George','Clooney'),
  ('Brad','Pitt')
)
INSERT INTO public.actor (first_name, last_name, last_update)
SELECT a.first_name, a.last_name, current_date
FROM actors a
WHERE NOT EXISTS (
  SELECT 1 FROM public.actor ax
  WHERE ax.first_name = a.first_name AND ax.last_name = a.last_name
)
RETURNING actor_id, first_name, last_name;

-- Link actors to target films
WITH film_map AS (
  SELECT f.title, f.release_year, f.film_id
  FROM public.film f
  WHERE (f.title,f.release_year) IN (
    ('Inception',2010),
    ('The Godfather',1972),
    ('Ocean''s Eleven',2001)
  )
),
pairs AS (
  SELECT 'Inception'::text AS title, 2010::int AS release_year, 'Leonardo'::text AS fn, 'DiCaprio'::text AS ln
  UNION ALL SELECT 'Inception',2010,'Joseph','Gordon-Levitt'
  UNION ALL SELECT 'The Godfather',1972,'Marlon','Brando'
  UNION ALL SELECT 'The Godfather',1972,'Al','Pacino'
  UNION ALL SELECT 'Ocean''s Eleven',2001,'George','Clooney'
  UNION ALL SELECT 'Ocean''s Eleven',2001,'Brad','Pitt'
),
to_link AS (
  SELECT fm.film_id, a.actor_id
  FROM pairs p
  INNER JOIN film_map fm
    ON fm.title = p.title AND fm.release_year = p.release_year
  INNER JOIN public.actor a
    ON a.first_name = p.fn AND a.last_name = p.ln
)
INSERT INTO public.film_actor (actor_id, film_id, last_update)
SELECT tl.actor_id, tl.film_id, current_date
FROM to_link tl
WHERE NOT EXISTS (
  SELECT 1 FROM public.film_actor fa
  WHERE fa.actor_id = tl.actor_id AND fa.film_id = tl.film_id
)
RETURNING actor_id, film_id;

-- Quick check
SELECT a.first_name, a.last_name, f.title
FROM public.film_actor fa
INNER JOIN public.actor a ON a.actor_id = fa.actor_id
INNER JOIN public.film f ON f.film_id = fa.film_id
WHERE f.title IN ('Inception','The Godfather','Ocean''s Eleven')
ORDER BY f.title, a.last_name, a.first_name;

COMMIT;

-- Subtask 3: Add these films to any store’s inventory

BEGIN;

WITH any_store AS (
  SELECT s.store_id
  FROM public.store s
  ORDER BY s.store_id
  LIMIT 1
),
target_films AS (
  SELECT f.film_id
  FROM public.film f
  WHERE (f.title,f.release_year) IN (
    ('Inception',2010),
    ('The Godfather',1972),
    ('Ocean''s Eleven',2001)
  )
)
INSERT INTO public.inventory (film_id, store_id, last_update)
SELECT tf.film_id, asx.store_id, current_date
FROM target_films tf
CROSS JOIN any_store asx
WHERE NOT EXISTS (
  SELECT 1 FROM public.inventory i
  WHERE i.film_id = tf.film_id AND i.store_id = asx.store_id
)
RETURNING inventory_id, film_id, store_id;

-- Quick check
SELECT i.inventory_id, f.title, i.store_id
FROM public.inventory i
INNER JOIN public.film f ON f.film_id = i.film_id
WHERE f.title IN ('Inception','The Godfather','Ocean''s Eleven')
ORDER BY f.title, i.inventory_id;

COMMIT;


-- Subtask 4: Update an existing “heavy” customer (≥43 rentals & ≥43 payments)

BEGIN;

WITH rental_counts AS (
  SELECT r.customer_id, COUNT(*) AS rentals
  FROM public.rental r
  GROUP BY r.customer_id
),
payment_counts AS (
  SELECT p.customer_id, COUNT(*) AS payments
  FROM public.payment p
  GROUP BY p.customer_id
),
heavy AS (
  SELECT rc.customer_id
  FROM rental_counts rc
  INNER JOIN payment_counts pc ON pc.customer_id = rc.customer_id
  WHERE rc.rentals >= 43 AND pc.payments >= 43
  ORDER BY rc.customer_id
  LIMIT 1
),
use_address AS (
  -- Choose any existing address deterministically (optional).
  SELECT address_id FROM public.address ORDER BY address_id LIMIT 1
)
UPDATE public.customer c
SET first_name = 'Laurynas',
    last_name  = 'Virsila',
    email      = 'laurynas.virsila@gmail.com',
    last_update = current_date
FROM heavy
WHERE c.customer_id = heavy.customer_id
RETURNING c.customer_id, c.first_name, c.last_name, c.email, c.address_id;

-- Quick check
SELECT c.customer_id, c.first_name, c.last_name, c.email, c.address_id
FROM public.customer c
WHERE c.first_name = 'Laurynas' AND c.last_name = 'Virsila';

COMMIT;

-- Subtask 5: Remove your activity from all tables except Customer & Inventory

BEGIN;

WITH me AS (
  SELECT c.customer_id
  FROM public.customer c
  WHERE c.first_name = 'Laurynas' AND c.last_name = 'Virsila'
  LIMIT 1
),
my_rentals AS (
  SELECT r.rental_id
  FROM public.rental r
  INNER JOIN me ON me.customer_id = r.customer_id
)
-- Delete payments for your rentals
DELETE FROM public.payment p
USING my_rentals mr
WHERE p.rental_id = mr.rental_id
RETURNING p.payment_id, p.rental_id;

-- Delete your rentals
WITH me AS (
  SELECT c.customer_id
  FROM public.customer c
  WHERE c.first_name = 'Laurynas' AND c.last_name = 'Virsila'
  LIMIT 1
)
DELETE FROM public.rental r
USING me
WHERE r.customer_id = me.customer_id
RETURNING r.rental_id;

-- Quick check (you remain as a customer; activity cleared)
WITH me AS (
  SELECT c.customer_id
  FROM public.customer c
  WHERE c.first_name = 'Laurynas' AND c.last_name = 'Virsila'
  LIMIT 1
)
SELECT
  (SELECT COUNT(*) FROM public.rental  r WHERE r.customer_id = me.customer_id)  AS rentals_after,
  (SELECT COUNT(*) FROM public.payment p WHERE p.customer_id = me.customer_id)  AS payments_after
FROM me;

COMMIT;


--   SUBTASK 6 — Rent the 3 favorite movies again and pay


BEGIN;

-- Step 1: Rent the movies
WITH me AS (
  SELECT c.customer_id
  FROM public.customer c
  WHERE c.first_name = 'Laurynas' AND c.last_name = 'Virsila'
  LIMIT 1
),
store_holding AS (
  SELECT DISTINCT i.store_id
  FROM public.inventory i
  INNER JOIN public.film f ON f.film_id = i.film_id
  WHERE f.title IN ('Inception','The Godfather','Ocean''s Eleven')
  ORDER BY i.store_id
  LIMIT 1
),
staff_in_store AS (
  SELECT s.staff_id, s.store_id
  FROM public.staff s
  INNER JOIN store_holding sh ON sh.store_id = s.store_id
  ORDER BY s.staff_id
  LIMIT 1
),
target_inventories AS (
  SELECT i.inventory_id, i.store_id, f.title
  FROM public.inventory i
  INNER JOIN public.film f ON f.film_id = i.film_id
  INNER JOIN store_holding sh ON sh.store_id = i.store_id
  WHERE f.title IN ('Inception','The Godfather','Ocean''s Eleven')
),
to_rent AS (
  SELECT
    ti.inventory_id,
    (DATE '2017-02-15')::timestamp AS rental_date,
    (DATE '2017-02-17')::timestamp AS return_date,
    (SELECT staff_id FROM staff_in_store) AS staff_id
  FROM target_inventories ti
)
INSERT INTO public.rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
SELECT tr.rental_date, tr.inventory_id, me.customer_id, tr.return_date, tr.staff_id, current_date
FROM to_rent tr
CROSS JOIN me
WHERE NOT EXISTS (
  SELECT 1 FROM public.rental r
  WHERE r.inventory_id = tr.inventory_id
    AND r.customer_id  = me.customer_id
    AND r.rental_date  = tr.rental_date
)
RETURNING rental_id, inventory_id, customer_id;

-- Step 2: Add payments for those rentals (payment_date in first half of 2017)
WITH me AS (
  SELECT c.customer_id
  FROM public.customer c
  WHERE c.first_name = 'Laurynas' AND c.last_name = 'Virsila'
  LIMIT 1
),
new_rentals AS (
  SELECT r.rental_id, r.customer_id, r.staff_id, r.inventory_id
  FROM public.rental r
  INNER JOIN me ON me.customer_id = r.customer_id
  WHERE r.rental_date::date = DATE '2017-02-15'
),
amount_by_inventory AS (
  SELECT nr.rental_id, nr.customer_id, nr.staff_id,
         f.rental_rate AS amount
  FROM new_rentals nr
  INNER JOIN public.inventory i ON i.inventory_id = nr.inventory_id
  INNER JOIN public.film f      ON f.film_id      = i.film_id
)
INSERT INTO public.payment (customer_id, staff_id, rental_id, amount, payment_date)
SELECT abi.customer_id, abi.staff_id, abi.rental_id,
       abi.amount,
       (DATE '2017-02-15')::timestamp AS payment_date
FROM amount_by_inventory abi
WHERE NOT EXISTS (
  SELECT 1 FROM public.payment p
  WHERE p.rental_id = abi.rental_id
)
RETURNING payment_id, rental_id, amount;

-- Step 3: Quick verification
WITH me AS (
  SELECT c.customer_id
  FROM public.customer c
  WHERE c.first_name = 'Laurynas' AND c.last_name = 'Virsila'
  LIMIT 1
)
SELECT
  (SELECT COUNT(*) FROM public.rental  r WHERE r.customer_id = me.customer_id)  AS rentals_now,
  (SELECT COUNT(*) FROM public.payment p WHERE p.customer_id = me.customer_id)  AS payments_now
FROM me;

COMMIT;

