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
    WHERE name = 'Animation'
)
SELECT f.title,
       f.release_year,
       f.rental_rate
FROM public.film f
INNER JOIN public.film_category fc
    ON f.film_id = fc.film_id
INNER JOIN animation_category ac
    ON fc.category_id = ac.category_id
WHERE f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
ORDER BY f.title;
/* Pros: Easy to read step by step
   Cons: Slightly longer query, not always fastest on huge data */


-- task 1: Subquery
SELECT f.title,
       f.release_year,
       f.rental_rate
FROM public.film f
INNER JOIN public.film_category fc
    ON f.film_id = fc.film_id
WHERE fc.category_id IN (
    SELECT category_id
    FROM public.category
    WHERE name = 'Animation'
)
  AND f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
ORDER BY f.title;
/* Pros: Compact and simple
   Cons: Subquery harder to reuse later */


-- task 1: JOIN
SELECT f.title,
       f.release_year,
       f.rental_rate
FROM public.film f
INNER JOIN public.film_category fc
    ON f.film_id = fc.film_id
INNER JOIN public.category c
    ON fc.category_id = c.category_id
WHERE c.name = 'Animation'
  AND f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
ORDER BY f.title;
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
    SELECT *
    FROM public.payment
    WHERE payment_date >= DATE '2017-04-01'
),
store_revenue AS (
    SELECT i.store_id, SUM(p.amount) AS revenue
    FROM public.inventory i
    INNER JOIN public.rental r
        ON i.inventory_id = r.inventory_id
    INNER JOIN payments_since_april p
        ON r.rental_id = p.rental_id
    GROUP BY i.store_id
)
SELECT CONCAT(a.address, ' ', COALESCE(a.address2, '')) AS full_address,
       sr.revenue
FROM store_revenue sr
INNER JOIN public.store s
    ON s.store_id = sr.store_id
INNER JOIN public.address a
    ON a.address_id = s.address_id
ORDER BY full_address;
/* Pros: Very readable, easy to test each CTE
   Cons: A bit verbose */


-- task 2: Subquery
SELECT CONCAT(a.address, ' ', COALESCE(a.address2, '')) AS full_address,
       sr.revenue
FROM (
    SELECT i.store_id, SUM(p.amount) AS revenue
    FROM public.inventory i
    INNER JOIN public.rental r ON i.inventory_id = r.inventory_id
    INNER JOIN public.payment p ON r.rental_id = p.rental_id
    WHERE p.payment_date >= DATE '2017-04-01'
    GROUP BY i.store_id
) AS sr
INNER JOIN public.store s ON s.store_id = sr.store_id
INNER JOIN public.address a ON a.address_id = s.address_id
ORDER BY full_address;
/* Pros: Compact and efficient
   Cons: Subquery not reusable */


-- task 2: JOIN
SELECT CONCAT(a.address, ' ', COALESCE(a.address2, '')) AS full_address,
       SUM(p.amount) AS revenue
FROM public.store s
INNER JOIN public.address a ON a.address_id = s.address_id
INNER JOIN public.inventory i ON i.store_id = s.store_id
INNER JOIN public.rental r ON r.inventory_id = i.inventory_id
INNER JOIN public.payment p ON p.rental_id = r.rental_id
WHERE p.payment_date >= DATE '2017-04-01'
GROUP BY CONCAT(a.address, ' ', COALESCE(a.address2, ''))
ORDER BY full_address;
/* Pros: Fastest and simplest
   Cons: Harder to isolate steps for debugging */



/* ============================================================
   TASK 3
   Goal:
     The marketing department in our stores aims to identify 
     the most successful actors since 2015 to boost customer 
     interest in their films. Show top-5 actors by number of 
     movies (released after 2015) they took part in 
     (columns: first_name, last_name, number_of_movies, sorted by number_of_movies in descending order)
   ============================================================ */


