-- Cortex AI_SENTIMENT demo: aspect-based sentiment analysis
-- Co-authored with CoCo

-- ============================================================
-- WHAT IS AI_SENTIMENT?
-- ============================================================
--
-- AI_SENTIMENT is Snowflake's latest sentiment function.
-- Unlike the older CORTEX.SENTIMENT() (which returns a number),
-- AI_SENTIMENT returns CATEGORICAL labels:
--
--   positive, negative, neutral, mixed, unknown
--
-- It also supports ASPECT-BASED analysis — score sentiment
-- for specific topics/aspects within the same text.
--
-- Syntax:
--   AI_SENTIMENT(text)                    — overall sentiment only
--   AI_SENTIMENT(text, [aspects_array])   — overall + per-aspect
--
-- Returns: JSON object with categories array
-- Supports: English, Spanish, French, German, Hindi, Italian, Portuguese
-- ============================================================

USE ROLE TRAINING_ROLE;
USE WAREHOUSE ANIMAL_TASK_WH;


-- ============================================================
-- EXAMPLE 1: Overall Sentiment (No Aspects)
-- Returns: positive, negative, neutral, or mixed
-- ============================================================

-- Positive example
SELECT AI_SENTIMENT('I love this product! Best purchase I have ever made.') AS result;

-- Negative example
SELECT AI_SENTIMENT('Terrible experience. The product broke on day one.') AS result;

-- Neutral example
SELECT AI_SENTIMENT('The package arrived on Tuesday afternoon.') AS result;

-- Mixed example (both good and bad)
SELECT AI_SENTIMENT('The food was amazing but the service was very slow.') AS result;


-- ============================================================
-- EXAMPLE 2: Aspect-Based Sentiment
-- Analyze sentiment for SPECIFIC aspects of the text.
-- Pass up to 10 aspects as an array.
-- ============================================================

-- Restaurant review: analyze Cost, Quality, and Wait Time separately
SELECT AI_SENTIMENT(
    'The pizza was absolutely delicious and fresh out of the oven.
     However, I waited 45 minutes for a table and the bill was way too high
     for what we got.',
    ['Cost', 'Quality', 'Wait Time']
) AS result;

-- Expected output:
-- {
--   "categories": [
--     {"name": "overall", "sentiment": "mixed"},
--     {"name": "Cost", "sentiment": "negative"},
--     {"name": "Quality", "sentiment": "positive"},
--     {"name": "Wait Time", "sentiment": "negative"}
--   ]
-- }


-- ============================================================
-- EXAMPLE 3: Product Review with Multiple Aspects
-- ============================================================

SELECT AI_SENTIMENT(
    'The laptop has a stunning display and lightning-fast processor.
     Battery life is disappointing though — barely lasts 4 hours.
     The keyboard feels cheap but the trackpad is smooth.',
    ['Display', 'Performance', 'Battery', 'Keyboard', 'Trackpad']
) AS result;


-- ============================================================
-- EXAMPLE 4: Apply to Table Data (Real Use Case)
-- Score customer feedback with aspect-based analysis.
-- ============================================================

CREATE OR REPLACE TEMPORARY TABLE customer_reviews (
    review_id INT,
    customer STRING,
    product STRING,
    review_text STRING
);

INSERT INTO customer_reviews VALUES
    (1, 'Alice', 'SmartPhone Pro', 'Amazing camera and screen quality. But the battery drains too fast and it overheats.'),
    (2, 'Bob', 'SmartPhone Pro', 'Love everything about this phone. Fast, beautiful, great battery life.'),
    (3, 'Carol', 'SmartPhone Pro', 'Decent phone for the price. Nothing exceptional but no complaints either.'),
    (4, 'Dave', 'SmartPhone Pro', 'Worst purchase ever. Camera is blurry, screen cracked easily, and support was useless.'),
    (5, 'Eve', 'SmartPhone Pro', 'The design is beautiful but the software is buggy and laggy.');

-- Analyze each review for Camera, Battery, and Design aspects
SELECT
    review_id,
    customer,
    review_text,
    AI_SENTIMENT(review_text, ['Camera', 'Battery', 'Design']) AS sentiment_analysis
FROM customer_reviews;


-- ============================================================
-- EXAMPLE 5: Extract Overall Sentiment from the JSON Result
-- Use JSON dot notation to pull out specific values.
-- ============================================================

