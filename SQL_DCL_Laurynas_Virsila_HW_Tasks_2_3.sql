-- Task 2. Implement role-based authentication model
-- 2.1 Create user rentaluser with ability to connect only

-- Step 1: create login role with password
CREATE ROLE rentaluser
    LOGIN
    PASSWORD 'rentalpassword';

-- Step 2: allow connecting to the dvd_rental database
GRANT CONNECT ON DATABASE dvd_rental TO rentaluser;

-- At this point, rentaluser can connect, but has no rights on schemas or tables.

------------------------------------------------------------
-- 2.2 Grant SELECT on customer and verify it works
------------------------------------------------------------

-- To select from tables in the public schema, the user needs USAGE on the schema
GRANT USAGE ON SCHEMA public TO rentaluser;

-- Grant SELECT on the customer table
GRANT SELECT ON TABLE public.customer TO rentaluser;

-- Test: as rentaluser, we can now read from public.customer
-- (these statements are meant to be executed after connecting as a superuser)
SET ROLE rentaluser;

-- Check that the permission works:
SELECT * FROM public.customer LIMIT 10;

RESET ROLE;

------------------------------------------------------------
-- 2.3 Create a group role rental and add rentaluser to it
------------------------------------------------------------

-- Create group role (NOLOGIN means it cannot log in directly)
CREATE ROLE rental NOLOGIN;

-- Add rentaluser as a member of rental
GRANT rental TO rentaluser;

------------------------------------------------------------
-- 2.4 Grant INSERT and UPDATE on rental table via group
--      Then insert a new row and update an existing one
------------------------------------------------------------

-- Grant group role rental the right to INSERT and UPDATE rows in public.rental
GRANT INSERT, UPDATE ON TABLE public.rental TO rental;

-- Test these privileges using rentaluser (who is member of rental)
SET ROLE rentaluser;

-- Insert a new rental row.
-- We use ids that exist in the standard dvdrental sample: inventory_id = 1, customer_id = 1, staff_id = 1.
INSERT INTO public.rental (rental_date, inventory_id, customer_id, return_date, staff_id)
VALUES (NOW(), 1, 1, NULL, 1);

-- Update an existing row (for simplicity, update the most recent rental of this customer)
UPDATE public.rental
SET return_date = NOW()
WHERE rental_id = (
    SELECT MAX(rental_id)
    FROM public.rental
    WHERE customer_id = 1
);

RESET ROLE;

------------------------------------------------------------
-- 2.5 Revoke INSERT from rental and show that insert is denied
------------------------------------------------------------

-- Revoke INSERT privilege; keep UPDATE
REVOKE INSERT ON TABLE public.rental FROM rental;

-- Test: under rentaluser, trying to insert should now fail
SET ROLE rentaluser;

-- This statement should raise: ERROR: permission denied for table rental
INSERT INTO public.rental (rental_date, inventory_id, customer_id, return_date, staff_id)
VALUES (NOW(), 1, 1, NULL, 1);

RESET ROLE;

------------------------------------------------------------
-- 2.6 Create personalized role for an existing customer
--      whose rental and payment history is not empty
------------------------------------------------------------

-- First, find a customer who has at least one rental and one payment:
-- (This is an evidence query; the actual result may vary, but in the
--  standard dvdrental sample, customer_id = 1, MARY SMITH, satisfies it.)
--
-- SELECT c.customer_id, c.first_name, c.last_name,
--        COUNT(DISTINCT r.rental_id)  AS rentals,
--        COUNT(DISTINCT p.payment_id) AS payments
-- FROM public.customer c
-- JOIN public.rental  r ON r.customer_id = c.customer_id
-- JOIN public.payment p ON p.customer_id = c.customer_id
-- GROUP BY c.customer_id, c.first_name, c.last_name
-- HAVING COUNT(DISTINCT r.rental_id)  > 0
--    AND COUNT(DISTINCT p.payment_id) > 0
-- ORDER BY rentals DESC, payments DESC
-- LIMIT 5;

-- For this homework I choose:
--   customer_id = 1
--   first_name = 'MARY'
--   last_name  = 'SMITH'
-- Role name must be: client_MARY_SMITH

CREATE ROLE client_MARY_SMITH
    LOGIN
    PASSWORD 'clientpassword';

-- Allow this client role to connect to the dvd_rental database
GRANT CONNECT ON DATABASE dvd_rental TO client_MARY_SMITH;

-- Allow usage of the public schema
GRANT USAGE ON SCHEMA public TO client_MARY_SMITH;

============================================================
-- Task 3. Implement row-level security
============================================================

-- Goal: configure client_MARY_SMITH so that she can only access
-- her own data in the rental and payment tables.

------------------------------------------------------------
-- 3.1 Enable row-level security on rental and payment
------------------------------------------------------------

ALTER TABLE public.rental  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment ENABLE ROW LEVEL SECURITY;

------------------------------------------------------------
-- 3.2 Grant SELECT on rental and payment to client role
------------------------------------------------------------

GRANT SELECT ON TABLE public.rental  TO client_MARY_SMITH;
GRANT SELECT ON TABLE public.payment TO client_MARY_SMITH;

------------------------------------------------------------
-- 3.3 Create RLS policies that restrict access to customer_id = 1
------------------------------------------------------------

-- For the rental table
CREATE POLICY rental_client_MARY_SMITH_policy
ON public.rental
FOR SELECT
TO client_MARY_SMITH
USING (customer_id = 1);   -- customer_id of MARY SMITH

-- For the payment table
CREATE POLICY payment_client_MARY_SMITH_policy
ON public.payment
FOR SELECT
TO client_MARY_SMITH
USING (customer_id = 1);   -- customer_id of MARY SMITH

------------------------------------------------------------
-- 3.4 Test that the client role only sees her own data
------------------------------------------------------------

SET ROLE client_MARY_SMITH;

-- Check that only customer_id = 1 is visible in rental
SELECT DISTINCT customer_id
FROM public.rental
ORDER BY customer_id;

-- Check that only customer_id = 1 is visible in payment
SELECT DISTINCT customer_id
FROM public.payment
ORDER BY customer_id;

-- Inspect some recent rows (they should all have customer_id = 1)
SELECT rental_id, rental_date, customer_id
FROM public.rental
ORDER BY rental_date DESC
LIMIT 10;

SELECT payment_id, amount, customer_id
FROM public.payment
ORDER BY payment_date DESC
LIMIT 10;

RESET ROLE;

-- End of SQL_DCL_Laurynas_Virsila_HW_Tasks_2_3.sql
