-- 1. CREATE DATABASE

CREATE DATABASE auction_house;

-- 2. CREATE SCHEMA

CREATE SCHEMA IF NOT EXISTS auction_house_schema;
SET search_path TO auction_house_schema;

-- 3. CREATE TABLES (SCHEMA-QUALIFIED + IF NOT EXISTS)

-- COUNTRY
CREATE TABLE IF NOT EXISTS auction_house_schema.country (
    country_id BIGSERIAL PRIMARY KEY,
    country_name VARCHAR(100) NOT NULL,
    CONSTRAINT uq_country_name UNIQUE (country_name)
);

-- CITY
CREATE TABLE IF NOT EXISTS auction_house_schema.city (
    city_id BIGSERIAL PRIMARY KEY,
    city_name VARCHAR(100) NOT NULL,
    country_id BIGINT NOT NULL,
    CONSTRAINT fk_city_country FOREIGN KEY (country_id)
        REFERENCES auction_house_schema.country(country_id),
    CONSTRAINT uq_city_country UNIQUE (city_name, country_id)
);

-- CATEGORY
CREATE TABLE IF NOT EXISTS auction_house_schema.category (
    category_id BIGSERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    description TEXT,
    parent_category_id BIGINT,
    CONSTRAINT fk_category_parent FOREIGN KEY (parent_category_id)
        REFERENCES auction_house_schema.category(category_id),
    CONSTRAINT uq_category_parent UNIQUE (category_name, parent_category_id)
);

-- ADDRESS
CREATE TABLE IF NOT EXISTS auction_house_schema.address (
    address_id BIGSERIAL PRIMARY KEY,
    street VARCHAR(150) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    city_id BIGINT NOT NULL,
    CONSTRAINT fk_address_city FOREIGN KEY (city_id)
        REFERENCES auction_house_schema.city(city_id),
    CONSTRAINT uq_address UNIQUE (street, postal_code, city_id)
);

-- LOCATION
CREATE TABLE IF NOT EXISTS auction_house_schema.location (
    location_id BIGSERIAL PRIMARY KEY,
    location_name VARCHAR(100) NOT NULL,
    city_id BIGINT NOT NULL,
    CONSTRAINT fk_location_city FOREIGN KEY (city_id)
        REFERENCES auction_house_schema.city(city_id),
    CONSTRAINT uq_location_city UNIQUE (location_name, city_id)
);

-- BUYER
CREATE TABLE IF NOT EXISTS auction_house_schema.buyer (
    buyer_id BIGSERIAL PRIMARY KEY,
    buyer_name VARCHAR(100) NOT NULL,
    contact_number VARCHAR(30),
    email VARCHAR(120),
    address_id BIGINT NOT NULL,
    CONSTRAINT fk_buyer_address FOREIGN KEY (address_id)
        REFERENCES auction_house_schema.address(address_id),
    CONSTRAINT uq_buyer_email UNIQUE (email)
);

-- SELLER
CREATE TABLE IF NOT EXISTS auction_house_schema.seller (
    seller_id BIGSERIAL PRIMARY KEY,
    seller_name VARCHAR(100) NOT NULL,
    contact_number VARCHAR(30),
    email VARCHAR(120),
    address_id BIGINT NOT NULL,
    CONSTRAINT fk_seller_address FOREIGN KEY (address_id)
        REFERENCES auction_house_schema.address(address_id),
    CONSTRAINT uq_seller_email UNIQUE (email)
);

-- AUCTION
CREATE TABLE IF NOT EXISTS auction_house_schema.auction (
    auction_id BIGSERIAL PRIMARY KEY,
    auction_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    location_id BIGINT NOT NULL,
    category_id BIGINT NOT NULL,
    CONSTRAINT fk_auction_location FOREIGN KEY (location_id)
        REFERENCES auction_house_schema.location(location_id),
    CONSTRAINT fk_auction_category FOREIGN KEY (category_id)
        REFERENCES auction_house_schema.category(category_id),
    CONSTRAINT chk_auction_date CHECK (auction_date > DATE '2000-01-01'),
    CONSTRAINT chk_auction_time CHECK (end_time > start_time)
);

