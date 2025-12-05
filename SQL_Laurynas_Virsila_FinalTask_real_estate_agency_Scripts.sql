CREATE SCHEMA IF NOT EXISTS rea;


/* ============================================================
   2. TABLES (3NF, PARENT BEFORE CHILD)
   ============================================================ */

-- Neighborhood:
--   Stores geographical areas where properties are located.
--   In 3NF: all attributes depend on neighborhood_id, no transitive deps.
CREATE TABLE IF NOT EXISTS rea.neighborhood (
    neighborhood_id      BIGSERIAL    PRIMARY KEY,
    name                 VARCHAR(100) NOT NULL,
    city                 VARCHAR(100) NOT NULL,
    country              VARCHAR(100) NOT NULL,
    postal_code_pattern  VARCHAR(20),
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_neighborhood_name_city UNIQUE (name, city)
);

-- Client:
--   Stores buyers, sellers, landlords, tenants.
--   In 3NF: no derived or repeating attributes.
CREATE TABLE IF NOT EXISTS rea.client (
    client_id    BIGSERIAL    PRIMARY KEY,
    full_name    VARCHAR(150) NOT NULL,
    email        VARCHAR(255) NOT NULL,
    phone        VARCHAR(50),
    client_type  VARCHAR(20)  NOT NULL, -- BUYER / SELLER / LANDLORD / TENANT / MIXED
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_client_email UNIQUE (email)
);

-- Agent:
--   Stores agency agents and their basic information.
CREATE TABLE IF NOT EXISTS rea.agent (
    agent_id    BIGSERIAL    PRIMARY KEY,
    full_name   VARCHAR(150) NOT NULL,
    email       VARCHAR(255) NOT NULL,
    phone       VARCHAR(50),
    hire_date   DATE         NOT NULL,
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_agent_email UNIQUE (email)
);

-- Property:
--   Stores information about each real estate unit.
--   3NF: attributes describe only the property, no derivable aggregates.
CREATE TABLE IF NOT EXISTS rea.property (
    property_id      BIGSERIAL    PRIMARY KEY,
    neighborhood_id  BIGINT       NOT NULL REFERENCES rea.neighborhood (neighborhood_id),
    external_code    VARCHAR(30)  NOT NULL, -- business identifier used by agency
    property_type    VARCHAR(30)  NOT NULL, -- HOUSE / APARTMENT / CONDO / LAND / COMMERCIAL
    bedrooms         INT          NOT NULL,
    bathrooms        NUMERIC(3,1),
    area_m2          NUMERIC(10,2),
    year_built       INT,
    street           VARCHAR(200) NOT NULL,
    city             VARCHAR(100) NOT NULL,
    zip_code         VARCHAR(20),
    list_price       NUMERIC(14,2),
    listing_status   VARCHAR(20)  NOT NULL DEFAULT 'LISTED',
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    -- Full address is derived from other attributes to avoid duplication,
    -- generated column ensures consistency.
    full_address     TEXT GENERATED ALWAYS AS (
        street || ', ' || city || ' ' || COALESCE(zip_code, '')
    ) STORED,
    CONSTRAINT uq_property_external_code UNIQUE (external_code)
);

-- Listing:
--   Represents publication of a property for sale or rent.
CREATE TABLE IF NOT EXISTS rea.listing (
    listing_id         BIGSERIAL    PRIMARY KEY,
    property_id        BIGINT       NOT NULL REFERENCES rea.property (property_id),
    seller_client_id   BIGINT       NOT NULL REFERENCES rea.client (client_id),
    listing_agent_id   BIGINT       NOT NULL REFERENCES rea.agent (agent_id),
    listing_type       VARCHAR(10)  NOT NULL, -- SALE / RENT
    listing_start_date DATE         NOT NULL,
    listing_end_date   DATE,
    asking_price       NUMERIC(14,2) NOT NULL,
    status             VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE'
);