-- task 3 CTE:
WITH recent_films AS (
    SELECT film_id
    FROM public.film
    WHERE release_year > 2015
),
actor_counts AS (
    SELECT a.actor_id,
           a.first_name,
           a.last_name,
           COUNT(DISTINCT fa.film_id) AS num_movies
    FROM public.actor a
    INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
    INNER JOIN recent_films rf ON rf.film_id = fa.film_id
    GROUP BY a.actor_id, a.first_name, a.last_name
)
SELECT first_name, last_name, num_movies
FROM actor_counts
ORDER BY num_movies DESC, last_name, first_name
LIMIT 5;
/* Pros: Easy to follow and modular
   Cons: Slightly longer */


-- task 3 Subquery:
SELECT a.first_name,
       a.last_name,
       (
         SELECT COUNT(DISTINCT fa.film_id)
         FROM public.film_actor fa
         INNER JOIN public.film f ON fa.film_id = f.film_id
         WHERE fa.actor_id = a.actor_id
           AND f.release_year > 2015
       ) AS num_movies
FROM public.actor a
ORDER BY num_movies DESC, last_name, first_name
LIMIT 5;
/* Pros: Very short
   Cons: May run slower on huge datasets */


-- task 3 JOIN:
SELECT a.first_name,
       a.last_name,
       COUNT(DISTINCT f.film_id) AS num_movies
FROM public.actor a
INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
INNER JOIN public.film f ON fa.film_id = f.film_id
WHERE f.release_year > 2015
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY num_movies DESC, last_name, first_name
LIMIT 5;
/* Pros: Clean and fast
   Cons: None for this case */



/* ============================================================
   TASK 4
   Goal:
     The marketing team needs to track the production trends of 
     Drama, Travel, and Documentary films to inform genre-specific 
     marketing strategies. Ырщц number of Drama, Travel, Documentary 
     per year (include columns: release_year, number_of_drama_movies, 
     number_of_travel_movies, number_of_documentary_movies), 
     sorted by release year in descending order. 
     Dealing with NULL values is encouraged)
   ============================================================ */


-- task 4 CTE:
WITH film_with_category AS (
    SELECT f.release_year, c.name AS category_name
    FROM public.film f
    INNER JOIN public.film_category fc ON f.film_id = fc.film_id
    INNER JOIN public.category c ON fc.category_id = c.category_id
    WHERE c.name IN ('Drama', 'Travel', 'Documentary')
)
SELECT release_year,
       SUM(CASE WHEN category_name = 'Drama' THEN 1 ELSE 0 END) AS num_drama,
       SUM(CASE WHEN category_name = 'Travel' THEN 1 ELSE 0 END) AS num_travel,
       SUM(CASE WHEN category_name = 'Documentary' THEN 1 ELSE 0 END) AS num_documentary
FROM film_with_category
GROUP BY release_year
ORDER BY release_year DESC;
/* Pros: Very clear and easy to read
   Cons: Similar speed to direct join */


-- task 4 Subquery:
SELECT 
    f.release_year,
    COALESCE((
        SELECT COUNT(DISTINCT f1.film_id)
        FROM public.film AS f1
        INNER JOIN public.film_category AS fc1 ON f1.film_id = fc1.film_id
        INNER JOIN public.category AS c1 ON fc1.category_id = c1.category_id
        WHERE c1.name = 'Drama'
          AND f1.release_year = f.release_year
    ), 0) AS num_drama,
    COALESCE((
        SELECT COUNT(DISTINCT f2.film_id)
        FROM public.film AS f2
        INNER JOIN public.film_category AS fc2 ON f2.film_id = fc2.film_id
        INNER JOIN public.category AS c2 ON fc2.category_id = c2.category_id
        WHERE c2.name = 'Travel'
          AND f2.release_year = f.release_year
    ), 0) AS num_travel,
    COALESCE((
        SELECT COUNT(DISTINCT f3.film_id)
        FROM public.film AS f3
        INNER JOIN public.film_category AS fc3 ON f3.film_id = fc3.film_id
        INNER JOIN public.category AS c3 ON fc3.category_id = c3.category_id
        WHERE c3.name = 'Documentary'
          AND f3.release_year = f.release_year
    ), 0) AS num_documentary
FROM public.film f
GROUP BY f.release_year
ORDER BY f.release_year DESC;

