Monthly country metrics with top product.

  Schema
  --------------
  customers(id        BIGINT PRIMARY KEY,
            name      TEXT,
            country   TEXT,
            created_at TIMESTAMP);

  orders(id          BIGINT PRIMARY KEY,
         customer_id BIGINT REFERENCES customers(id),
         order_date  TIMESTAMP,
         total_amount NUMERIC);

  order_items(id        BIGINT PRIMARY KEY,
              order_id  BIGINT REFERENCES orders(id),
              product_id BIGINT,
              quantity   INT,
              unit_price NUMERIC);

  products(id       BIGINT PRIMARY KEY,
           name     TEXT,
           category TEXT);
*/

WITH RECURSIVE month_series AS (
    -- Last 12 months including current month
    SELECT date_trunc('month', current_date) - interval '11 month' AS month_start
    UNION ALL
    SELECT month_start + interval '1 month'
    FROM month_series
    WHERE month_start + interval '1 month' <= date_trunc('month', current_date)
),

customer_first_order AS (
    -- First order date per customer
    SELECT
        o.customer_id,
        MIN(o.order_date) AS first_order_date
    FROM orders o
    GROUP BY o.customer_id
),

orders_enriched AS (
    -- Orders with month + new/returning flag
    SELECT
        o.id AS order_id,
        o.customer_id,
        o.order_date,
        date_trunc('month', o.order_date) AS order_month,
        c.country,
        o.total_amount,
        CASE
            WHEN cfo.first_order_date >= date_trunc('month', o.order_date)
             AND cfo.first_order_date <  date_trunc('month', o.order_date) + interval '1 month'
            THEN 1 ELSE 0
        END AS is_new_customer
    FROM orders o
    JOIN customers c          ON c.id = o.customer_id
    JOIN customer_first_order cfo ON cfo.customer_id = o.customer_id
),

monthly_country_stats AS (
    -- Per month & country: revenue, customers, AOV, etc.
    SELECT
        ms.month_start AS month,
        oe.country,
        COUNT(DISTINCT oe.customer_id)                                        AS active_customers,
        SUM(oe.is_new_customer)                                               AS new_customers,
        COUNT(DISTINCT CASE WHEN oe.is_new_customer = 0 THEN oe.customer_id END)
                                                                            AS returning_customers,
        COUNT(DISTINCT oe.order_id)                                           AS orders_count,
        SUM(oe.total_amount)                                                  AS revenue,
        AVG(oe.total_amount)                                                  AS avg_order_value
    FROM month_series ms
    LEFT JOIN orders_enriched oe
           ON oe.order_month = ms.month_start
    GROUP BY ms.month_start, oe.country
),

product_revenue AS (
    -- Per month, country & product: revenue + rank
    SELECT
        date_trunc('month', o.order_date) AS order_month,
        c.country,
        oi.product_id,
        SUM(oi.quantity * oi.unit_price) AS product_revenue,
        DENSE_RANK() OVER (
            PARTITION BY date_trunc('month', o.order_date), c.country
            ORDER BY SUM(oi.quantity * oi.unit_price) DESC
        ) AS revenue_rank
    FROM orders o
    JOIN customers   c  ON c.id = o.customer_id
    JOIN order_items oi ON oi.order_id = o.id
    GROUP BY date_trunc('month', o.order_date), c.country, oi.product_id
),

top_products AS (
    -- Top product by revenue per month & country
    SELECT
        order_month AS month,
        country,
        product_id,
        product_revenue
    FROM product_revenue
    WHERE revenue_rank = 1
)

-- Final result
SELECT
    mcs.month,
    mcs.country,
    mcs.revenue,
    mcs.orders_count,
    mcs.active_customers,
    mcs.new_customers,
    mcs.returning_customers,
    mcs.avg_order_value,
    tp.product_id       AS top_product_id,
    tp.product_revenue  AS top_product_revenue
FROM monthly_country_stats mcs
LEFT JOIN top_products tp
       ON tp.month = mcs.month
      AND tp.country = mcs.country
ORDER BY mcs.month, mcs.country;