-- Transaction:
--   Represents a completed sale or rental agreement.
CREATE TABLE IF NOT EXISTS rea.transaction (
    transaction_id    BIGSERIAL    PRIMARY KEY,
    listing_id        BIGINT       NOT NULL REFERENCES rea.listing (listing_id),
    buyer_client_id   BIGINT       REFERENCES rea.client (client_id),
    tenant_client_id  BIGINT       REFERENCES rea.client (client_id),
    transaction_type  VARCHAR(10)  NOT NULL, -- SALE / RENT
    closing_date      DATE         NOT NULL,
    final_price       NUMERIC(14,2) NOT NULL,
    -- Commission rate kept as numeric to allow different contract rates.
    commission_rate   NUMERIC(5,4) NOT NULL DEFAULT 0.0300,
    -- Commission amount is derived to avoid inconsistencies.
    commission_amount NUMERIC(14,2) GENERATED ALWAYS AS (
        ROUND(final_price * commission_rate, 2)
    ) STORED,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Commission Payment:
--   Tracks actual payouts to agents, derived from transactions.
CREATE TABLE IF NOT EXISTS rea.commission_payment (
    commission_payment_id BIGSERIAL    PRIMARY KEY,
    transaction_id        BIGINT       NOT NULL REFERENCES rea.transaction (transaction_id),
    agent_id              BIGINT       NOT NULL REFERENCES rea.agent (agent_id),
    payment_date          DATE         NOT NULL,
    amount                NUMERIC(14,2) NOT NULL,
    -- Unique ensures same agent is not paid twice per transaction.
    CONSTRAINT uq_commission_transaction_agent UNIQUE (transaction_id, agent_id)
);

-- Market Data:
--   Stores aggregated market statistics per neighborhood and period.
CREATE TABLE IF NOT EXISTS rea.market_data (
    market_data_id    BIGSERIAL    PRIMARY KEY,
    neighborhood_id   BIGINT       NOT NULL REFERENCES rea.neighborhood (neighborhood_id),
    period_start      DATE         NOT NULL,
    period_end        DATE         NOT NULL,
    avg_price         NUMERIC(14,2),
    num_transactions  INT,
    -- Unique ensures one record per neighborhood per period.
    CONSTRAINT uq_market_period UNIQUE (neighborhood_id, period_start, period_end)
);

-- Client Property Interest:
--   Bridge table implementing M:N between client and property.
CREATE TABLE IF NOT EXISTS rea.client_property_interest (
    client_id     BIGINT      NOT NULL REFERENCES rea.client (client_id),
    property_id   BIGINT      NOT NULL REFERENCES rea.property (property_id),
    interest_date DATE        NOT NULL DEFAULT CURRENT_DATE,
    interest_type VARCHAR(20) NOT NULL, -- VIEW_REQUEST / OFFER / GENERAL
    PRIMARY KEY (client_id, property_id)
);


/* ============================================================
   3. CHECK CONSTRAINTS (EXPLAINED)
   ============================================================ */

-- Property list_price cannot be negative; zero or positive only.
ALTER TABLE rea.property
    ADD CONSTRAINT chk_property_list_price_positive
    CHECK (list_price IS NULL OR list_price > 0);

-- Bedrooms must be non-negative because a property cannot have negative rooms.
ALTER TABLE rea.property
    ADD CONSTRAINT chk_property_bedrooms_non_negative
    CHECK (bedrooms >= 0);

-- Restrict property types to a known controlled domain for data consistency.
ALTER TABLE rea.property
    ADD CONSTRAINT chk_property_type_valid
    CHECK (property_type IN ('HOUSE', 'APARTMENT', 'CONDO', 'LAND', 'COMMERCIAL'));

-- Client type must be one of the allowed business roles.
ALTER TABLE rea.client
    ADD CONSTRAINT chk_client_type_valid
    CHECK (client_type IN ('BUYER', 'SELLER', 'LANDLORD', 'TENANT', 'MIXED'));

-- Basic email validation: it must contain '@' somewhere after first character.
ALTER TABLE rea.client
    ADD CONSTRAINT chk_client_email_format
    CHECK (POSITION('@' IN email) > 1);

-- Transaction closing date must be from 2024-01-01 to ensure "recent" data for the project.
ALTER TABLE rea.transaction
    ADD CONSTRAINT chk_transaction_date_recent
    CHECK (closing_date >= DATE '2024-01-01');

-- Commission rate must be greater than 0 and not exceed 1 (100%).
ALTER TABLE rea.transaction
    ADD CONSTRAINT chk_transaction_commission_rate_range
    CHECK (commission_rate > 0 AND commission_rate <= 1);

-- Market average price cannot be negative.
ALTER TABLE rea.market_data
    ADD CONSTRAINT chk_market_avg_price_non_negative
    CHECK (avg_price IS NULL OR avg_price >= 0);

-- Number of transactions cannot be negative.
ALTER TABLE rea.market_data
    ADD CONSTRAINT chk_market_num_transactions_non_negative
    CHECK (num_transactions IS NULL OR num_transactions >= 0);

-- Market period must be valid: end date strictly after start date.
ALTER TABLE rea.market_data
    ADD CONSTRAINT chk_market_period_valid
    CHECK (period_end > period_start);


/* ============================================================
   4. DML: SAMPLE DATA 
   ============================================================ */

---------------------------------------------------------------
-- 4.1 NEIGHBORHOOD
---------------------------------------------------------------
INSERT INTO rea.neighborhood (name, city, country, postal_code_pattern)
VALUES
    ('Old Town',      'Vilnius', 'Lithuania', '0xxxx'),
    ('New Riverside', 'Vilnius', 'Lithuania', '0xxxx'),
    ('City Center',   'Kaunas',  'Lithuania', '4xxxx'),
    ('Suburbs East',  'Vilnius', 'Lithuania', '0xxxx'),
    ('Suburbs West',  'Kaunas',  'Lithuania', '4xxxx'),
    ('Lake District', 'Trakai',  'Lithuania', '2xxxx');

---------------------------------------------------------------
-- 4.2 CLIENT
---------------------------------------------------------------
INSERT INTO rea.client (full_name, email, phone, client_type)
VALUES
    ('Jonas Buyer',      'jonas.buyer@example.com',      '+37060000001', 'BUYER'),
    ('Ona Seller',       'ona.seller@example.com',       '+37060000002', 'SELLER'),
    ('Petras Landlord',  'petras.landlord@example.com',  '+37060000003', 'LANDLORD'),
    ('Ieva Tenant',      'ieva.tenant@example.com',      '+37060000004', 'TENANT'),
    ('Mantas Investor',  'mantas.investor@example.com',  '+37060000005', 'MIXED'),
    ('Agne Buyer',       'agne.buyer@example.com',       '+37060000006', 'BUYER');

---------------------------------------------------------------
-- 4.3 AGENT
---------------------------------------------------------------
INSERT INTO rea.agent (full_name, email, phone, hire_date)
VALUES
    ('Laura Agent',    'laura.agent@example.com',    '+37061111111', CURRENT_DATE - INTERVAL '2 years'),
    ('Tomas Agent',    'tomas.agent@example.com',    '+37062222222', CURRENT_DATE - INTERVAL '1 year'),
    ('Greta Agent',    'greta.agent@example.com',    '+37063333333', CURRENT_DATE - INTERVAL '6 months'),
    ('Rasa Agent',     'rasa.agent@example.com',     '+37064444444', CURRENT_DATE - INTERVAL '3 years'),
    ('Dainius Agent',  'dainius.agent@example.com',  '+37065555555', CURRENT_DATE - INTERVAL '18 months'),
    ('Karolis Agent',  'karolis.agent@example.com',  '+37066666666', CURRENT_DATE - INTERVAL '9 months');

---------------------------------------------------------------
-- 4.4 PROPERTY
---------------------------------------------------------------
INSERT INTO rea.property (
    neighborhood_id,
    external_code,
    property_type,
    bedrooms,
    bathrooms,
    area_m2,
    year_built,
    street,
    city,
    zip_code,
    list_price,
    listing_status
)
VALUES
    (
        (SELECT nbr.neighborhood_id
         FROM rea.neighborhood AS nbr
         WHERE nbr.name = 'Old Town' AND nbr.city = 'Vilnius'),
        'VT-OT-APT-001',
        'APARTMENT',
        2,
        1.0,
        55.0,
        1950,
        'Pilies g. 10',
        'Vilnius',
        '01123',
        180000,
        'LISTED'
    ),
    (
        (SELECT nbr.neighborhood_id
         FROM rea.neighborhood AS nbr
         WHERE nbr.name = 'New Riverside' AND nbr.city = 'Vilnius'),
        'VT-NR-HSE-001',
        'HOUSE',
        4,
        2.0,
        140.0,
        2005,
        'Upes g. 5',
        'Vilnius',
        '08200',
        320000,
        'LISTED'
    ),
    (
        (SELECT nbr.neighborhood_id
         FROM rea.neighborhood AS nbr
         WHERE nbr.name = 'City Center' AND nbr.city = 'Kaunas'),
        'KN-CC-APT-001',
        'APARTMENT',
        3,
        1.5,
        80.0,
        1990,
        'Laisves al. 25',
        'Kaunas',
        '44250',
        210000,
        'LISTED'
    ),
    (
        (SELECT nbr.neighborhood_id
         FROM rea.neighborhood AS nbr
         WHERE nbr.name = 'Suburbs East' AND nbr.city = 'Vilnius'),
        'VT-SE-HSE-001',
        'HOUSE',
        3,
        2.0,
        120.0,
        2015,
        'Rytu g. 7',
        'Vilnius',
        '08400',
        260000,
        'LISTED'
    ),
    (
        (SELECT nbr.neighborhood_id
         FROM rea.neighborhood AS nbr
         WHERE nbr.name = 'Suburbs West' AND nbr.city = 'Kaunas'),
        'KN-SW-HSE-001',
        'HOUSE',
        5,
        3.0,
        180.0,
        2010,
        'Vakaru g. 3',
        'Kaunas',
        '44500',
        350000,
        'LISTED'
    ),
    (
        (SELECT nbr.neighborhood_id
         FROM rea.neighborhood AS nbr
         WHERE nbr.name = 'Lake District' AND nbr.city = 'Trakai'),
        'TR-LD-COTT-001',
        'HOUSE',
        2,
        1.0,
        70.0,
        2008,
        'Ezero g. 1',
        'Trakai',
        '21100',
        190000,
        'LISTED'
    );

---------------------------------------------------------------
-- 4.5 LISTING
---------------------------------------------------------------
INSERT INTO rea.listing (
    property_id,
    seller_client_id,
    listing_agent_id,
    listing_type,
    listing_start_date,
    listing_end_date,
    asking_price,
    status
)
VALUES
    (
        (SELECT prop.property_id
         FROM rea.property AS prop
         WHERE prop.external_code = 'VT-OT-APT-001'),
        (SELECT cli.client_id
         FROM rea.client AS cli
         WHERE cli.email = 'ona.seller@example.com'),
        (SELECT agt.agent_id
         FROM rea.agent AS agt
         WHERE agt.email = 'laura.agent@example.com'),
        'SALE',
        CURRENT_DATE - INTERVAL '75 days',
        NULL,
        185000,
        'ACTIVE'
    ),
    (
        (SELECT prop.property_id
         FROM rea.property AS prop
         WHERE prop.external_code = 'VT-NR-HSE-001'),
        (SELECT cli.client_id
         FROM rea.client AS cli
         WHERE cli.email = 'petras.landlord@example.com'),
        (SELECT agt.agent_id
         FROM rea.agent AS agt
         WHERE agt.email = 'tomas.agent@example.com'),
        'RENT',
        CURRENT_DATE - INTERVAL '60 days',
        CURRENT_DATE - INTERVAL '30 days',
        1500,
        'UNDER_OFFER'
    ),
    (
        (SELECT prop.property_id
         FROM rea.property AS prop
         WHERE prop.external_code = 'KN-CC-APT-001'),
        (SELECT cli.client_id
         FROM rea.client AS cli
         WHERE cli.email = 'mantas.investor@example.com'),
        (SELECT agt.agent_id
         FROM rea.agent AS agt
         WHERE agt.email = 'greta.agent@example.com'),
        'SALE',
        CURRENT_DATE - INTERVAL '40 days',
        CURRENT_DATE - INTERVAL '10 days',
        215000,
        'CLOSED'
    ),
    (
        (SELECT prop.property_id
         FROM rea.property AS prop
         WHERE prop.external_code = 'VT-SE-HSE-001'),
        (SELECT cli.client_id
         FROM rea.client AS cli
         WHERE cli.email = 'petras.landlord@example.com'),
        (SELECT agt.agent_id
         FROM rea.agent AS agt
         WHERE agt.email = 'rasa.agent@example.com'),
        'RENT',
        CURRENT_DATE - INTERVAL '50 days',
        NULL,
        1200,
        'ACTIVE'
    ),
    (
        (SELECT prop.property_id
         FROM rea.property AS prop
         WHERE prop.external_code = 'KN-SW-HSE-001'),
        (SELECT cli.client_id
         FROM rea.client AS cli
         WHERE cli.email = 'mantas.investor@example.com'),
        (SELECT agt.agent_id
         FROM rea.agent AS agt
         WHERE agt.email = 'dainius.agent@example.com'),
        'SALE',
        CURRENT_DATE - INTERVAL '55 days',
        CURRENT_DATE - INTERVAL '20 days',
        355000,
        'CLOSED'
    ),
    (
        (SELECT prop.property_id
         FROM rea.property AS prop
         WHERE prop.external_code = 'TR-LD-COTT-001'),
        (SELECT cli.client_id
         FROM rea.client AS cli
         WHERE cli.email = 'petras.landlord@example.com'),
        (SELECT agt.agent_id
         FROM rea.agent AS agt
         WHERE agt.email = 'karolis.agent@example.com'),
        'RENT',
        CURRENT_DATE - INTERVAL '25 days',
        NULL,
        900,
        'ACTIVE'
    );

---------------------------------------------------------------
-- 4.6 TRANSACTION
---------------------------------------------------------------
INSERT INTO rea.transaction (
    listing_id,
    buyer_client_id,
    tenant_client_id,
    transaction_type,
    closing_date,
    final_price,
    commission_rate
)
VALUES
    -- Sale of KN-CC-APT-001
    (
        (SELECT lst.listing_id
         FROM rea.listing AS lst
         JOIN rea.property AS prop
             ON prop.property_id = lst.property_id
         WHERE prop.external_code = 'KN-CC-APT-001'
         ORDER BY lst.listing_start_date DESC
         LIMIT 1),
        (SELECT cli.client_id
         FROM rea.client AS cli
         WHERE cli.email = 'jonas.buyer@example.com'),
        NULL,
        'SALE',
        CURRENT_DATE - INTERVAL '8 days',
        212000,
        0.0300
    ),
    -- Rent of VT-NR-HSE-001
    (
        (SELECT lst.listing_id
         FROM rea.listing AS lst
         JOIN rea.property AS prop
             ON prop.property_id = lst.property_id
         WHERE prop.external_code = 'VT-NR-HSE-001'
         ORDER BY lst.listing_start_date DESC
         LIMIT 1),
        NULL,
        (SELECT cli.client_id
         FROM rea.client AS cli
         WHERE cli.email = 'ieva.tenant@example.com'),
        'RENT',
        CURRENT_DATE - INTERVAL '25 days',
        1500,
        0.0500
    ),
    -- Sale of KN-SW-HSE-001
    (
        (SELECT lst.listing_id
         FROM rea.listing AS lst
         JOIN rea.property AS prop
             ON prop.property_id = lst.property_id
         WHERE prop.external_code = 'KN-SW-HSE-001'
         ORDER BY lst.listing_start_date DESC
         LIMIT 1),
        (SELECT cli.client_id
         FROM rea.client AS cli
         WHERE cli.email = 'agne.buyer@example.com'),
        NULL,
        'SALE',
        CURRENT_DATE - INTERVAL '18 days',
        348000,
        0.0250
    ),
    -- Rent of TR-LD-COTT-001
    (
        (SELECT lst.listing_id
         FROM rea.listing AS lst
         JOIN rea.property AS prop
             ON prop.property_id = lst.property_id
         WHERE prop.external_code = 'TR-LD-COTT-001'
         ORDER BY lst.listing_start_date DESC
         LIMIT 1),
        NULL,
        (SELECT cli.client_id
         FROM rea.client AS cli
         WHERE cli.email = 'jonas.buyer@example.com'),
        'RENT',
        CURRENT_DATE - INTERVAL '10 days',
        950,
        0.0500
    ),
    -- Rent renewal of VT-SE-HSE-001
    (
        (SELECT lst.listing_id
         FROM rea.listing AS lst
         JOIN rea.property AS prop
             ON prop.property_id = lst.property_id
         WHERE prop.external_code = 'VT-SE-HSE-001'
         ORDER BY lst.listing_start_date DESC
         LIMIT 1),
        NULL,
        (SELECT cli.client_id
         FROM rea.client AS cli
         WHERE cli.email = 'ieva.tenant@example.com'),
        'RENT',
        CURRENT_DATE - INTERVAL '5 days',
        1200,
        0.0450
    ),
    -- Sale of VT-OT-APT-001
    (
        (SELECT lst.listing_id
         FROM rea.listing AS lst
         JOIN rea.property AS prop
             ON prop.property_id = lst.property_id
         WHERE prop.external_code = 'VT-OT-APT-001'
         ORDER BY lst.listing_start_date DESC
         LIMIT 1),
        (SELECT cli.client_id
         FROM rea.client AS cli
         WHERE cli.email = 'mantas.investor@example.com'),
        NULL,
        'SALE',
        CURRENT_DATE - INTERVAL '2 days',
        182000,
        0.0300
    );

---------------------------------------------------------------
-- 4.7 COMMISSION PAYMENT
---------------------------------------------------------------
INSERT INTO rea.commission_payment (
    transaction_id,
    agent_id,
    payment_date,
    amount
)
VALUES
    (
        (SELECT tran.transaction_id
         FROM rea.transaction AS tran
         JOIN rea.listing AS lst
             ON lst.listing_id = tran.listing_id
         JOIN rea.property AS prop
             ON prop.property_id = lst.property_id
         WHERE prop.external_code = 'KN-CC-APT-001'
         ORDER BY tran.closing_date DESC
         LIMIT 1),
        (SELECT agt.agent_id
         FROM rea.agent AS agt
         WHERE agt.email = 'greta.agent@example.com'),
        CURRENT_DATE - INTERVAL '5 days',
        212000 * 0.03
    ),
    (
        (SELECT tran.transaction_id
         FROM rea.transaction AS tran
         JOIN rea.listing AS lst
             ON lst.listing_id = tran.listing_id
         JOIN rea.property AS prop
             ON prop.property_id = lst.property_id
         WHERE prop.external_code = 'VT-NR-HSE-001'
         ORDER BY tran.closing_date DESC
         LIMIT 1),
        (SELECT agt.agent_id
         FROM rea.agent AS agt
         WHERE agt.email = 'tomas.agent@example.com'),
        CURRENT_DATE - INTERVAL '20 days',
        1500 * 0.05
    ),
    (
        (SELECT tran.transaction_id
         FROM rea.transaction AS tran
         JOIN rea.listing AS lst
             ON lst.listing_id = tran.listing_id
         JOIN rea.property AS prop
             ON prop.property_id = lst.property_id
         WHERE prop.external_code = 'KN-SW-HSE-001'
         ORDER BY tran.closing_date DESC
         LIMIT 1),
        (SELECT agt.agent_id
         FROM rea.agent AS agt
         WHERE agt.email = 'dainius.agent@example.com'),
        CURRENT_DATE - INTERVAL '15 days',
        348000 * 0.025
    ),
    (
        (SELECT tran.transaction_id
         FROM rea.transaction AS tran
         JOIN rea.listing AS lst
             ON lst.listing_id = tran.listing_id
         JOIN rea.property AS prop
             ON prop.property_id = lst.property_id
         WHERE prop.external_code = 'TR-LD-COTT-001'
         ORDER BY tran.closing_date DESC
         LIMIT 1),
        (SELECT agt.agent_id
         FROM rea.agent AS agt
         WHERE agt.email = 'karolis.agent@example.com'),
        CURRENT_DATE - INTERVAL '7 days',
        950 * 0.05
    ),
    (
        (SELECT tran.transaction_id
         FROM rea.transaction AS tran
         JOIN rea.listing AS lst
             ON lst.listing_id = tran.listing_id
         JOIN rea.property AS prop
             ON prop.property_id = lst.property_id
         WHERE prop.external_code = 'VT-SE-HSE-001'
         ORDER BY tran.closing_date DESC
         LIMIT 1),
        (SELECT agt.agent_id
         FROM rea.agent AS agt
         WHERE agt.email = 'rasa.agent@example.com'),
        CURRENT_DATE - INTERVAL '3 days',
        1200 * 0.045
    ),
    (
        (SELECT tran.transaction_id
         FROM rea.transaction AS tran
         JOIN rea.listing AS lst
             ON lst.listing_id = tran.listing_id
         JOIN rea.property AS prop
             ON prop.property_id = lst.property_id
         WHERE prop.external_code = 'VT-OT-APT-001'
         ORDER BY tran.closing_date DESC
         LIMIT 1),
        (SELECT agt.agent_id
         FROM rea.agent AS agt
         WHERE agt.email = 'laura.agent@example.com'),
        CURRENT_DATE - INTERVAL '1 days',
        182000 * 0.03
    );

---------------------------------------------------------------
-- 4.8 MARKET DATA
---------------------------------------------------------------
INSERT INTO rea.market_data (
    neighborhood_id,
    period_start,
    period_end,
    avg_price,
    num_transactions
)
VALUES
    (
        (SELECT nbr.neighborhood_id
         FROM rea.neighborhood AS nbr
         WHERE nbr.name = 'Old Town' AND nbr.city = 'Vilnius'),
        DATE_TRUNC('quarter', CURRENT_DATE) - INTERVAL '3 months',
        DATE_TRUNC('quarter', CURRENT_DATE),
        190000,
        12
    ),
    (
        (SELECT nbr.neighborhood_id
         FROM rea.neighborhood AS nbr
         WHERE nbr.name = 'New Riverside' AND nbr.city = 'Vilnius'),
        DATE_TRUNC('quarter', CURRENT_DATE) - INTERVAL '3 months',
        DATE_TRUNC('quarter', CURRENT_DATE),
        250000,
        7
    ),
    (
        (SELECT nbr.neighborhood_id
         FROM rea.neighborhood AS nbr
         WHERE nbr.name = 'City Center' AND nbr.city = 'Kaunas'),
        DATE_TRUNC('quarter', CURRENT_DATE) - INTERVAL '3 months',
        DATE_TRUNC('quarter', CURRENT_DATE),
        205000,
        9
    ),
    (
        (SELECT nbr.neighborhood_id
         FROM rea.neighborhood AS nbr
         WHERE nbr.name = 'Suburbs East' AND nbr.city = 'Vilnius'),
        DATE_TRUNC('quarter', CURRENT_DATE) - INTERVAL '3 months',
        DATE_TRUNC('quarter', CURRENT_DATE),
        230000,
        5
    ),
    (
        (SELECT nbr.neighborhood_id
         FROM rea.neighborhood AS nbr
         WHERE nbr.name = 'Suburbs West' AND nbr.city = 'Kaunas'),
        DATE_TRUNC('quarter', CURRENT_DATE) - INTERVAL '3 months',
        DATE_TRUNC('quarter', CURRENT_DATE),
        280000,
        4
    ),
    (
        (SELECT nbr.neighborhood_id
         FROM rea.neighborhood AS nbr
         WHERE nbr.name = 'Lake District' AND nbr.city = 'Trakai'),
        DATE_TRUNC('quarter', CURRENT_DATE) - INTERVAL '3 months',
        DATE_TRUNC('quarter', CURRENT_DATE),
        195000,
        3
    );

---------------------------------------------------------------
-- 4.9 CLIENT PROPERTY INTEREST (M:N)
---------------------------------------------------------------
INSERT INTO rea.client_property_interest (
    client_id,
    property_id,
    interest_date,
    interest_type
)
VALUES
    (
        (SELECT cli.client_id
         FROM rea.client AS cli
         WHERE cli.email = 'jonas.buyer@example.com'),
        (SELECT prop.property_id
         FROM rea.property AS prop
         WHERE prop.external_code = 'VT-OT-APT-001'),
        CURRENT_DATE - INTERVAL '15 days',
        'VIEW_REQUEST'
    ),
    (
        (SELECT cli.client_id
         FROM rea.client AS cli
         WHERE cli.email = 'agne.buyer@example.com'),
        (SELECT prop.property_id
         FROM rea.property AS prop
         WHERE prop.external_code = 'KN-CC-APT-001'),
        CURRENT_DATE - INTERVAL '12 days',
        'OFFER'
    ),
    (
        (SELECT cli.client_id
         FROM rea.client AS cli
         WHERE cli.email = 'mantas.investor@example.com'),
        (SELECT prop.property_id
         FROM rea.property AS prop
         WHERE prop.external_code = 'VT-NR-HSE-001'),
        CURRENT_DATE - INTERVAL '20 days',
        'GENERAL'
    ),
    (
        (SELECT cli.client_id
         FROM rea.client AS cli
         WHERE cli.email = 'jonas.buyer@example.com'),
        (SELECT prop.property_id
         FROM rea.property AS prop
         WHERE prop.external_code = 'KN-SW-HSE-001'),
        CURRENT_DATE - INTERVAL '18 days',
        'GENERAL'
    ),
    (
        (SELECT cli.client_id
         FROM rea.client AS cli
         WHERE cli.email = 'ieva.tenant@example.com'),
        (SELECT prop.property_id
         FROM rea.property AS prop
         WHERE prop.external_code = 'TR-LD-COTT-001'),
        CURRENT_DATE - INTERVAL '8 days',
        'VIEW_REQUEST'
    ),
    (
        (SELECT cli.client_id
         FROM rea.client AS cli
         WHERE cli.email = 'ona.seller@example.com'),
        (SELECT prop.property_id
         FROM rea.property AS prop
         WHERE prop.external_code = 'VT-SE-HSE-001'),
        CURRENT_DATE - INTERVAL '6 days',
        'GENERAL'
    );


/* ============================================================
   5. FUNCTIONS
   ============================================================ */

---------------------------------------------------------------
-- 5.1 Generic update function for PROPERTY
---------------------------------------------------------------
CREATE OR REPLACE FUNCTION rea.update_property_column (
    p_property_id   BIGINT,
    p_column_name   TEXT,
    p_new_value     TEXT
)
RETURNS VOID
LANGUAGE plpgsql
AS
$$
BEGIN
    -- Dynamic SQL used to allow arbitrary column name update.
    EXECUTE FORMAT(
        'UPDATE rea.property SET %I = $1 WHERE property_id = $2',
        p_column_name
    )
    USING p_new_value, p_property_id;

    RAISE NOTICE 'Property % updated: % = %',
        p_property_id, p_column_name, p_new_value;
END;
$$;

-- Example call:
-- SELECT rea.update_property_column(1, 'listing_status', 'SOLD');


---------------------------------------------------------------
-- 5.2 Function to add a new transaction
---------------------------------------------------------------
CREATE OR REPLACE FUNCTION rea.add_transaction (
    p_property_external_code TEXT,
    p_buyer_email            TEXT,
    p_tenant_email           TEXT,
    p_transaction_type       TEXT,   -- 'SALE' or 'RENT'
    p_closing_date           DATE,
    p_final_price            NUMERIC,
    p_commission_rate        NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql
AS
$$
DECLARE
    found_listing_id BIGINT;
    found_buyer_id   BIGINT;
    found_tenant_id  BIGINT;
BEGIN
    -- Use most recent listing for the given property external code.
    SELECT lst.listing_id
    INTO found_listing_id
    FROM rea.listing AS lst
    JOIN rea.property AS prop
        ON prop.property_id = lst.property_id
    WHERE prop.external_code = p_property_external_code
    ORDER BY lst.listing_start_date DESC
    LIMIT 1;

    IF found_listing_id IS NULL THEN
        RAISE EXCEPTION 'Listing not found for property external_code = %', p_property_external_code;
    END IF;

    IF p_buyer_email IS NOT NULL THEN
        SELECT cli.client_id
        INTO found_buyer_id
        FROM rea.client AS cli
        WHERE cli.email = p_buyer_email;
    END IF;

    IF p_tenant_email IS NOT NULL THEN
        SELECT cli.client_id
        INTO found_tenant_id
        FROM rea.client AS cli
        WHERE cli.email = p_tenant_email;
    END IF;

    INSERT INTO rea.transaction (
        listing_id,
        buyer_client_id,
        tenant_client_id,
        transaction_type,
        closing_date,
        final_price,
        commission_rate
    )
    VALUES (
        found_listing_id,
        found_buyer_id,
        found_tenant_id,
        p_transaction_type,
        p_closing_date,
        p_final_price,
        p_commission_rate
    );

    RAISE NOTICE 'New transaction inserted for property external_code = % on %',
        p_property_external_code, p_closing_date;
END;
$$;

-- Example:
-- SELECT rea.add_transaction(
--     p_property_external_code => 'VT-OT-APT-001',
--     p_buyer_email            => 'jonas.buyer@example.com',
--     p_tenant_email           => NULL,
--     p_transaction_type       => 'SALE',
--     p_closing_date           => CURRENT_DATE,
--     p_final_price            => 190000,
--     p_commission_rate        => 0.03
-- );


/* ============================================================
   6. ANALYTICS VIEW FOR MOST RECENT QUARTER
   ============================================================ */

-- View presents analytics for the most recent quarter:
--   - Excludes surrogate keys
--   - Aggregates by city, neighborhood, property_type, agent
--   - Uses only business fields useful for manager reporting.
CREATE OR REPLACE VIEW rea.v_quarterly_sales_analytics AS
WITH latest_quarter AS (
    SELECT DATE_TRUNC('quarter', MAX(tran.closing_date)) AS quarter_start
    FROM rea.transaction AS tran
),
transaction_data AS (
    SELECT
        DATE_TRUNC('quarter', tran.closing_date) AS quarter_start,
        nbr.city                                AS city,
        nbr.name                                AS neighborhood_name,
        prop.property_type                      AS property_type,
        agt.full_name                           AS agent_name,
        tran.final_price                        AS final_price
    FROM rea.transaction AS tran
    JOIN rea.listing AS lst
        ON lst.listing_id = tran.listing_id
    JOIN rea.property AS prop
        ON prop.property_id = lst.property_id
    JOIN rea.neighborhood AS nbr
        ON nbr.neighborhood_id = prop.neighborhood_id
    JOIN rea.agent AS agt
        ON agt.agent_id = lst.listing_agent_id
)
SELECT
    transaction_data.quarter_start::DATE      AS quarter_start,
    transaction_data.city                     AS city,
    transaction_data.neighborhood_name        AS neighborhood_name,
    transaction_data.property_type            AS property_type,
    transaction_data.agent_name               AS agent_name,
    COUNT(*)                                  AS deals_count,
    SUM(transaction_data.final_price)         AS total_volume,
    AVG(transaction_data.final_price)         AS average_price
FROM transaction_data
JOIN latest_quarter AS lq
    ON lq.quarter_start = transaction_data.quarter_start
GROUP BY
    transaction_data.quarter_start,
    transaction_data.city,
    transaction_data.neighborhood_name,
    transaction_data.property_type,
    transaction_data.agent_name;


/* ============================================================
   7. READ-ONLY ROLE FOR MANAGER
   ============================================================ */

-- Role for manager:
--   - Can log in
--   - Has SELECT on all tables in schema rea
--   - No write permissions
CREATE ROLE manager_ro LOGIN PASSWORD 'ChangeMe_StrongPassword1';

-- NOTE: Replace 'real_estate_agency' with actual database name if different.
-- This grant gives the manager role permission to connect to the database.
GRANT CONNECT ON DATABASE real_estate_agency TO manager_ro;

-- Allow usage of schema rea.
GRANT USAGE ON SCHEMA rea TO manager_ro;

-- Allow read-only access to all current tables in schema rea.
GRANT SELECT ON ALL TABLES IN SCHEMA rea TO manager_ro;

-- Ensure future tables in schema rea are also readable by manager role.
ALTER DEFAULT PRIVILEGES IN SCHEMA rea
GRANT SELECT ON TABLES TO manager_ro;

