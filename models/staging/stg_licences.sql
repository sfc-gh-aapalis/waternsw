{{ config(materialized='view') }}

select
    licence_id,
    licence_number,
    holder_name,
    holder_abn,
    licence_type,
    water_source,
    catchment_code,
    catchment_name,
    water_sharing_plan,
    regulatory_zone,
    share_component_ml,
    extraction_limit_ml_per_year,
    current_fy,
    current_allocation_pct,
    current_allocation_ml,
    status,
    issue_date,
    expiry_date
from {{ source('silver_source', 'WLS_LICENCES_VALIDATED') }}
