/* ============================================================
   PART 1
   TASK 1
     The marketing team needs a list of animation movies 
     between 2017 and 2019 to promote family-friendly content 
     in an upcoming season in stores. 
     Show all animation movies
     	released during this period with 
     	rate more than 1, 
     	sorted alphabetically
   ============================================================ */

-- task 1: CTE
WITH animation_category AS (
    SELECT category_id
    FROM public.category
    WHERE UPPER(cat.name) = 'ANIMATION'
)
SELECT fil.title,
       fil.release_year,
       fil.rental_rate
FROM public.film fil
INNER JOIN public.film_category fct
    ON fil.film_id = fct.film_id
INNER JOIN animation_category ac
    ON fct.category_id = ac.category_id
WHERE fil.release_year BETWEEN 2017 AND 2019
  AND fil.rental_rate > 1
ORDER BY fil.title;
/* Pros: Easy to read step by step
   Cons: Slightly longer query, not always fastest on huge data */


-- task 1: Subquery
SELECT fil.title,
       fil.release_year,
       fil.rental_rate
FROM public.film fil
INNER JOIN public.film_category fct
    ON fil.film_id = fct.film_id
WHERE fct.category_id IN (
    SELECT category_id
    FROM public.category
    WHERE UPPER(cat.name) = 'ANIMATION'
)
  AND fil.release_year BETWEEN 2017 AND 2019
  AND fil.rental_rate > 1
ORDER BY fil.title;
/* Pros: Compact and simple
   Cons: Subquery harder to reuse later */


-- task 1: JOIN
SELECT fil.title,
       fil.release_year,
       fil.rental_rate
FROM public.film fil
INNER JOIN public.film_category fct
    ON fil.film_id = fct.film_id
INNER JOIN public.category cat
    ON fct.category_id = cat.category_id
WHERE UPPER(cat.name) = 'ANIMATION'
  AND fil.release_year BETWEEN 2017 AND 2019
  AND fil.rental_rate > 1
ORDER BY fil.title;
/* Pros: Very direct and usually fastest
   Cons: All logic in one place (less modular) */



/* ============================================================
   TASK 2
   Goal:
     The finance department requires a report on store performance
     to assess profitability and plan resource allocation for 
     stores after March 2017. Calculate the revenue earned by 
     each rental store after March 2017 (since April) 
     (include columns: address and address2 – as one column, revenue)
    ============================================================ */


-- task 2: CTE
WITH payments_since_april AS (
    SELECT payment_id, customer_id, staff_id, rental_id, amount, payment_date
    FROM public.payment
    WHERE payment_date >= DATE '2017-04-01'
),
store_revenue AS (
    SELECT inv.store_id, SUM(pay.amount) AS revenue
    FROM public.inventory inv
    INNER JOIN public.rental rnt ON inv.inventory_id = rnt.inventory_id
    INNER JOIN payments_since_april pay ON rnt.rental_id = pay.rental_id
    GROUP BY inv.store_id
)
SELECT CONCAT(addr.address, ' ', COALESCE(addr.address2, '')) AS full_address,
       sr.revenue
FROM store_revenue sr
INNER JOIN public.store stf ON stf.store_id = sr.store_id
INNER JOIN public.address addr ON addr.address_id = stf.address_id
ORDER BY full_address;
/* Pros: Very readable, easy to test each CTE
   Cons: A bit verbose */


-- task 2: Subquery
SELECT CONCAT(addr.address, ' ', COALESCE(addr.address2, '')) AS full_address,
       sr.revenue
FROM (
    SELECT inv.store_id, SUM(pay.amount) AS revenue
    FROM public.inventory inv
    INNER JOIN public.rental rnt ON inv.inventory_id = rnt.inventory_id
    INNER JOIN public.payment pay ON rnt.rental_id = pay.rental_id
    WHERE pay.payment_date >= DATE '2017-04-01'
    GROUP BY inv.store_id
) AS sr
INNER JOIN public.store stf ON stf.store_id = sr.store_id
INNER JOIN public.address addr ON addr.address_id = stf.address_id
ORDER BY full_address;
/* Pros: Compact and efficient
   Cons: Subquery not reusable */