-- EMPLOYEE
CREATE TABLE IF NOT EXISTS auction_house_schema.employee (
    employee_id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    role VARCHAR(50),
    auction_id BIGINT,
    CONSTRAINT fk_employee_auction FOREIGN KEY (auction_id)
        REFERENCES auction_house_schema.auction(auction_id)
);

-- ITEM
CREATE TABLE IF NOT EXISTS auction_house_schema.item (
    item_id BIGSERIAL PRIMARY KEY,
    item_name VARCHAR(150) NOT NULL,
    description TEXT,
    starting_price NUMERIC(12,2) NOT NULL,
    seller_id BIGINT NOT NULL,
    category_id BIGINT NOT NULL,
    CONSTRAINT fk_item_seller FOREIGN KEY (seller_id)
        REFERENCES auction_house_schema.seller(seller_id),
    CONSTRAINT fk_item_category FOREIGN KEY (category_id)
        REFERENCES auction_house_schema.category(category_id),
    CONSTRAINT chk_item_starting_price CHECK (starting_price >= 0),
    CONSTRAINT uq_item_seller UNIQUE (item_name, seller_id)
);

-- AUCTION_ITEM
CREATE TABLE IF NOT EXISTS auction_house_schema.auction_item (
    auction_id BIGINT NOT NULL,
    item_id BIGINT NOT NULL,
    display_order INT NOT NULL,
    estimated_price NUMERIC(12,2),
    CONSTRAINT pk_auction_item PRIMARY KEY (auction_id, item_id),
    CONSTRAINT fk_ai_auction FOREIGN KEY (auction_id)
        REFERENCES auction_house_schema.auction(auction_id),
    CONSTRAINT fk_ai_item FOREIGN KEY (item_id)
        REFERENCES auction_house_schema.item(item_id),
    CONSTRAINT chk_ai_estimated CHECK (estimated_price IS NULL OR estimated_price >= 0),
    CONSTRAINT uq_ai_display UNIQUE (auction_id, display_order)
);

-- LOT
CREATE TABLE IF NOT EXISTS auction_house_schema.lot (
    lot_id BIGSERIAL PRIMARY KEY,
    lot_number VARCHAR(20) NOT NULL,
    auction_id BIGINT NOT NULL,
    item_id BIGINT NOT NULL,
    lot_description TEXT,
    CONSTRAINT fk_lot_auction FOREIGN KEY (auction_id)
        REFERENCES auction_house_schema.auction(auction_id),
    CONSTRAINT fk_lot_item FOREIGN KEY (item_id)
        REFERENCES auction_house_schema.item(item_id),
    CONSTRAINT uq_lot UNIQUE (auction_id, lot_number)
);

-- BID
CREATE TABLE IF NOT EXISTS auction_house_schema.bid (
    bid_id BIGSERIAL PRIMARY KEY,
    lot_id BIGINT NOT NULL,
    buyer_id BIGINT NOT NULL,
    bid_amount NUMERIC(12,2) NOT NULL,
    bid_time TIMESTAMP NOT NULL,
    CONSTRAINT fk_bid_lot FOREIGN KEY (lot_id)
        REFERENCES auction_house_schema.lot(lot_id),
    CONSTRAINT fk_bid_buyer FOREIGN KEY (buyer_id)
        REFERENCES auction_house_schema.buyer(buyer_id),
    CONSTRAINT chk_bid_amount CHECK (bid_amount >= 0)
);