/* Pros: Works fine, but not optimal
   Cons: Repeats logic, long script */


-- task 4 JOIN:
SELECT f.release_year,
       SUM(CASE WHEN c.name = 'Drama' THEN 1 ELSE 0 END) AS num_drama,
       SUM(CASE WHEN c.name = 'Travel' THEN 1 ELSE 0 END) AS num_travel,
       SUM(CASE WHEN c.name = 'Documentary' THEN 1 ELSE 0 END) AS num_documentary
FROM public.film f
INNER JOIN public.film_category fc ON f.film_id = fc.film_id
INNER JOIN public.category c ON fc.category_id = c.category_id
WHERE c.name IN ('Drama', 'Travel', 'Documentary')
GROUP BY f.release_year
ORDER BY f.release_year DESC;
/* Pros: Fastest, cleanest solution
   Cons: None really */

/* ============================================================
   PART 2
   TASK 1
   The HR department aims to reward top-performing employees in 2017 
   with bonuses to recognize their contribution to stores revenue. 
   Show which three employees generated the most revenue in 2017? 

	Assumptions: 
	staff could work in several stores in a year, please indicate 
	which store the staff worked in (the last one);
	if staff processed the payment then he works in the same store; 
	take into account only payment_date


   ============================================================ */


-- task 1 CTE:
WITH payments_2017 AS (
    SELECT 
        p.payment_id,
        p.staff_id,
        p.amount,
        p.payment_date,
        i.store_id
    FROM public.payment p
    INNER JOIN public.rental r
        ON p.rental_id = r.rental_id
    INNER JOIN public.inventory i
        ON r.inventory_id = i.inventory_id
    WHERE p.payment_date BETWEEN DATE '2017-01-01' AND DATE '2017-12-31'
),
staff_revenue AS (
    SELECT staff_id, SUM(amount) AS total_revenue
    FROM payments_2017
    GROUP BY staff_id
),
last_store AS (
    SELECT DISTINCT ON (staff_id)
        staff_id,
        store_id
    FROM payments_2017
    ORDER BY staff_id, payment_date DESC, payment_id DESC
)
SELECT 
    s.first_name,
    s.last_name,
    ls.store_id AS last_store_id,
    sr.total_revenue
FROM staff_revenue AS sr
INNER JOIN public.staff AS s
    ON s.staff_id = sr.staff_id
INNER JOIN last_store AS ls
    ON ls.staff_id = sr.staff_id
ORDER BY sr.total_revenue DESC
LIMIT 3;
/* Pros: Modular and easy to debug
   Cons: More code than needed for small data */


-- task 1 Subquery:
SELECT 
    s.first_name,
    s.last_name,
    (
        SELECT i.store_id
        FROM public.payment p
        INNER JOIN public.rental r ON p.rental_id = r.rental_id
        INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
        WHERE p.staff_id = s.staff_id
          AND p.payment_date BETWEEN DATE '2017-01-01' AND DATE '2017-12-31'
        ORDER BY p.payment_date DESC, p.payment_id DESC
        LIMIT 1
    ) AS last_store_id,
    (
        SELECT SUM(p.amount)
        FROM public.payment p
        WHERE p.staff_id = s.staff_id
          AND p.payment_date BETWEEN DATE '2017-01-01' AND DATE '2017-12-31'
    ) AS total_revenue
FROM public.staff AS s
WHERE (
    SELECT SUM(p.amount)
    FROM public.payment p
    WHERE p.staff_id = s.staff_id
      AND p.payment_date BETWEEN DATE '2017-01-01' AND DATE '2017-12-31'
) IS NOT NULL
ORDER BY total_revenue DESC
LIMIT 3;
/* Pros: Compact, very readable
   Cons: Not best for huge datasets */


-- task 1 JOIN:
SELECT 
    s.first_name,
    s.last_name,
    ls.store_id AS last_store_id,
    SUM(p.amount) AS total_revenue
FROM public.staff s
INNER JOIN public.payment p
    ON s.staff_id = p.staff_id
    AND p.payment_date BETWEEN DATE '2017-01-01' AND DATE '2017-12-31'