-- task 2: JOIN
SELECT CONCAT(addr.address, ' ', COALESCE(addr.address2, '')) AS full_address,
       SUM(pay.amount) AS revenue
FROM public.store stf
INNER JOIN public.address addr ON addr.address_id = stf.address_id
INNER JOIN public.inventory inv ON inv.store_id = stf.store_id
INNER JOIN public.rental rnt ON rnt.inventory_id = inv.inventory_id
INNER JOIN public.payment pay ON pay.rental_id = rnt.rental_id
WHERE pay.payment_date >= DATE '2017-04-01'
GROUP BY CONCAT(addr.address, ' ', COALESCE(addr.address2, ''))
ORDER BY full_address;
/* Pros: Fastest and simplest
   Cons: Harder to isolate steps for debugging */



/* ============================================================
   TASK 3
   Goal:
     Identify top-5 actors by number of movies released after 2015.
   ============================================================ */


-- task 3 CTE:
WITH recent_films AS (
    SELECT film_id
    FROM public.film
    WHERE release_year > 2015
),
actor_counts AS (
    SELECT act.actor_id, act.first_name, act.last_name,
           COUNT(DISTINCT fla.film_id) AS num_movies
    FROM public.actor act
    INNER JOIN public.film_actor fla ON act.actor_id = fla.actor_id
    INNER JOIN recent_films rf ON rf.film_id = fla.film_id
    GROUP BY act.actor_id, act.first_name, act.last_name
)
SELECT first_name, last_name, num_movies
FROM actor_counts
ORDER BY num_movies DESC, last_name, first_name
LIMIT 5;
/* Pros: Easy to follow and modular
   Cons: Slightly longer */


-- task 3 Subquery:
SELECT act.first_name,
       act.last_name,
       (
         SELECT COUNT(DISTINCT fla.film_id)
         FROM public.film_actor fla
         INNER JOIN public.film fil ON fla.film_id = fil.film_id
         WHERE fla.actor_id = act.actor_id
           AND fil.release_year > 2015
       ) AS num_movies
FROM public.actor act
ORDER BY num_movies DESC, last_name, first_name
LIMIT 5;
/* Pros: Very short
   Cons: May run slower on huge datasets */


-- task 3 JOIN:
SELECT act.first_name, act.last_name,
       COUNT(DISTINCT fil.film_id) AS num_movies
FROM public.actor act
INNER JOIN public.film_actor fla ON act.actor_id = fla.actor_id
INNER JOIN public.film fil ON fla.film_id = fil.film_id
WHERE fil.release_year > 2015
GROUP BY act.actor_id, act.first_name, act.last_name
ORDER BY num_movies DESC, last_name, first_name
LIMIT 5;
/* Pros: Clean and fast
   Cons: None for this case */



/* ============================================================
   TASK 4
   Goal:
     Track production trends for Drama, Travel, Documentary
   ============================================================ */


-- task 4 CTE:
WITH film_with_category AS (
    SELECT fil.release_year, cat.name AS category_name
    FROM public.film fil
    INNER JOIN public.film_category fct ON fil.film_id = fct.film_id
    INNER JOIN public.category cat ON fct.category_id = cat.category_id
    WHERE UPPER(cat.name) IN ('DRAMA', 'TRAVEL', 'DOCUMENTARY')
)
SELECT release_year,
       SUM(CASE WHEN category_name = 'Drama' THEN 1 ELSE 0 END) AS num_drama,
       SUM(CASE WHEN category_name = 'Travel' THEN 1 ELSE 0 END) AS num_travel,
       SUM(CASE WHEN category_name = 'Documentary' THEN 1 ELSE 0 END) AS num_documentary
FROM film_with_category
GROUP BY release_year
ORDER BY release_year DESC;
/* Pros: Clear and logical
   Cons: Slightly verbose */


