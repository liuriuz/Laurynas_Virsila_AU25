-- Task 2. Implement role-based authentication model

------------------------------------------------------------
-- 2.1 Create user rentaluser with ability to connect only
------------------------------------------------------------

CREATE ROLE rentaluser
    LOGIN
    PASSWORD 'rentalpassword';

GRANT CONNECT ON DATABASE dvdrental TO rentaluser;


------------------------------------------------------------
-- 2.2 Grant SELECT on customer and verify it works
------------------------------------------------------------

GRANT USAGE ON SCHEMA public TO rentaluser;

GRANT SELECT (
    customer_id, store_id, first_name, last_name, email, address_id, active, create_date, last_update
) ON public.customer TO rentaluser;

SET ROLE rentaluser;

SELECT 
    customer_id,
    first_name,
    last_name,
    email
FROM public.customer
ORDER BY customer_id ASC
LIMIT 10;

RESET ROLE;


------------------------------------------------------------
-- 2.3 Create a group role rental and add rentaluser to it
------------------------------------------------------------

CREATE ROLE rental NOLOGIN;
GRANT rental TO rentaluser;


------------------------------------------------------------
-- 2.4 Grant INSERT and UPDATE on rental table via group
--      Then insert a new row and update an existing one
------------------------------------------------------------

GRANT INSERT, UPDATE ON TABLE public.rental TO rental;

GRANT USAGE ON SEQUENCE public.rental_rental_id_seq TO rental;

SET ROLE rentaluser;

INSERT INTO public.rental (
    rental_date, 
    inventory_id, 
    customer_id, 
    return_date, 
    staff_id
)
VALUES (
    NOW(),
    (SELECT MIN(inventory_id) FROM public.inventory), 
    2,
    NULL,
    (SELECT MIN(staff_id) FROM public.staff)
);

UPDATE public.rental
SET return_date = NOW()
WHERE rental_id = (
    SELECT MAX(rental_table.rental_id)
    FROM public.rental AS rental_table
    WHERE rental_table.customer_id = 2
);

RESET ROLE;


------------------------------------------------------------
-- 2.5 Revoke INSERT from rental and show that insert is denied
------------------------------------------------------------

REVOKE INSERT ON TABLE public.rental FROM rental;

SET ROLE rentaluser;

INSERT INTO public.rental (
    rental_date, inventory_id, customer_id, return_date, staff_id
)
VALUES (
    NOW(),
    (SELECT MIN(inventory_id) FROM public.inventory),
    2,
    NULL,
    (SELECT MIN(staff_id) FROM public.staff)
);

RESET ROLE;


------------------------------------------------------------
-- 2.6 Create personalized role for an existing customer
------------------------------------------------------------

CREATE ROLE client_PATRICIA_JOHNSON
    LOGIN
    PASSWORD 'clientpassword';

GRANT CONNECT ON DATABASE dvdrental TO client_PATRICIA_JOHNSON;
GRANT USAGE ON SCHEMA public TO client_PATRICIA_JOHNSON;



-- Task 3. Implement row-level security

------------------------------------------------------------
-- 3.1 Enable row-level security on rental, payment, and sale
------------------------------------------------------------

ALTER TABLE public.rental  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale    ENABLE ROW LEVEL SECURITY;


------------------------------------------------------------
-- 3.2 Grant SELECT on rental and payment to client role
------------------------------------------------------------

GRANT SELECT ON TABLE public.rental  TO client_PATRICIA_JOHNSON;
GRANT SELECT ON TABLE public.payment TO client_PATRICIA_JOHNSON;
GRANT SELECT ON TABLE public.sale    TO client_PATRICIA_JOHNSON;


------------------------------------------------------------
-- 3.3 Create RLS policies that restrict access
------------------------------------------------------------

CREATE POLICY rental_client_PATRICIA_JOHNSON_policy
ON public.rental
FOR SELECT
TO client_PATRICIA_JOHNSON
USING (customer_id = 2);

CREATE POLICY sale_client_PATRICIA_JOHNSON_policy
ON public.sale
FOR SELECT
TO client_PATRICIA_JOHNSON
USING (buyer_id = 1);

CREATE POLICY payment_client_PATRICIA_JOHNSON_policy
ON public.payment
FOR SELECT
TO client_PATRICIA_JOHNSON
USING (
    sale_id IN (
        SELECT sale_table.sale_id
        FROM public.sale AS sale_table
        WHERE sale_table.buyer_id = 1
    )
);


------------------------------------------------------------
-- 3.4 Test that the client role only sees her own data
------------------------------------------------------------

SET ROLE client_PATRICIA_JOHNSON;

SELECT DISTINCT 
    rental_table.customer_id
FROM public.rental AS rental_table
ORDER BY rental_table.customer_id ASC;

SELECT DISTINCT 
    sale_table.buyer_id
FROM public.sale AS sale_table
ORDER BY sale_table.buyer_id ASC;

SELECT 
    payment_table.payment_id,
    payment_table.sale_id,
    payment_table.payment_date,
    payment_table.payment_amount,
    payment_table.payment_method
FROM public.payment AS payment_table
WHERE payment_table.sale_id IN (
    SELECT sale_table.sale_id
    FROM public.sale AS sale_table
    WHERE sale_table.buyer_id = 1
)
ORDER BY payment_table.payment_id ASC;

RESET ROLE;
