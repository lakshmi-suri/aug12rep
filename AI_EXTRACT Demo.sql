-- Cortex AI_EXTRACT demo: extract structured data from text and files
-- Co-authored with CoCo

-- ============================================================
-- WHAT IS AI_EXTRACT?
-- ============================================================
--
-- AI_EXTRACT pulls specific fields from unstructured text or files.
-- You tell it WHAT to extract, and it returns structured data.
--
-- Supported inputs:
--   - Plain text strings
--   - Files: PDF, PNG, PPT, EML, DOC, DOCX, JPEG, JPG, HTM,
--            HTML, TEXT, TXT, TIF, TIFF, BMP, GIF, WEBP, MD
--
-- Syntax:
--   AI_EXTRACT(input, fields_array)           — from text
--   AI_EXTRACT(file => TO_FILE(...), ...)     — from a file
--
-- Returns: JSON object with your requested field names as keys
-- ============================================================

USE ROLE TRAINING_ROLE;
USE WAREHOUSE ANIMAL_TASK_WH;


-- ============================================================
-- EXAMPLE 1: Extract from a Simple Text String
-- Pass an array of field names — AI_EXTRACT figures out the rest.
-- ============================================================

SELECT AI_EXTRACT(
    'John Smith is a 34-year-old software engineer living in Seattle, Washington.',
    ['name', 'age', 'city', 'occupation']
) AS result;

-- Expected output:
-- {"name": "John Smith", "age": 34, "city": "Seattle", "occupation": "software engineer"}


-- ============================================================
-- EXAMPLE 2: Extract from an Email Body
-- ============================================================

SELECT AI_EXTRACT(
    'Hi Team,

     Please schedule a meeting with Dr. Sarah Johnson on March 15, 2025
     at 2:30 PM in Conference Room B. The topic will be Q1 budget review.

     Thanks,
     Mike Chen
     Finance Department',
    ['sender', 'recipient', 'meeting_date', 'meeting_time', 'location', 'topic', 'department']
) AS email_fields;


-- ============================================================
-- EXAMPLE 3: Extract from Business Documents (Invoice Text)
-- ============================================================

SELECT AI_EXTRACT(
    'INVOICE #INV-2025-0847
     Date: April 3, 2025
     Bill To: Acme Corporation
     Address: 123 Main Street, Portland, OR 97201

     Items:
     - Cloud Storage (500GB): $49.99
     - API Calls (1M requests): $29.99
     - Premium Support: $99.99

     Subtotal: $179.97
     Tax (8%): $14.40
     Total Due: $194.37
     Payment Due By: May 3, 2025',
    ['invoice_number', 'date', 'company', 'total_amount', 'due_date', 'items']
) AS invoice_data;


-- ============================================================
-- EXAMPLE 4: Extract from Multiple Rows (Table Data)
-- Process a batch of unstructured records.
-- ============================================================

CREATE OR REPLACE TEMPORARY TABLE job_postings (
    posting_id INT,
    raw_text STRING
);

