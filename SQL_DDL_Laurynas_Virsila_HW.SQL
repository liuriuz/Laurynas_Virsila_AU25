-- 1. CREATE DATABASE

CREATE DATABASE auction_house;

-- 2. CREATE SCHEMA

CREATE SCHEMA IF NOT EXISTS auction_house_schema;
SET search_path TO auction_house_schema;

-- 3. CREATE TABLES
-- COUNTRY
CREATE TABLE country (
    country_id BIGSERIAL PRIMARY KEY,
    country_name VARCHAR(100) NOT NULL,
    CONSTRAINT uq_country_name UNIQUE (country_name)
);

-- CITY
CREATE TABLE city (
    city_id BIGSERIAL PRIMARY KEY,
    city_name VARCHAR(100) NOT NULL,
    country_id BIGINT NOT NULL,
    CONSTRAINT fk_city_country FOREIGN KEY (country_id) REFERENCES country(country_id),
    CONSTRAINT uq_city_country UNIQUE (city_name, country_id)
);

-- CATEGORY 
CREATE TABLE category (
    category_id BIGSERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    description TEXT,
    parent_category_id BIGINT,
    CONSTRAINT fk_category_parent FOREIGN KEY (parent_category_id) REFERENCES category(category_id),
    CONSTRAINT uq_category_parent UNIQUE (category_name, parent_category_id)
);

-- ADDRESS
CREATE TABLE address (
    address_id BIGSERIAL PRIMARY KEY,
    street VARCHAR(150) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    city_id BIGINT NOT NULL,
    CONSTRAINT fk_address_city FOREIGN KEY (city_id) REFERENCES city(city_id),
    CONSTRAINT uq_address UNIQUE (street, postal_code, city_id)
);


-- LOCATION
CREATE TABLE location (
    location_id BIGSERIAL PRIMARY KEY,
    location_name VARCHAR(100) NOT NULL,
    city_id BIGINT NOT NULL,
    CONSTRAINT fk_location_city FOREIGN KEY (city_id) REFERENCES city(city_id),
    CONSTRAINT uq_location_city UNIQUE (location_name, city_id)
);

-- BUYER
CREATE TABLE buyer (
    buyer_id BIGSERIAL PRIMARY KEY,
    buyer_name VARCHAR(100) NOT NULL,
    contact_number VARCHAR(30),
    email VARCHAR(120),
    address_id BIGINT NOT NULL,
    CONSTRAINT fk_buyer_address FOREIGN KEY (address_id) REFERENCES address(address_id),
    CONSTRAINT uq_buyer_email UNIQUE (email)
);

-- SELLER
CREATE TABLE seller (
    seller_id BIGSERIAL PRIMARY KEY,
    seller_name VARCHAR(100) NOT NULL,
    contact_number VARCHAR(30),
    email VARCHAR(120),
    address_id BIGINT NOT NULL,
    CONSTRAINT fk_seller_address FOREIGN KEY (address_id) REFERENCES address(address_id),
    CONSTRAINT uq_seller_email UNIQUE (email)
);

-- AUCTION
CREATE TABLE auction (
    auction_id BIGSERIAL PRIMARY KEY,
    auction_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    location_id BIGINT NOT NULL,
    category_id BIGINT NOT NULL,
    CONSTRAINT fk_auction_location FOREIGN KEY (location_id) REFERENCES location(location_id),
    CONSTRAINT fk_auction_category FOREIGN KEY (category_id) REFERENCES category(category_id),
    CONSTRAINT chk_auction_date CHECK (auction_date > DATE '2000-01-01'),
    CONSTRAINT chk_auction_time CHECK (end_time > start_time)
);

-- EMPLOYEE
CREATE TABLE employee (
    employee_id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    role VARCHAR(50),
    auction_id BIGINT,
    CONSTRAINT fk_employee_auction FOREIGN KEY (auction_id) REFERENCES auction(auction_id)
);