-- SALE
CREATE TABLE IF NOT EXISTS auction_house_schema.sale (
    sale_id BIGSERIAL PRIMARY KEY,
    lot_id BIGINT NOT NULL,
    buyer_id BIGINT NOT NULL,
    final_price NUMERIC(12,2) NOT NULL,
    sale_date DATE NOT NULL,
    CONSTRAINT fk_sale_lot FOREIGN KEY (lot_id)
        REFERENCES auction_house_schema.lot(lot_id),
    CONSTRAINT fk_sale_buyer FOREIGN KEY (buyer_id)
        REFERENCES auction_house_schema.buyer(buyer_id),
    CONSTRAINT chk_sale_price CHECK (final_price >= 0),
    CONSTRAINT chk_sale_date CHECK (sale_date > DATE '2000-01-01'),
    CONSTRAINT uq_sale UNIQUE (lot_id)
);

-- PAYMENT
CREATE TABLE IF NOT EXISTS auction_house_schema.payment (
    payment_id BIGSERIAL PRIMARY KEY,
    sale_id BIGINT NOT NULL,
    payment_date DATE NOT NULL,
    payment_amount NUMERIC(12,2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    CONSTRAINT fk_payment_sale FOREIGN KEY (sale_id)
        REFERENCES auction_house_schema.sale(sale_id),
    CONSTRAINT uq_payment UNIQUE (sale_id),
    CONSTRAINT chk_payment_amount CHECK (payment_amount >= 0),
    CONSTRAINT chk_payment_date CHECK (payment_date > DATE '2000-01-01'),
    CONSTRAINT chk_payment_method CHECK (payment_method IN ('CASH','CARD','TRANSFER'))
);


-- 4. INSERT SAMPLE DATA (WITH UPPER())


INSERT INTO auction_house_schema.country (country_name)
VALUES ('Lithuania'), ('Poland')
ON CONFLICT DO NOTHING;

INSERT INTO auction_house_schema.city (city_name, country_id)
VALUES
('Vilnius', (SELECT country_id FROM auction_house_schema.country WHERE UPPER(country_name)='LITHUANIA')),
('Kaunas',  (SELECT country_id FROM auction_house_schema.country WHERE UPPER(country_name)='LITHUANIA')),
('Warsaw',  (SELECT country_id FROM auction_house_schema.country WHERE UPPER(country_name)='POLAND'))
ON CONFLICT DO NOTHING;

INSERT INTO auction_house_schema.category (category_name, description, parent_category_id)
VALUES
('Art','Fine art',NULL),
('Antiques','Old objects',NULL)
ON CONFLICT DO NOTHING;

INSERT INTO auction_house_schema.category (category_name, description, parent_category_id)
VALUES
('Painting','Paintings',(SELECT category_id FROM auction_house_schema.category WHERE UPPER(category_name)='ART' AND parent_category_id IS NULL)),
('Sculpture','Sculptures',(SELECT category_id FROM auction_house_schema.category WHERE UPPER(category_name)='ART' AND parent_category_id IS NULL))
ON CONFLICT DO NOTHING;

INSERT INTO auction_house_schema.address (street, postal_code, city_id)
VALUES
('Gedimino pr. 1','01103',(SELECT city_id FROM auction_house_schema.city WHERE UPPER(city_name)='VILNIUS')),
('Laisves al. 10','44215',(SELECT city_id FROM auction_house_schema.city WHERE UPPER(city_name)='KAUNAS')),
('Old Town 5','00-001',(SELECT city_id FROM auction_house_schema.city WHERE UPPER(city_name)='WARSAW'))
ON CONFLICT DO NOTHING;

INSERT INTO auction_house_schema.location (location_name, city_id)
VALUES
('Vilnius Auction Hall',(SELECT city_id FROM auction_house_schema.city WHERE UPPER(city_name)='VILNIUS')),
('Kaunas Expo Center',(SELECT city_id FROM auction_house_schema.city WHERE UPPER(city_name)='KAUNAS'))
ON CONFLICT DO NOTHING;

INSERT INTO auction_house_schema.buyer (buyer_name, contact_number, email, address_id)
VALUES
('Jonas Petraitis','+37060000001','jonas@example.com',
 (SELECT address_id FROM auction_house_schema.address WHERE UPPER(street)='GEDIMINO PR. 1')),
('Agnė Jankauskaitė','+37060000002','agne@example.com',
 (SELECT address_id FROM auction_house_schema.address WHERE UPPER(street)='LAISVES AL. 10'))
ON CONFLICT DO NOTHING;

INSERT INTO auction_house_schema.seller (seller_name, contact_number, email, address_id)
VALUES
('Old Masters Gallery','+37060000011','gallery@example.com',
 (SELECT address_id FROM auction_house_schema.address WHERE UPPER(street)='GEDIMINO PR. 1')),
('Antique World','+37060000012','antiques@example.com',
 (SELECT address_id FROM auction_house_schema.address WHERE UPPER(street)='OLD TOWN 5'))
ON CONFLICT DO NOTHING;

INSERT INTO auction_house_schema.auction (auction_date,start_time,end_time,location_id,category_id)
VALUES
('2024-03-15','18:00','21:00',
 (SELECT location_id FROM auction_house_schema.location WHERE UPPER(location_name)='VILNIUS AUCTION HALL'),
 (SELECT category_id FROM auction_house_schema.category WHERE UPPER(category_name)='ART' AND parent_category_id IS NULL)),
('2024-04-20','17:00','20:30',
 (SELECT location_id FROM auction_house_schema.location WHERE UPPER(location_name)='KAUNAS EXPO CENTER'),
 (SELECT category_id FROM auction_house_schema.category WHERE UPPER(category_name)='ANTIQUES' AND parent_category_id IS NULL))
ON CONFLICT DO NOTHING;

INSERT INTO auction_house_schema.employee (name,role,auction_id)
VALUES
('Laura Admin','Auctioneer',(SELECT auction_id FROM auction_house_schema.auction WHERE auction_date='2024-03-15')),
('Mantas Helper','Assistant',(SELECT auction_id FROM auction_house_schema.auction WHERE auction_date='2024-03-15')),
('Eglė Manager','Coordinator',(SELECT auction_id FROM auction_house_schema.auction WHERE auction_date='2024-04-20'))
ON CONFLICT DO NOTHING;

INSERT INTO auction_house_schema.item (item_name,description,starting_price,seller_id,category_id)
VALUES
('Sunset Over Vilnius','Oil painting',500,
 (SELECT seller_id FROM auction_house_schema.seller WHERE UPPER(seller_name)='OLD MASTERS GALLERY'),
 (SELECT category_id FROM auction_house_schema.category WHERE UPPER(category_name)='PAINTING')),
('Ancient Vase','19th century vase',300,
 (SELECT seller_id FROM auction_house_schema.seller WHERE UPPER(seller_name)='ANTIQUE WORLD'),
 (SELECT category_id FROM auction_house_schema.category WHERE UPPER(category_name)='ANTIQUES')),
('Bronze Statue','Bronze sculpture',800,
 (SELECT seller_id FROM auction_house_schema.seller WHERE UPPER(seller_name)='OLD MASTERS GALLERY'),
 (SELECT category_id FROM auction_house_schema.category WHERE UPPER(category_name)='SCULPTURE'))
ON CONFLICT DO NOTHING;

INSERT INTO auction_house_schema.auction_item (auction_id,item_id,display_order,estimated_price)
VALUES
((SELECT auction_id FROM auction_house_schema.auction WHERE auction_date='2024-03-15'),
 (SELECT item_id FROM auction_house_schema.item WHERE UPPER(item_name)='SUNSET OVER VILNIUS'),1,700),
((SELECT auction_id FROM auction_house_schema.auction WHERE auction_date='2024-03-15'),
 (SELECT item_id FROM auction_house_schema.item WHERE UPPER(item_name)='BRONZE STATUE'),2,1000),
((SELECT auction_id FROM auction_house_schema.auction WHERE auction_date='2024-04-20'),
 (SELECT item_id FROM auction_house_schema.item WHERE UPPER(item_name)='ANCIENT VASE'),1,450)
ON CONFLICT DO NOTHING;

INSERT INTO auction_house_schema.lot (lot_number,auction_id,item_id,lot_description)
VALUES
('A-01',(SELECT auction_id FROM auction_house_schema.auction WHERE auction_date='2024-03-15'),
 (SELECT item_id FROM auction_house_schema.item WHERE UPPER(item_name)='SUNSET OVER VILNIUS'),'Main painting'),
('A-02',(SELECT auction_id FROM auction_house_schema.auction WHERE auction_date='2024-03-15'),
 (SELECT item_id FROM auction_house_schema.item WHERE UPPER(item_name)='BRONZE STATUE'),'Sculpture lot'),
('B-01',(SELECT auction_id FROM auction_house_schema.auction WHERE auction_date='2024-04-20'),
 (SELECT item_id FROM auction_house_schema.item WHERE UPPER(item_name)='ANCIENT VASE'),'Antique lot')
ON CONFLICT DO NOTHING;

INSERT INTO auction_house_schema.bid (lot_id,buyer_id,bid_amount,bid_time)
VALUES
((SELECT lot_id FROM auction_house_schema.lot WHERE UPPER(lot_number)='A-01'),
 (SELECT buyer_id FROM auction_house_schema.buyer WHERE UPPER(buyer_name)='JONAS PETRAITIS'),
 600,'2024-03-15 18:30'),
((SELECT lot_id FROM auction_house_schema.lot WHERE UPPER(lot_number)='A-01'),
 (SELECT buyer_id FROM auction_house_schema.buyer WHERE UPPER(buyer_name)='AGNĖ JANKAUSKAITĖ'),
 650,'2024-03-15 18:45'),
((SELECT lot_id FROM auction_house_schema.lot WHERE UPPER(lot_number)='B-01'),
 (SELECT buyer_id FROM auction_house_schema.buyer WHERE UPPER(buyer_name)='JONAS PETRAITIS'),
 400,'2024-04-20 17:20')
ON CONFLICT DO NOTHING;

INSERT INTO auction_house_schema.sale (lot_id,buyer_id,final_price,sale_date)
VALUES
((SELECT lot_id FROM auction_house_schema.lot WHERE UPPER(lot_number)='A-01'),
 (SELECT buyer_id FROM auction_house_schema.buyer WHERE UPPER(buyer_name)='AGNĖ JANKAUSKAITĖ'),
 650,'2024-03-15'),
((SELECT lot_id FROM auction_house_schema.lot WHERE UPPER(lot_number)='B-01'),
 (SELECT buyer_id FROM auction_house_schema.buyer WHERE UPPER(buyer_name)='JONAS PETRAITIS'),
 400,'2024-04-20')
ON CONFLICT DO NOTHING;

INSERT INTO auction_house_schema.payment (sale_id,payment_date,payment_amount,payment_method)
VALUES
((SELECT sale_id FROM auction_house_schema.sale s
  JOIN auction_house_schema.lot l ON s.lot_id=l.lot_id
  WHERE UPPER(l.lot_number)='A-01'),
 '2024-03-16',650,'CARD'),
((SELECT sale_id FROM auction_house_schema.sale s
  JOIN auction_house_schema.lot l ON s.lot_id=l.lot_id
  WHERE UPPER(l.lot_number)='B-01'),
 '2024-04-21',400,'TRANSFER')
ON CONFLICT DO NOTHING;

-- 5. ADD record_ts TO ALL TABLES

ALTER TABLE auction_house_schema.country      ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE auction_house_schema.city         ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE auction_house_schema.category     ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE auction_house_schema.address      ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE auction_house_schema.location     ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE auction_house_schema.buyer        ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE auction_house_schema.seller       ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE auction_house_schema.auction      ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE auction_house_schema.employee     ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE auction_house_schema.item         ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE auction_house_schema.auction_item ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE auction_house_schema.lot          ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE auction_house_schema.bid          ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE auction_house_schema.sale         ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;
ALTER TABLE auction_house_schema.payment      ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT current_date;