SELECT
    review_id,
    customer,
    review_text,
    AI_SENTIMENT(review_text) AS full_result,
    AI_SENTIMENT(review_text):categories[0].sentiment::STRING AS overall_sentiment
FROM customer_reviews;


-- ============================================================
-- EXAMPLE 6: Extract Aspect Sentiments with FLATTEN
-- Parse the JSON to get one row per aspect.
-- ============================================================

SELECT
    r.review_id,
    r.customer,
    f.value:name::STRING AS aspect,
    f.value:sentiment::STRING AS sentiment
FROM customer_reviews r,
    LATERAL FLATTEN(input => AI_SENTIMENT(r.review_text, ['Camera', 'Battery', 'Design']):categories) f
ORDER BY r.review_id, aspect;


-- ============================================================
-- EXAMPLE 7: Aggregate — Count Sentiment by Aspect
-- Which aspects are customers happiest/unhappiest about?
-- ============================================================

SELECT
    f.value:name::STRING AS aspect,
    f.value:sentiment::STRING AS sentiment,
    COUNT(*) AS review_count
FROM customer_reviews r,
    LATERAL FLATTEN(input => AI_SENTIMENT(r.review_text, ['Camera', 'Battery', 'Design']):categories) f
WHERE f.value:name::STRING != 'overall'
GROUP BY aspect, sentiment
ORDER BY aspect, review_count DESC;


-- ============================================================
-- EXAMPLE 8: Multilingual Support
-- AI_SENTIMENT works across 7 languages without translation.
-- ============================================================

-- Spanish review
SELECT AI_SENTIMENT(
    'El restaurante tiene buena comida pero el servicio fue terrible y muy caro.',
    ['Comida', 'Servicio', 'Precio']
) AS spanish_result;

-- German review (aspects can be in English even if text is not)
SELECT AI_SENTIMENT(
    'Das Hotel war sauber und modern, aber das Frühstück war enttäuschend.',
    ['Cleanliness', 'Breakfast', 'Room']
) AS german_result;

-- French review
SELECT AI_SENTIMENT(
    'Le film était visuellement magnifique mais le scénario manquait de profondeur.',
    ['Visual', 'Story']
) AS french_result;


-- ============================================================
-- EXAMPLE 9: Filter Negative Reviews for Follow-Up
-- Find reviews where specific aspects are negative.
-- ============================================================

SELECT
    r.review_id,
    r.customer,
    r.review_text
FROM customer_reviews r
WHERE AI_SENTIMENT(r.review_text):categories[0].sentiment::STRING IN ('negative', 'mixed');


-- ============================================================
-- EXAMPLE 10: Compare AI_SENTIMENT vs CORTEX.SENTIMENT
-- ============================================================

-- Old function: returns a NUMBER (-1 to 1)
SELECT
    'The food was great but service was terrible.' AS text,
    SNOWFLAKE.CORTEX.SENTIMENT('The food was great but service was terrible.') AS old_numeric_score;

-- New function: returns CATEGORICAL labels with aspect breakdown
SELECT
    'The food was great but service was terrible.' AS text,
    AI_SENTIMENT('The food was great but service was terrible.', ['Food', 'Service']) AS new_aspect_result;

-- Key differences:
-- CORTEX.SENTIMENT() → single number, no aspects, fast
-- AI_SENTIMENT()     → categorical labels, aspect-based, multilingual, richer output


-- ============================================================
-- TIPS & BEST PRACTICES
-- ============================================================
--
-- 1. ASPECTS: Up to 10 aspects, each max 30 characters.
--    Choose aspects relevant to your domain.
--
-- 2. UNKNOWN: If an aspect doesn't appear in the text,
--    AI_SENTIMENT returns "unknown" for that aspect.
--
-- 3. CONTEXT WINDOW: Optimized for up to 2,048 tokens (~1,600 words).
--    Longer texts may be truncated.
--
-- 4. LANGUAGES: English, Spanish, French, German, Hindi,
--    Italian, Portuguese. No language parameter needed —
--    it auto-detects.
--
-- 5. COST: Cheaper than using AI_COMPLETE with a prompt for
--    sentiment. Purpose-built model = better accuracy + lower cost.
--
-- 6. PARSING RESULTS: Use :categories[0].sentiment for overall,
--    or LATERAL FLATTEN for per-aspect rows.
--
-- 7. LEGACY: SNOWFLAKE.CORTEX.SENTIMENT() still works but will
--    be deprecated. Migrate to AI_SENTIMENT for new code.
-- ============================================================