INSERT INTO job_postings VALUES
(1, 'Senior Data Engineer at Snowflake Inc. Location: San Mateo, CA.
     Salary: $180,000-$220,000. Required: 5+ years experience with SQL,
     Python, and cloud platforms. Remote-friendly.'),
(2, 'Marketing Manager at Nike. Location: Portland, OR.
     Salary: $120,000-$150,000. Required: 7+ years in digital marketing,
     team leadership experience. Hybrid work model.'),
(3, 'Junior Frontend Developer at Spotify. Location: Stockholm, Sweden.
     Salary: €45,000-€55,000. Required: React, TypeScript, 1-2 years
     experience. Fully remote available.');

-- Extract structured fields from each posting
SELECT
    posting_id,
    AI_EXTRACT(
        raw_text,
        ['job_title', 'company', 'location', 'salary_range', 'experience_required', 'work_model']
    ) AS extracted
FROM job_postings;


-- ============================================================
-- EXAMPLE 5: Parse the JSON Output into Columns
-- Use dot notation to get individual fields.
-- ============================================================

SELECT
    posting_id,
    AI_EXTRACT(raw_text, ['job_title', 'company', 'location', 'salary_range']):job_title::STRING AS job_title,
    AI_EXTRACT(raw_text, ['job_title', 'company', 'location', 'salary_range']):company::STRING AS company,
    AI_EXTRACT(raw_text, ['job_title', 'company', 'location', 'salary_range']):location::STRING AS location,
    AI_EXTRACT(raw_text, ['job_title', 'company', 'location', 'salary_range']):salary_range::STRING AS salary
FROM job_postings;


-- ============================================================
-- EXAMPLE 6: Extract with Descriptive Prompts (Array of Arrays)
-- Give AI_EXTRACT more context about what each field means.
-- ============================================================

SELECT AI_EXTRACT(
    'Patient: Maria Garcia, DOB: 06/15/1985. Visited on 2025-04-01.
     Chief complaint: persistent headache for 3 days. BP: 140/90.
     Prescribed: Ibuprofen 400mg twice daily for 5 days.
     Follow-up in 2 weeks. Attending: Dr. Robert Lee, Neurology.',
    [['patient_name', 'Full name of the patient'],
     ['date_of_birth', 'Patient date of birth'],
     ['visit_date', 'Date of the medical visit'],
     ['complaint', 'Primary symptom or reason for visit'],
     ['blood_pressure', 'Blood pressure reading'],
     ['medication', 'Prescribed drug and dosage'],
     ['doctor', 'Attending physician name'],
     ['department', 'Medical department or specialty']]
) AS medical_record;


-- ============================================================
-- EXAMPLE 7: Extract from Staged Files (PDF, Images, etc.)
-- Use TO_FILE() to point to documents on a Snowflake stage.
-- ============================================================

-- NOTE: Adjust stage and file names for your environment

-- Extract from a PDF document
-- SELECT AI_EXTRACT(
--     file => TO_FILE('@my_stage', 'invoice_april.pdf'),
--     responseFormat => [
--         ['invoice_number', 'The invoice ID or number'],
--         ['vendor', 'Company that issued the invoice'],
--         ['total', 'Total amount due'],
--         ['due_date', 'Payment due date']
--     ]
-- ) AS pdf_extract;

-- Extract from a scanned image (receipt)
-- SELECT AI_EXTRACT(
--     file => TO_FILE('@my_stage', 'receipt_photo.jpg'),
--     responseFormat => [
--         ['store', 'Store or restaurant name'],
--         ['date', 'Transaction date'],
--         ['total', 'Total amount paid'],
--         ['payment_method', 'How it was paid']
--     ]
-- ) AS receipt_extract;


-- ============================================================
-- EXAMPLE 8: Batch Process Files from a Stage
-- Extract from every file in a stage directory.
-- ============================================================

-- NOTE: Uncomment and adjust for your environment
-- SELECT
--     RELATIVE_PATH,
--     AI_EXTRACT(
--         file => TO_FILE('@contracts_stage', RELATIVE_PATH),
--         responseFormat => ['client_name', 'contract_date', 'value', 'term_length']
--     ) AS contract_data
-- FROM DIRECTORY(@contracts_stage)
-- WHERE RELATIVE_PATH ILIKE '%.pdf';


-- ============================================================
-- EXAMPLE 9: Extract Contact Info from Business Cards
-- ============================================================

SELECT AI_EXTRACT(
    'Jane Wilson
     VP of Engineering
     TechCorp Solutions
     jane.wilson@techcorp.com
     +1 (415) 555-0142
     San Francisco, CA 94105
     linkedin.com/in/janewilson',
    ['name', 'title', 'company', 'email', 'phone', 'city', 'linkedin']
) AS business_card;


-- ============================================================
-- EXAMPLE 10: Extract and Filter (Find High-Value Invoices)
-- Combine AI_EXTRACT with WHERE clauses.
-- ============================================================

CREATE OR REPLACE TEMPORARY TABLE raw_invoices (
    doc_id INT,
    content STRING
);

INSERT INTO raw_invoices VALUES
(1, 'Invoice #1001 from CloudServ LLC. Total: $2,500. Due: 2025-05-01. Service: Data storage.'),
(2, 'Invoice #1002 from DataPipe Inc. Total: $15,750. Due: 2025-05-15. Service: ETL pipeline.'),
(3, 'Invoice #1003 from SecureNet. Total: $800. Due: 2025-04-30. Service: SSL certificates.'),
(4, 'Invoice #1004 from AnalyticsPro. Total: $42,000. Due: 2025-06-01. Service: Annual license.');

-- Extract and find invoices over $10,000
SELECT
    doc_id,
    AI_EXTRACT(content, ['invoice_number', 'vendor', 'total', 'service']) AS parsed,
    AI_EXTRACT(content, ['total']):total::STRING AS amount
FROM raw_invoices
WHERE AI_EXTRACT(content, ['total']):total::STRING ILIKE '%$1%'
   OR AI_EXTRACT(content, ['total']):total::STRING ILIKE '%$4%';


-- ============================================================
-- TIPS & BEST PRACTICES
-- ============================================================
--
-- 1. FIELD NAMES MATTER: Use clear, specific names.
--    Good: ['invoice_number', 'total_amount', 'due_date']
--    Bad:  ['field1', 'field2', 'field3']
--
-- 2. DESCRIPTIVE FORMAT: Use [['name', 'description']] when
--    simple field names aren't enough context.
--
-- 3. SUPPORTED FILES: PDF, PNG, DOC, DOCX, PPT, JPEG, JPG,
--    EML, HTM, HTML, TEXT, TXT, TIF, TIFF, BMP, GIF, WEBP, MD
--
-- 4. CONTEXT WINDOW: Up to 128,000 tokens input. Large PDFs
--    work fine, but keep field lists reasonable (under 50).
--
-- 5. OUTPUT: Always returns a JSON object (VARIANT type).
--    Use :field_name::TYPE to cast to specific columns.
--
-- 6. vs AI_COMPLETE: Use AI_EXTRACT when you know exactly
--    which fields you need. Use AI_COMPLETE for open-ended
--    questions about documents.
--
-- 7. COST: Cheaper than AI_COMPLETE for extraction tasks
--    because it uses a purpose-built model (arctic-extract).
--
-- 8. FINE-TUNING: You can fine-tune arctic-extract for
--    domain-specific extraction if default accuracy is low.
-- ============================================================
