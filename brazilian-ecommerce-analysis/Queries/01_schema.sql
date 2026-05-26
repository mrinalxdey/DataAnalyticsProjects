CREATE TABLE IF NOT EXISTS customers (
    customer_id VARCHAR(50) NOT NULL,
    customer_unique_id VARCHAR(50) NOT NULL,
    customer_zip_code_prefix INT,
    customer_city VARCHAR(50),
    customer_state VARCHAR(2),
    CONSTRAINT pk_customers PRIMARY KEY (customer_id)
);

CREATE TABLE IF NOT EXISTS geolocation (
    geolocation_zip_code_prefix INT,
    geolocation_lat FLOAT,
    geolocation_lng FLOAT,
    geolocation_city VARCHAR(50),
    geolocation_state VARCHAR(2)
);

CREATE TABLE IF NOT EXISTS orders (
    order_id VARCHAR(50),
    customer_id VARCHAR(50) NOT NULL,
    order_status VARCHAR(15) NOT NULL,
    order_purchase_timestamp TIMESTAMP NOT NULL,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,
    CONSTRAINT pk_orders PRIMARY KEY (order_id),
    CONSTRAINT fk_orders_customer_id FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id)
);

CREATE TABLE IF NOT EXISTS product_category_name_translation (
	product_category_name varchar(50),
    product_category_name_english varchar(50),
    constraint pk_product_category_name primary key (product_category_name)
);

CREATE TABLE IF NOT EXISTS products (
    product_id VARCHAR(50),
    product_category_name VARCHAR(50),
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT,
    CONSTRAINT pk_products PRIMARY KEY (product_id),
    CONSTRAINT fk_products_category_name FOREIGN KEY (product_category_name)
        REFERENCES product_category_name_translation (product_category_name)
);

CREATE TABLE IF NOT EXISTS sellers (
    seller_id VARCHAR(50),
    seller_zip_code_prefix INT,
    seller_city VARCHAR(50),
    seller_state VARCHAR(2),
    CONSTRAINT pk_sellers PRIMARY KEY (seller_id)
);

CREATE TABLE IF NOT EXISTS order_items (
    order_id VARCHAR(50) NOT NULL,
    order_item_id INT NOT NULL,
    product_id VARCHAR(50) NOT NULL,
    seller_id VARCHAR(50) NOT NULL,
    shipping_limit_date TIMESTAMP,
    price DECIMAL(10 , 2 ),
    freight_value DECIMAL(10 , 2 ),
    CONSTRAINT pk_order_items PRIMARY KEY (order_id , order_item_id),
    CONSTRAINT fk_order_items_orders FOREIGN KEY (order_id)
        REFERENCES orders (order_id),
    CONSTRAINT fk_order_items_products FOREIGN KEY (product_id)
        REFERENCES products (product_id),
    CONSTRAINT fk_order_items_sellers FOREIGN KEY (seller_id)
        REFERENCES sellers (seller_id)
);

CREATE TABLE IF NOT EXISTS reviews (
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INT NOT NULL,
    review_comment_title VARCHAR(255),
    review_comment_message TEXT,
    review_creation_date TIMESTAMP NOT NULL,
    review_answer_timestamp TIMESTAMP NOT NULL,
    CONSTRAINT pk_order_reviews PRIMARY KEY (review_id , order_id),
    CONSTRAINT chk_review_score CHECK (review_score BETWEEN 1 AND 5),
    CONSTRAINT fk_order_reviews_order_id FOREIGN KEY (order_id)
        REFERENCES orders (order_id)
);

CREATE TABLE IF NOT EXISTS payments (
    order_id VARCHAR(50),
    payment_sequential INT,
    payment_type VARCHAR(30) NOT NULL,
    payment_installments INT NOT NULL,
    payment_value DECIMAL(10 , 2 ) NOT NULL,
    CONSTRAINT pk_order_payments PRIMARY KEY (order_id , payment_sequential),
    CONSTRAINT fk_order_payments_orders FOREIGN KEY (order_id)
        REFERENCES orders (order_id),
    CONSTRAINT chk_payment_installments CHECK (payment_installments > 0),
    CONSTRAINT chk_payment_value CHECK (payment_value >= 0)
);