-- ITEM
CREATE TABLE item (
    item_id BIGSERIAL PRIMARY KEY,
    item_name VARCHAR(150) NOT NULL,
    description TEXT,
    starting_price NUMERIC(12,2) NOT NULL,
    seller_id BIGINT NOT NULL,
    category_id BIGINT NOT NULL,
    CONSTRAINT fk_item_seller FOREIGN KEY (seller_id) REFERENCES seller(seller_id),
    CONSTRAINT fk_item_category FOREIGN KEY (category_id) REFERENCES category(category_id),
    CONSTRAINT chk_item_starting_price CHECK (starting_price >= 0),
    CONSTRAINT uq_item_seller UNIQUE (item_name, seller_id)
);

-- AUCTION_ITEM
CREATE TABLE auction_item (
    auction_id BIGINT NOT NULL,
    item_id BIGINT NOT NULL,
    display_order INT NOT NULL,
    estimated_price NUMERIC(12,2),
    CONSTRAINT pk_auction_item PRIMARY KEY (auction_id, item_id),
    CONSTRAINT fk_ai_auction FOREIGN KEY (auction_id) REFERENCES auction(auction_id),
    CONSTRAINT fk_ai_item FOREIGN KEY (item_id) REFERENCES item(item_id),
    CONSTRAINT chk_estimated_price CHECK (estimated_price IS NULL OR estimated_price >= 0),
    CONSTRAINT uq_ai_display UNIQUE (auction_id, display_order)
);

-- LOT
CREATE TABLE lot (
    lot_id BIGSERIAL PRIMARY KEY,
    lot_number VARCHAR(20) NOT NULL,
    auction_id BIGINT NOT NULL,
    item_id BIGINT NOT NULL,
    lot_description TEXT,
    CONSTRAINT fk_lot_auction FOREIGN KEY (auction_id) REFERENCES auction(auction_id),
    CONSTRAINT fk_lot_item FOREIGN KEY (item_id) REFERENCES item(item_id),
    CONSTRAINT uq_lot UNIQUE (auction_id, lot_number)
);

-- BID
CREATE TABLE bid (
    bid_id BIGSERIAL PRIMARY KEY,
    lot_id BIGINT NOT NULL,
    buyer_id BIGINT NOT NULL,
    bid_amount NUMERIC(12,2) NOT NULL,
    bid_time TIMESTAMP NOT NULL,
    CONSTRAINT fk_bid_lot FOREIGN KEY (lot_id) REFERENCES lot(lot_id),
    CONSTRAINT fk_bid_buyer FOREIGN KEY (buyer_id) REFERENCES buyer(buyer_id),
    CONSTRAINT chk_bid_amount CHECK (bid_amount >= 0)
);

-- SALE
CREATE TABLE sale (
    sale_id BIGSERIAL PRIMARY KEY,
    lot_id BIGINT NOT NULL,
    buyer_id BIGINT NOT NULL,
    final_price NUMERIC(12,2) NOT NULL,
    sale_date DATE NOT NULL,
    CONSTRAINT fk_sale_lot FOREIGN KEY (lot_id) REFERENCES lot(lot_id),
    CONSTRAINT fk_sale_buyer FOREIGN KEY (buyer_id) REFERENCES buyer(buyer_id),
    CONSTRAINT chk_sale_price CHECK (final_price >= 0),
    CONSTRAINT chk_sale_date CHECK (sale_date > DATE '2000-01-01'),
    CONSTRAINT uq_sale UNIQUE (lot_id)
);