-- task 4 Subquery:
SELECT fil.release_year,
    COALESCE((
        SELECT COUNT(DISTINCT fil1.film_id)
        FROM public.film fil1
        INNER JOIN public.film_category fct1 ON fil1.film_id = fct1.film_id
        INNER JOIN public.category cat1 ON fct1.category_id = cat1.category_id
        WHERE UPPER(cat1.name) = 'DRAMA' AND fil1.release_year = fil.release_year
    ), 0) AS num_drama,
    COALESCE((
        SELECT COUNT(DISTINCT fil2.film_id)
        FROM public.film fil2
        INNER JOIN public.film_category fct2 ON fil2.film_id = fct2.film_id
        INNER JOIN public.category cat2 ON fct2.category_id = cat2.category_id
        WHERE UPPER(cat2.name) = 'TRAVEL' AND fil2.release_year = fil.release_year
    ), 0) AS num_travel,
    COALESCE((
        SELECT COUNT(DISTINCT fil3.film_id)
        FROM public.film fil3
        INNER JOIN public.film_category fct3 ON fil3.film_id = fct3.film_id
        INNER JOIN public.category cat3 ON fct3.category_id = cat3.category_id
        WHERE UPPER(cat3.name) = 'DOCUMENTARY' AND fil3.release_year = fil.release_year
    ), 0) AS num_documentary
FROM public.film fil
GROUP BY fil.release_year
ORDER BY fil.release_year DESC;
/* Pros: Works fine
   Cons: Repetitive subqueries */


-- task 4 JOIN:
SELECT fil.release_year,
       SUM(CASE WHEN cat.name = 'Drama' THEN 1 ELSE 0 END) AS num_drama,
       SUM(CASE WHEN cat.name = 'Travel' THEN 1 ELSE 0 END) AS num_travel,
       SUM(CASE WHEN cat.name = 'Documentary' THEN 1 ELSE 0 END) AS num_documentary
FROM public.film fil
INNER JOIN public.film_category fct ON fil.film_id = fct.film_id
INNER JOIN public.category cat ON fct.category_id = cat.category_id
WHERE UPPER(cat.name) IN ('DRAMA', 'TRAVEL', 'DOCUMENTARY')
GROUP BY fil.release_year
ORDER BY fil.release_year DESC;
/* Pros: Fastest, simple
   Cons: None */



/* ============================================================
   PART 2
   TASK 1 – Top-performing employees 2017
   ============================================================ */

-- task 1 CTE:
WITH payments_2017 AS (
    SELECT pay.payment_id, pay.staff_id, pay.amount, pay.payment_date, inv.store_id
    FROM public.payment pay
    INNER JOIN public.rental rnt ON pay.rental_id = rnt.rental_id
    INNER JOIN public.inventory inv ON rnt.inventory_id = inv.inventory_id
    WHERE pay.payment_date BETWEEN DATE '2017-01-01' AND DATE '2017-12-31'
),
staff_revenue AS (
    SELECT staff_id, SUM(amount) AS total_revenue
    FROM payments_2017
    GROUP BY staff_id
),
last_store AS (
    SELECT DISTINCT ON (staff_id) staff_id, store_id
    FROM payments_2017
    ORDER BY staff_id, payment_date DESC, payment_id DESC
)
SELECT stf.first_name, stf.last_name, ls.store_id AS last_store_id, sr.total_revenue
FROM staff_revenue sr
INNER JOIN public.staff stf ON stf.staff_id = sr.staff_id
INNER JOIN last_store ls ON ls.staff_id = sr.staff_id
ORDER BY sr.total_revenue DESC
LIMIT 3;
/* Pros: Modular, clean
   Cons: Slightly verbose */



/* ============================================================
   TASK 2 – Most popular movies + expected age
   ============================================================ */

