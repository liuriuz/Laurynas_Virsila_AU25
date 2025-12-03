-- TASK 1: View - sales_revenue_by_category_qtr
-- Shows sales revenue per film category for the current year & quarter.
------------------------------------------------------------
CREATE OR REPLACE VIEW public.sales_revenue_by_category_qtr AS
SELECT
    cat.name AS category,
    SUM(pay.amount) AS total_revenue
FROM public.payment       AS pay
JOIN public.rental        AS rent  ON rent.rental_id   = pay.rental_id
JOIN public.inventory     AS inv   ON inv.inventory_id = rent.inventory_id
JOIN public.film          AS film  ON film.film_id     = inv.film_id
JOIN public.film_category AS filmc ON filmc.film_id    = film.film_id
JOIN public.category      AS cat   ON cat.category_id  = filmc.category_id
WHERE EXTRACT(YEAR FROM pay.payment_date)    = EXTRACT(YEAR FROM CURRENT_DATE)
  AND EXTRACT(QUARTER FROM pay.payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE)
GROUP BY cat.name
HAVING SUM(pay.amount) > 0;

-- Example check:
-- SELECT * FROM public.sales_revenue_by_category_qtr;


-- TASK 2: Query Language Function - get_sales_revenue_by_category_qtr
-- Returns same result as the view but for a given reference date.
-- p_ref_date is optional and defaults to CURRENT_DATE.
------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_sales_revenue_by_category_qtr(
    p_ref_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (category TEXT, total_revenue NUMERIC)
LANGUAGE sql
AS $$
    SELECT
        cat.name AS category,
        SUM(pay.amount) AS total_revenue
    FROM public.payment       AS pay
    JOIN public.rental        AS rent  ON rent.rental_id   = pay.rental_id
    JOIN public.inventory     AS inv   ON inv.inventory_id = rent.inventory_id
    JOIN public.film          AS film  ON film.film_id     = inv.film_id
    JOIN public.film_category AS filmc ON filmc.film_id    = film.film_id
    JOIN public.category      AS cat   ON cat.category_id  = filmc.category_id
    WHERE EXTRACT(YEAR FROM pay.payment_date)    = EXTRACT(YEAR FROM p_ref_date)
      AND EXTRACT(QUARTER FROM pay.payment_date) = EXTRACT(QUARTER FROM p_ref_date)
    GROUP BY cat.name
    HAVING SUM(pay.amount) > 0;
$$;

-- Example usage:
-- SELECT * FROM public.get_sales_revenue_by_category_qtr();              -- current quarter
-- SELECT * FROM public.get_sales_revenue_by_category_qtr('2024-05-01');  -- quarter for given date


-- TASK 3: Procedure Function - most_popular_films_by_countries
-- Returns the most rented film per each supplied country.
-- Input: array of country names (case-insensitive).
------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.most_popular_films_by_countries(
    countries TEXT[]
)
RETURNS TABLE (
    country    TEXT,
    film_title TEXT,
    rentals    INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF countries IS NULL OR array_length(countries, 1) IS NULL THEN
        RAISE EXCEPTION 'No countries supplied';
    END IF;

    RETURN QUERY
    WITH normalized AS (
        -- Normalize input country names to uppercase.
        SELECT UPPER(unnest(countries)) AS country_upper
    ),
    country_customers AS (
        -- Map customers to countries (case-insensitive match).
        SELECT
            cust.customer_id,
            cntry.country
        FROM public.customer AS cust
        JOIN public.address  AS addr  ON addr.address_id = cust.address_id
        JOIN public.city     AS ct    ON ct.city_id      = addr.city_id
        JOIN public.country  AS cntry ON cntry.country_id = ct.country_id
        JOIN normalized      AS norm  ON UPPER(cntry.country) = norm.country_upper
    ),
    film_counts AS (
        -- Count rentals per film for each country.
        SELECT
            cc.country,
            film.title,
            COUNT(*) AS rentals
        FROM public.rental    AS rent
        JOIN public.inventory AS inv   ON inv.inventory_id = rent.inventory_id
        JOIN public.film      AS film  ON film.film_id     = inv.film_id
        JOIN country_customers AS cc   ON cc.customer_id   = rent.customer_id
        GROUP BY cc.country, film.title
    )
    SELECT DISTINCT ON (country)
        country,
        title AS film_title,
        rentals
    FROM film_counts
    ORDER BY country, rentals DESC;
END;
$$;

-- Example usage:
-- SELECT * FROM public.most_popular_films_by_countries(ARRAY['Afghanistan','Brazil','United States']);


-- TASK 4: Procedure Function - films_in_stock_by_title
-- Returns a numbered list of films that match the given title pattern
-- and currently have at least one copy in stock.
-- If no films are found, returns a single row with a message.
------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.films_in_stock_by_title(
    title_pattern TEXT
)
RETURNS TABLE (
    row_num INTEGER,
    film_id INTEGER,
    title   TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF title_pattern IS NULL THEN
        RAISE EXCEPTION 'Title pattern cannot be null';
    END IF;

    RETURN QUERY
    WITH in_stock AS (
        SELECT DISTINCT
            film.film_id,
            film.title
        FROM public.film      AS film
        JOIN public.inventory AS inv
          ON inv.film_id = film.film_id
        WHERE UPPER(film.title) LIKE UPPER(title_pattern)
          AND public.inventory_in_stock(inv.inventory_id) = TRUE
    )
    SELECT
        ROW_NUMBER() OVER (ORDER BY title) AS row_num,
        film_id,
        title
    FROM in_stock;

    -- If no data was returned, provide a user-friendly message.
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT
            1 AS row_num,
            NULL::INTEGER AS film_id,
            FORMAT('No films found in stock for pattern: %s', title_pattern) AS title;
    END IF;
END;
$$;

-- Example usage:
-- SELECT * FROM public.films_in_stock_by_title('%love%');


-- TASK 5: Procedure Function - new_movie
-- Inserts a new film into the film table with default values:
--  * rental_rate      = 4.99
--  * rental_duration  = 3 days
--  * replacement_cost = 19.99
-- Optional parameters:
--  * p_release_year  (defaults to current year)
--  * language_name   (defaults to 'Klingon')
-- Validates that the language exists and that there are no duplicates.
------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.new_movie(
    movie_title    TEXT,
    p_release_year INT  DEFAULT EXTRACT(YEAR FROM CURRENT_DATE),
    language_name  TEXT DEFAULT 'Klingon'
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    lang_id INT;
    new_id  INT;
BEGIN
    IF movie_title IS NULL THEN
        RAISE EXCEPTION 'Movie title cannot be null';
    END IF;

    -- Validate that language exists (case-insensitive match).
    SELECT language_id INTO lang_id
    FROM public.language
    WHERE UPPER(name) = UPPER(language_name);

    IF lang_id IS NULL THEN
        RAISE EXCEPTION 'Language "%" does not exist', language_name;
    END IF;

    -- Avoid inserting duplicate films with same title, language and release year.
    IF EXISTS (
        SELECT 1
        FROM public.film AS film
        WHERE UPPER(film.title) = UPPER(movie_title)
          AND film.language_id   = lang_id
          AND film.release_year  = p_release_year
    ) THEN
        RAISE EXCEPTION 'Film "%" (% / %) already exists', movie_title, language_name, p_release_year;
    END IF;

    -- Insert the new movie.
    INSERT INTO public.film (
        title,
        language_id,
        rental_duration,
        rental_rate,
        replacement_cost,
        release_year
    )
    VALUES (
        movie_title,
        lang_id,
        3,
        4.99,
        19.99,
        p_release_year
    )
    RETURNING film_id INTO new_id;

    RETURN new_id;
END;
$$;

-- Example usage:
-- SELECT public.new_movie('Example Movie');
-- SELECT public.new_movie('Sci-Fi Epic', 2025, 'English');