-- PAYMENT
CREATE TABLE payment (
    payment_id BIGSERIAL PRIMARY KEY,
    sale_id BIGINT NOT NULL,
    payment_date DATE NOT NULL,
    payment_amount NUMERIC(12,2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    CONSTRAINT fk_payment_sale FOREIGN KEY (sale_id) REFERENCES sale(sale_id),
    CONSTRAINT uq_payment UNIQUE (sale_id),
    CONSTRAINT chk_payment_amount CHECK (payment_amount >= 0),
    CONSTRAINT chk_payment_date CHECK (payment_date > DATE '2000-01-01'),
    CONSTRAINT chk_payment_method CHECK (payment_method IN ('CASH','CARD','TRANSFER'))
);


-- 4. ADD SAMPLE DATA
-- COUNTRY
INSERT INTO country (country_name) VALUES
('Lithuania'), ('Poland')
ON CONFLICT DO NOTHING;

-- CITY
INSERT INTO city (city_name, country_id)
VALUES
('Vilnius',(SELECT country_id FROM country WHERE country_name='Lithuania')),
('Kaunas',(SELECT country_id FROM country WHERE country_name='Lithuania')),
('Warsaw',(SELECT country_id FROM country WHERE country_name='Poland'))
ON CONFLICT DO NOTHING;

-- CATEGORY ROOT
INSERT INTO category (category_name, description, parent_category_id)
VALUES
('Art','Fine art',NULL),
('Antiques','Old objects',NULL)
ON CONFLICT DO NOTHING;

-- CATEGORY CHILDREN
INSERT INTO category (category_name, description, parent_category_id)
VALUES
('Painting','Paintings',(SELECT category_id FROM category WHERE category_name='Art' AND parent_category_id IS NULL)),
('Sculpture','Sculptures',(SELECT category_id FROM category WHERE category_name='Art' AND parent_category_id IS NULL))
ON CONFLICT DO NOTHING;

-- ADDRESS 
INSERT INTO address (street, postal_code, city_id)
VALUES
('Gedimino pr. 1','01103',(SELECT city_id FROM city WHERE city_name='Vilnius')),
('Laisves al. 10','44215',(SELECT city_id FROM city WHERE city_name='Kaunas')),
('Old Town 5','00-001',(SELECT city_id FROM city WHERE city_name='Warsaw'))
ON CONFLICT DO NOTHING;

-- LOCATION
INSERT INTO location (location_name, city_id)
VALUES
('Vilnius Auction Hall',(SELECT city_id FROM city WHERE city_name='Vilnius')),
('Kaunas Expo Center',(SELECT city_id FROM city WHERE city_name='Kaunas'))
ON CONFLICT DO NOTHING;

-- BUYER
INSERT INTO buyer (buyer_name, contact_number, email, address_id)
VALUES
('Jonas Petraitis','+37060000001','jonas@example.com',
 (SELECT address_id FROM address WHERE street='Gedimino pr. 1')),
('Agnė Jankauskaitė','+37060000002','agne@example.com',
 (SELECT address_id FROM address WHERE street='Laisves al. 10'))
ON CONFLICT DO NOTHING;

-- SELLER
INSERT INTO seller (seller_name, contact_number, email, address_id)
VALUES
('Old Masters Gallery','+37060000011','gallery@example.com',
 (SELECT address_id FROM address WHERE street='Gedimino pr. 1')),
('Antique World','+37060000012','antiques@example.com',
 (SELECT address_id FROM address WHERE street='Old Town 5'))
ON CONFLICT DO NOTHING;

-- AUCTION
INSERT INTO auction (auction_date,start_time,end_time,location_id,category_id)
VALUES
('2024-03-15','18:00','21:00',
 (SELECT location_id FROM location WHERE location_name='Vilnius Auction Hall'),
 (SELECT category_id FROM category WHERE category_name='Art' AND parent_category_id IS NULL)),
('2024-04-20','17:00','20:30',
 (SELECT location_id FROM location WHERE location_name='Kaunas Expo Center'),
 (SELECT category_id FROM category WHERE category_name='Antiques' AND parent_category_id IS NULL))
ON CONFLICT DO NOTHING;

-- EMPLOYEE
INSERT INTO employee (name,role,auction_id)
VALUES
('Laura Admin','Auctioneer',(SELECT auction_id FROM auction WHERE auction_date='2024-03-15')),
('Mantas Helper','Assistant',(SELECT auction_id FROM auction WHERE auction_date='2024-03-15')),
('Eglė Manager','Coordinator',(SELECT auction_id FROM auction WHERE auction_date='2024-04-20'))
ON CONFLICT DO NOTHING;

-- ITEM
INSERT INTO item (item_name,description,starting_price,seller_id,category_id)
VALUES
('Sunset Over Vilnius','Oil painting',500,
 (SELECT seller_id FROM seller WHERE seller_name='Old Masters Gallery'),
 (SELECT category_id FROM category WHERE category_name='Painting')),
('Ancient Vase','19th century vase',300,
 (SELECT seller_id FROM seller WHERE seller_name='Antique World'),
 (SELECT category_id FROM category WHERE category_name='Antiques')),
('Bronze Statue','Bronze sculpture',800,
 (SELECT seller_id FROM seller WHERE seller_name='Old Masters Gallery'),
 (SELECT category_id FROM category WHERE category_name='Sculpture'))
ON CONFLICT DO NOTHING;

-- AUCTION_ITEM
INSERT INTO auction_item (auction_id,item_id,display_order,estimated_price)
VALUES
((SELECT auction_id FROM auction WHERE auction_date='2024-03-15'),
 (SELECT item_id FROM item WHERE item_name='Sunset Over Vilnius'),1,700),
((SELECT auction_id FROM auction WHERE auction_date='2024-03-15'),
 (SELECT item_id FROM item WHERE item_name='Bronze Statue'),2,1000),
((SELECT auction_id FROM auction WHERE auction_date='2024-04-20'),
 (SELECT item_id FROM item WHERE item_name='Ancient Vase'),1,450)
ON CONFLICT DO NOTHING;

-- LOT
INSERT INTO lot (lot_number,auction_id,item_id,lot_description)
VALUES
('A-01',(SELECT auction_id FROM auction WHERE auction_date='2024-03-15'),
 (SELECT item_id FROM item WHERE item_name='Sunset Over Vilnius'),'Main painting'),
('A-02',(SELECT auction_id FROM auction WHERE auction_date='2024-03-15'),
 (SELECT item_id FROM item WHERE item_name='Bronze Statue'),'Sculpture lot'),
('B-01',(SELECT auction_id FROM auction WHERE auction_date='2024-04-20'),
 (SELECT item_id FROM item WHERE item_name='Ancient Vase'),'Antique lot')
ON CONFLICT DO NOTHING;

-- BID
INSERT INTO bid (lot_id,buyer_id,bid_amount,bid_time)
VALUES
((SELECT lot_id FROM lot WHERE lot_number='A-01'),
 (SELECT buyer_id FROM buyer WHERE buyer_name='Jonas Petraitis'),
 600,'2024-03-15 18:30'),
((SELECT lot_id FROM lot WHERE lot_number='A-01'),
 (SELECT buyer_id FROM buyer WHERE buyer_name='Agnė Jankauskaitė'),
 650,'2024-03-15 18:45'),
((SELECT lot_id FROM lot WHERE lot_number='B-01'),
 (SELECT buyer_id FROM buyer WHERE buyer_name='Jonas Petraitis'),
 400,'2024-04-20 17:20')
ON CONFLICT DO NOTHING;

-- SALE
INSERT INTO sale (lot_id,buyer_id,final_price,sale_date)
VALUES
((SELECT lot_id FROM lot WHERE lot_number='A-01'),
 (SELECT buyer_id FROM buyer WHERE buyer_name='Agnė Jankauskaitė'),
 650,'2024-03-15'),
((SELECT lot_id FROM lot WHERE lot_number='B-01'),
 (SELECT buyer_id FROM buyer WHERE buyer_name='Jonas Petraitis'),
 400,'2024-04-20')
ON CONFLICT DO NOTHING;

-- PAYMENT
INSERT INTO payment (sale_id,payment_date,payment_amount,payment_method)
VALUES
((SELECT sale_id FROM sale s JOIN lot l ON s.lot_id=l.lot_id WHERE l.lot_number='A-01'),
 '2024-03-16',650,'CARD'),
((SELECT sale_id FROM sale s JOIN lot l ON s.lot_id=l.lot_id WHERE l.lot_number='B-01'),
 '2024-04-21',400,'TRANSFER')
ON CONFLICT DO NOTHING;

-- 5. Add record_ts to ALL TABLES

ALTER TABLE country      ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE city         ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE category     ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE address      ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE location     ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE buyer        ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE seller       ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE auction      ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE employee     ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE item         ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE auction_item ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE lot          ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE bid          ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE sale         ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE payment      ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