INNER JOIN public.rental r
    ON r.rental_id = p.rental_id
INNER JOIN public.inventory i
    ON i.inventory_id = r.inventory_id
INNER JOIN LATERAL (
    SELECT i2.store_id
    FROM public.payment AS p2
    INNER JOIN public.rental AS r2 ON p2.rental_id = r2.rental_id
    INNER JOIN public.inventory AS i2 ON r2.inventory_id = i2.inventory_id
    WHERE p2.staff_id = s.staff_id
      AND p2.payment_date BETWEEN DATE '2017-01-01' AND DATE '2017-12-31'
    ORDER BY p2.payment_date DESC, p2.payment_id DESC
    LIMIT 1
) AS ls ON TRUE
GROUP BY s.staff_id, s.first_name, s.last_name, ls.store_id
ORDER BY SUM(p.amount) DESC
LIMIT 3;
/* Pros: Simple and efficient
   Cons: No modular separation */



/* ============================================================
   TASK 2
   The management team wants to identify the most popular movies 
   and their target audience age groups to optimize marketing efforts. 
   Show which 5 movies were rented more than others (number of rentals), 
   and what's the expected age of the audience for these movies? 
   To determine expected age please use 
   'Motion Picture Association film rating system'
   ============================================================ */


-- task 2 CTE:
WITH rental_counts AS (
    SELECT i.film_id, COUNT(r.rental_id) AS rentals
    FROM public.inventory i
    INNER JOIN public.rental r ON i.inventory_id = r.inventory_id
    GROUP BY i.film_id
)
SELECT f.title, rc.rentals,
       CASE f.rating
           WHEN 'G' THEN 0
           WHEN 'PG' THEN 10
           WHEN 'PG-13' THEN 13
           WHEN 'R' THEN 17
           WHEN 'NC-17' THEN 18
           ELSE NULL
       END AS expected_age
FROM public.film f
INNER JOIN rental_counts rc ON f.film_id = rc.film_id
ORDER BY rc.rentals DESC, f.title
LIMIT 5;
/* Pros: Clear and reusable
   Cons: Needs two queries joined */


-- task 2 Subquery:
SELECT f.title,
       (SELECT COUNT(r.rental_id)
        FROM public.inventory i
        INNER JOIN public.rental r ON i.inventory_id = r.inventory_id
        WHERE i.film_id = f.film_id) AS rentals,
       CASE f.rating
           WHEN 'G' THEN 0
           WHEN 'PG' THEN 10
           WHEN 'PG-13' THEN 13
           WHEN 'R' THEN 17
           WHEN 'NC-17' THEN 18
           ELSE NULL
       END AS expected_age
FROM public.film f
ORDER BY rentals DESC, f.title
LIMIT 5;
/* Pros: Compact 
   Cons: Subquery runs per film (less efficient) */


-- task 2 JOIN:
SELECT f.title,
       COUNT(r.rental_id) AS rentals,
       CASE f.rating
           WHEN 'G' THEN 0
           WHEN 'PG' THEN 10
           WHEN 'PG-13' THEN 13
           WHEN 'R' THEN 17
           WHEN 'NC-17' THEN 18
           ELSE NULL
       END AS expected_age
FROM public.film f
INNER JOIN public.inventory i ON f.film_id = i.film_id
INNER JOIN public.rental r ON i.inventory_id = r.inventory_id
GROUP BY f.film_id, f.title, f.rating
ORDER BY rentals DESC, f.title
LIMIT 5;
/* Pros: Very fast and simple
   Cons: None here */


/* ============================================================
   PART 3
   
   The stores’ marketing team wants to analyze actors' inactivity 
   periods to select those with notable career breaks for targeted 
   promotional campaigns, highlighting their comebacks or consistent 
   appearances to engage customers with nostalgic or reliable film stars

	The task can be interpreted in various ways, and here are a few options (provide solutions for each one):
	V1: gap between the latest release_year and current year per each actor;
	V2: gaps between sequential films per each actor;


   ============================================================ */


