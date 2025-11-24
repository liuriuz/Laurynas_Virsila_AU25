-- TASK 1

CREATE OR REPLACE VIEW sales_revenue_by_category_qtr AS
WITH dt AS (
    SELECT 
        EXTRACT(YEAR FROM CURRENT_DATE)::INT AS curr_year,
        EXTRACT(QUARTER FROM CURRENT_DATE)::INT AS curr_quarter
)
SELECT 
    c.name AS category,
    SUM(p.amount) AS total_revenue
FROM payment p
JOIN rental r ON r.rental_id = p.rental_id
JOIN inventory i ON i.inventory_id = r.inventory_id
JOIN film f ON f.film_id = i.film_id
JOIN film_category fc ON fc.film_id = f.film_id
JOIN category c ON c.category_id = fc.category_id
CROSS JOIN dt
WHERE EXTRACT(YEAR FROM p.payment_date) = dt.curr_year
  AND EXTRACT(QUARTER FROM p.payment_date) = dt.curr_quarter
GROUP BY c.name
HAVING SUM(p.amount) > 0;

-- TASK 2

CREATE OR REPLACE FUNCTION get_sales_revenue_by_category_qtr(
    p_ref_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (category TEXT, total_revenue NUMERIC)
LANGUAGE sql
AS $$
    SELECT 
        c.name AS category,
        SUM(p.amount) AS total_revenue
    FROM payment p
    JOIN rental r ON r.rental_id = p.rental_id
    JOIN inventory i ON i.inventory_id = r.inventory_id
    JOIN film f ON f.film_id = i.film_id
    JOIN film_category fc ON fc.film_id = f.film_id
    JOIN category c ON c.category_id = fc.category_id
    WHERE EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM p_ref_date)
      AND EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM p_ref_date)
    GROUP BY c.name
    HAVING SUM(p.amount) > 0;
$$;

-- TASK 3

CREATE OR REPLACE FUNCTION most_popular_films_by_countries(
    countries TEXT[]
)
RETURNS TABLE (
    country TEXT,
    film_title TEXT,
    rentals INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF countries IS NULL OR array_length(countries, 1) IS NULL THEN
        RAISE EXCEPTION 'No countries supplied';
    END IF;

    RETURN QUERY
    WITH normalized AS (
        SELECT UPPER(unnest(countries)) AS country_upper
    ),
    country_customers AS (
        SELECT cu.customer_id, co.country
        FROM customer cu
        JOIN address a ON cu.address_id = a.address_id
        JOIN city ci ON a.city_id = ci.city_id
        JOIN country co ON ci.country_id = co.country_id
        JOIN normalized n ON UPPER(co.country) = n.country_upper
    ),
    film_counts AS (
        SELECT 
            cc.country,
            f.title,
            COUNT(*) AS rentals
        FROM rental r
        JOIN inventory i ON i.inventory_id = r.inventory_id
        JOIN film f ON f.film_id = i.film_id
        JOIN country_customers cc ON cc.customer_id = r.customer_id
        GROUP BY cc.country, f.title
    )
    SELECT DISTINCT ON (country)
        country, title AS film_title, rentals
    FROM film_counts
    ORDER BY country, rentals DESC;
END;
$$;

-- TASK 4

CREATE OR REPLACE FUNCTION films_in_stock_by_title(
    title_pattern TEXT
)
RETURNS TABLE (
    row_num INTEGER,
    film_id INTEGER,
    title TEXT
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
            f.film_id,
            f.title
        FROM film f
        JOIN inventory i ON i.film_id = f.film_id
        WHERE UPPER(f.title) LIKE UPPER(title_pattern)
          AND inventory_in_stock(i.inventory_id) = TRUE
    )
    SELECT 
        ROW_NUMBER() OVER (ORDER BY title),
        film_id,
        title
    FROM in_stock;

    IF NOT FOUND THEN
        RETURN QUERY
        SELECT 1,
               NULL::INTEGER,
               FORMAT('No films found in stock for pattern: %s', title_pattern);
    END IF;
END;
$$;


-- TASK 5

CREATE OR REPLACE FUNCTION new_movie(
    movie_title TEXT,
    release_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE),
    language_name TEXT DEFAULT 'Klingon'
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    lang_id INT;
    new_id INT;
BEGIN
    IF movie_title IS NULL THEN
        RAISE EXCEPTION 'Movie title cannot be null';
    END IF;

    SELECT language_id INTO lang_id
    FROM language
    WHERE UPPER(name) = UPPER(language_name);

    IF lang_id IS NULL THEN
        RAISE EXCEPTION 'Language "%" does not exist', language_name;
    END IF;

    IF EXISTS (
        SELECT 1 FROM film
        WHERE UPPER(title) = UPPER(movie_title)
          AND language_id = lang_id
          AND release_year = release_year
    ) THEN
        RAISE EXCEPTION 'Film "%" (% / %) already exists', movie_title, language_name, release_year;
    END IF;

    INSERT INTO film (
        title, language_id, rental_duration, rental_rate,
        replacement_cost, release_year
    )
    VALUES (
        movie_title, lang_id, 3, 4.99,
        19.99, release_year
    )
    RETURNING film_id INTO new_id;

    RETURN new_id;
END;
$$;
