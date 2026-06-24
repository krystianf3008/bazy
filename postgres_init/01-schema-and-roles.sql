-- Schematy
CREATE SCHEMA streaming;
CREATE SCHEMA billing;

-- Tabele
CREATE TABLE streaming.events (
    event_id SERIAL PRIMARY KEY,
    title VARCHAR(120) NOT NULL,
    event_date TIMESTAMP NOT NULL,
    price NUMERIC(10,2) NOT NULL
);

CREATE TABLE streaming.channels (
    channel_id SERIAL PRIMARY KEY,
    channel_name VARCHAR(120) NOT NULL
);

CREATE TABLE billing.orders (
    order_id SERIAL PRIMARY KEY,
    customer_email VARCHAR(120) NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE billing.payments (
    payment_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES billing.orders(order_id),
    amount NUMERIC(10,2) NOT NULL,
    payment_status VARCHAR(30) NOT NULL
);

-- Grupy i Użytkownicy
CREATE ROLE ppv_admin NOLOGIN;
CREATE ROLE ppv_operator NOLOGIN;

CREATE USER admin1 WITH PASSWORD 'Admin123!';
CREATE USER operator1 WITH PASSWORD 'Operator123!';

GRANT ppv_admin TO admin1;
GRANT ppv_operator TO operator1;

-- Uprawnienia
GRANT USAGE ON SCHEMA streaming TO ppv_admin;
GRANT USAGE ON SCHEMA billing TO ppv_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA streaming TO ppv_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA billing TO ppv_admin;

GRANT USAGE ON SCHEMA streaming TO ppv_operator;
GRANT USAGE ON SCHEMA billing TO ppv_operator;
GRANT SELECT ON streaming.events TO ppv_operator;
GRANT SELECT ON streaming.channels TO ppv_operator;
GRANT INSERT ON billing.orders TO ppv_operator;
-- REVOKE zabezpieczające
REVOKE ALL ON billing.payments FROM ppv_operator;