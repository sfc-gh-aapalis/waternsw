{{ config(materialized='view') }}

select
    account_id,
    customer_name,
    customer_email,
    customer_phone,
    property_address,
    lot_dp,
    latitude,
    longitude,
    catchment_code,
    account_status,
    created_at,
    updated_at,
    ingested_at
from {{ source('silver_source', 'WAS_ACCOUNTS_VALIDATED') }}
