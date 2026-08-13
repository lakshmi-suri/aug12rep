
-- ============================================================
-- WHAT IS CORTEX SENTIMENT?
-- ============================================================
--
-- SNOWFLAKE.CORTEX.SENTIMENT(text) returns a score from -1 to 1:
--
--   -1.0 = Very Negative
--   -0.5 = Somewhat Negative
--    0.0 = Neutral
--   +0.5 = Somewhat Positive
--   +1.0 = Very Positive
--
-- It's fast, cheap, and requires no prompt engineering.
-- Just pass text in and get a number back.
-- ============================================================

USE ROLE TRAINING_ROLE;
USE WAREHOUSE ANIMAL_TASK_WH;

-- ============================================================
-- EXAMPLE 1: Basic Sentiment Scoring
-- ============================================================

SELECT SNOWFLAKE.CORTEX.SENTIMENT('I love this product! Best purchase ever.') AS positive_score;
-- Expected: close to +1.0

SELECT SNOWFLAKE.CORTEX.SENTIMENT('This is the worst experience I have ever had.') AS negative_score;
-- Expected: close to -1.0

SELECT SNOWFLAKE.CORTEX.SENTIMENT('The package arrived on Tuesday.') AS neutral_score;
-- Expected: close to 0.0


-- ============================================================
-- EXAMPLE 2: Compare Sentiment Across Statements
-- ============================================================

SELECT text, SNOWFLAKE.CORTEX.SENTIMENT(text) AS score
FROM (
    VALUES
        ('Absolutely fantastic service, thank you!'),
        ('It was okay, nothing special.'),
        ('Terrible quality. I want a refund.'),
        ('The meeting is at 3pm tomorrow.'),
        ('I am so happy with my new phone!'),
        ('Disappointed. Expected much better.')
) AS t(text)
ORDER BY score DESC;


-- ============================================================
-- EXAMPLE 3: Sentiment on Table Data (Real Use Case)
-- Analyze customer reviews and categorize them.
-- ============================================================

CREATE OR REPLACE TEMPORARY TABLE product_reviews (
    review_id INT,
    customer STRING,
    product STRING,
    review_text STRING
);

INSERT INTO product_reviews VALUES
    (1, 'Alice', 'Laptop Pro X', 'Incredible performance and battery life. Worth every penny!'),
    (2, 'Bob', 'Laptop Pro X', 'Screen broke after 2 weeks. Extremely poor build quality.'),
    (3, 'Carol', 'SmartWatch Z', 'Does what it says. Battery lasts about 2 days.'),
    (4, 'Dave', 'SmartWatch Z', 'Love the health tracking features! Changed my daily routine.'),
    (5, 'Eve', 'Laptop Pro X', 'Runs hot and the fan is loud. Regret buying this.'),
    (6, 'Frank', 'SmartWatch Z', 'Returned it. The app kept crashing and syncing failed.'),
    (7, 'Grace', 'Laptop Pro X', 'Solid machine for development work. No complaints.'),
    (8, 'Hank', 'SmartWatch Z', 'Beautiful design and comfortable to wear all day.');

-- Score every review
SELECT
    review_id,
    customer,
    product,
    review_text,
    SNOWFLAKE.CORTEX.SENTIMENT(review_text) AS sentiment_score
FROM product_reviews
ORDER BY sentiment_score;


-- ============================================================
-- EXAMPLE 4: Categorize into Buckets (Positive/Neutral/Negative)
-- ============================================================

SELECT
    review_id,
    customer,
    product,
    review_text,
    SNOWFLAKE.CORTEX.SENTIMENT(review_text) AS score,
    CASE
        WHEN SNOWFLAKE.CORTEX.SENTIMENT(review_text) >= 0.4 THEN 'POSITIVE'
        WHEN SNOWFLAKE.CORTEX.SENTIMENT(review_text) <= -0.4 THEN 'NEGATIVE'
        ELSE 'NEUTRAL'
    END AS category