-- V1 CTE:
WITH last_year AS (
    SELECT a.actor_id, a.first_name, a.last_name,
           MAX(f.release_year) AS last_release
    FROM public.actor a
    INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
    INNER JOIN public.film f ON fa.film_id = f.film_id
    GROUP BY a.actor_id, a.first_name, a.last_name
)
SELECT first_name, last_name,
       last_release,
       (2025 - last_release) AS inactivity_years
FROM last_year
ORDER BY inactivity_years DESC;
/* Pros: Clean and modular
   Cons: Slightly longer */


-- V1 Subquery:
SELECT a.first_name, a.last_name,
       (SELECT MAX(f.release_year)
        FROM public.film_actor fa
        INNER JOIN public.film f ON fa.film_id = f.film_id
        WHERE fa.actor_id = a.actor_id) AS last_release,
       (2025 - (
         SELECT MAX(f.release_year)
         FROM public.film_actor fa
         INNER JOIN public.film f ON fa.film_id = f.film_id
         WHERE fa.actor_id = a.actor_id
       )) AS inactivity_years
FROM public.actor a
ORDER BY inactivity_years DESC;
/* Pros: Simple to understand
   Cons: Repeats subquery, less efficient */


-- V1 JOIN:
SELECT a.first_name, a.last_name,
       MAX(f.release_year) AS last_release,
       (2025 - MAX(f.release_year)) AS inactivity_years
FROM public.actor a
INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
INNER JOIN public.film f ON fa.film_id = f.film_id
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY inactivity_years DESC;
/* Pros: Fast and simple
   Cons: No separate sub-step debugging */


-- V2 CTE:
WITH actor_years AS (
    SELECT DISTINCT a.actor_id, a.first_name, a.last_name, f.release_year
    FROM public.actor a
    INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
    INNER JOIN public.film f ON fa.film_id = f.film_id
),
year_gaps AS (
    SELECT ay.actor_id, ay.first_name, ay.last_name, ay.release_year,
           (SELECT MIN(f2.release_year)
            FROM public.film_actor fa2
            INNER JOIN public.film f2 ON fa2.film_id = f2.film_id
            WHERE fa2.actor_id = ay.actor_id
              AND f2.release_year > ay.release_year) AS next_year
    FROM actor_years ay
)
SELECT first_name, last_name,
       MAX(CASE WHEN next_year IS NOT NULL THEN next_year - release_year ELSE 0 END) AS max_gap
FROM year_gaps
GROUP BY actor_id, first_name, last_name
ORDER BY max_gap DESC;
/* Pros: Step-by-step, easy to debug
   Cons: Slightly slower because of subquery per actor/year */


-- V2 Subquery:
SELECT a.first_name, a.last_name,
       MAX(COALESCE(
           (SELECT MIN(f2.release_year) - f.release_year
            FROM public.film_actor fa2
            INNER JOIN public.film f2 ON fa2.film_id = f2.film_id
            WHERE fa2.actor_id = a.actor_id
              AND f2.release_year > f.release_year),
           0)) AS max_gap
FROM public.actor a
INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
INNER JOIN public.film f ON fa.film_id = f.film_id
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY max_gap DESC;
/* Pros: One single query
   Cons: Subquery per film row (slower on large DB) */


-- V2 JOIN:
SELECT 
    a.first_name,
    a.last_name,
    MAX(COALESCE(next_f.release_year - f.release_year, 0)) AS max_gap
FROM public.actor AS a
INNER JOIN public.film_actor AS fa
    ON a.actor_id = fa.actor_id
INNER JOIN public.film AS f
    ON fa.film_id = f.film_id
LEFT JOIN LATERAL (
    SELECT f2.release_year
    FROM public.film_actor AS fa2
    INNER JOIN public.film AS f2
        ON fa2.film_id = f2.film_id
    WHERE fa2.actor_id = a.actor_id
      AND f2.release_year > f.release_year
    ORDER BY f2.release_year ASC
    LIMIT 1
) AS next_f ON TRUE
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY max_gap DESC;
/* Pros: Beginner-friendly join logic
   Cons: May repeat rows without DISTINCT filtering */