-- task 2: CTE
WITH rental_counts AS (
    SELECT inv.film_id, COUNT(rnt.rental_id) AS rentals
    FROM public.inventory inv
    INNER JOIN public.rental rnt ON inv.inventory_id = rnt.inventory_id
    GROUP BY inv.film_id
)
SELECT fil.title,
       rc.rentals,
       CASE fil.rating
           WHEN 'G' THEN 0
           WHEN 'PG' THEN 10
           WHEN 'PG-13' THEN 13
           WHEN 'R' THEN 17
           WHEN 'NC-17' THEN 18
       END AS expected_age
FROM public.film fil
INNER JOIN rental_counts rc ON fil.film_id = rc.film_id
WHERE fil.rating IN ('G', 'PG', 'PG-13', 'R', 'NC-17')
ORDER BY rc.rentals DESC, fil.title
LIMIT 5;
/* Pros: Clear and reusable
   Cons: Needs two queries joined */


-- task 2: Subquery
SELECT fil.title,
       (SELECT COUNT(rnt.rental_id)
        FROM public.inventory inv
        INNER JOIN public.rental rnt ON inv.inventory_id = rnt.inventory_id
        WHERE inv.film_id = fil.film_id) AS rentals,
       CASE fil.rating
           WHEN 'G' THEN 0
           WHEN 'PG' THEN 10
           WHEN 'PG-13' THEN 13
           WHEN 'R' THEN 17
           WHEN 'NC-17' THEN 18
       END AS expected_age
FROM public.film fil
WHERE fil.rating IN ('G', 'PG', 'PG-13', 'R', 'NC-17')
ORDER BY rentals DESC, fil.title
LIMIT 5;
/* Pros: Compact 
   Cons: Subquery runs per film (less efficient) */


-- task 2: JOIN
SELECT fil.title,
       COUNT(rnt.rental_id) AS rentals,
       CASE fil.rating
           WHEN 'G' THEN 0
           WHEN 'PG' THEN 10
           WHEN 'PG-13' THEN 13
           WHEN 'R' THEN 17
           WHEN 'NC-17' THEN 18
       END AS expected_age
FROM public.film fil
INNER JOIN public.inventory inv ON fil.film_id = inv.film_id
INNER JOIN public.rental rnt ON inv.inventory_id = rnt.inventory_id
WHERE fil.rating IN ('G', 'PG', 'PG-13', 'R', 'NC-17')
GROUP BY fil.film_id, fil.title, fil.rating
ORDER BY rentals DESC, fil.title
LIMIT 5;
/* Pros: Very fast and simple
   Cons: None here */



/* ============================================================
   PART 3 – Actor inactivity
   ============================================================ */

-- V1 CTE:
WITH last_year AS (
    SELECT act.actor_id, act.first_name, act.last_name,
           MAX(fil.release_year) AS last_release
    FROM public.actor act
    INNER JOIN public.film_actor fla ON act.actor_id = fla.actor_id
    INNER JOIN public.film fil ON fla.film_id = fil.film_id
    GROUP BY act.actor_id, act.first_name, act.last_name
)
SELECT first_name, last_name, last_release, (2025 - last_release) AS inactivity_years
FROM last_year
ORDER BY inactivity_years DESC;


-- V2 JOIN:
SELECT act.first_name, act.last_name,
       MAX(COALESCE(next_f.release_year - fil.release_year, 0)) AS max_gap
FROM public.actor act
INNER JOIN public.film_actor fla ON act.actor_id = fla.actor_id
INNER JOIN public.film fil ON fla.film_id = fil.film_id
LEFT JOIN LATERAL (
    SELECT fil2.release_year
    FROM public.film_actor fla2
    INNER JOIN public.film fil2 ON fla2.film_id = fil2.film_id
    WHERE fla2.actor_id = act.actor_id
      AND fil2.release_year > fil.release_year
    ORDER BY fil2.release_year ASC
    LIMIT 1
) AS next_f ON TRUE
GROUP BY act.actor_id, act.first_name, act.last_name
ORDER BY max_gap DESC;