FROM product_reviews
ORDER BY score DESC;


-- ============================================================
-- EXAMPLE 5: Aggregate Sentiment by Product
-- Which product has happier customers?
-- ============================================================

SELECT
    product,
    COUNT(*) AS total_reviews,
    ROUND(AVG(SNOWFLAKE.CORTEX.SENTIMENT(review_text)), 3) AS avg_sentiment,
    SUM(CASE WHEN SNOWFLAKE.CORTEX.SENTIMENT(review_text) >= 0.4 THEN 1 ELSE 0 END) AS positive_count,
    SUM(CASE WHEN SNOWFLAKE.CORTEX.SENTIMENT(review_text) <= -0.4 THEN 1 ELSE 0 END) AS negative_count
FROM product_reviews
GROUP BY product;


-- ============================================================
-- EXAMPLE 6: Find Unhappy Customers (Alert Use Case)
-- Flag reviews that need immediate attention.
-- ============================================================

SELECT
    customer,
    product,
    review_text,
    SNOWFLAKE.CORTEX.SENTIMENT(review_text) AS score
FROM product_reviews
WHERE SNOWFLAKE.CORTEX.SENTIMENT(review_text) < -0.5
ORDER BY score;


-- ============================================================
-- EXAMPLE 7: Sentiment Over Time (Trend Analysis)
-- ============================================================

CREATE OR REPLACE TEMPORARY TABLE support_tickets (
    ticket_id INT,
    created_date DATE,
    message STRING
);

INSERT INTO support_tickets VALUES
    (1, '2025-01-05', 'Great help from the team, issue resolved quickly.'),
    (2, '2025-01-12', 'Had to call back 3 times. Very frustrating.'),
    (3, '2025-02-01', 'Smooth onboarding experience, thank you!'),
    (4, '2025-02-15', 'Your system crashed and I lost my work.'),
    (5, '2025-03-01', 'Agent was polite but could not solve my problem.'),
    (6, '2025-03-20', 'Amazing support! Fixed everything in 5 minutes.'),
    (7, '2025-04-01', 'Still waiting for a response after 4 days.'),
    (8, '2025-04-15', 'Perfect service as always. Thank you team!');

-- Monthly average sentiment trend
SELECT
    DATE_TRUNC('month', created_date) AS month,
    COUNT(*) AS ticket_count,
    ROUND(AVG(SNOWFLAKE.CORTEX.SENTIMENT(message)), 3) AS avg_sentiment
FROM support_tickets
GROUP BY month
ORDER BY month;


-- ============================================================
-- EXAMPLE 8: Combine with Other Cortex Functions
-- Sentiment + Summarization together.
-- ============================================================

SELECT
    customer,
    review_text,
    SNOWFLAKE.CORTEX.SENTIMENT(review_text) AS sentiment_score,
    SNOWFLAKE.CORTEX.SUMMARIZE(review_text) AS summary
FROM product_reviews
WHERE SNOWFLAKE.CORTEX.SENTIMENT(review_text) < -0.3;


-- ============================================================
-- TIPS & BEST PRACTICES
-- ============================================================
--
-- 1. FAST & CHEAP: SENTIMENT() is much faster and cheaper than
--    using COMPLETE() with a classification prompt.
--
-- 2. NO PROMPT NEEDED: Just pass the text — no instructions required.
--
-- 3. LANGUAGE: Works best with English text. For other languages,
--    consider CORTEX.TRANSLATE() first, then SENTIMENT().
--
-- 4. THRESHOLDS: Adjust the ±0.4 cutoffs based on your data.
--    Some domains (medical, legal) may need different thresholds.
--
-- 5. NULL HANDLING: Returns NULL if input is NULL.
--
-- 6. COMPARISON TO COMPLETE():
--    - SENTIMENT() → numeric score, fast, cheap, no prompt
--    - COMPLETE()  → flexible labels (POSITIVE/NEGATIVE/MIXED),
--                    can explain reasoning, but slower and costlier
-- ============================================================