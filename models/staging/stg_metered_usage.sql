{{ config(materialized='view') }}

with deduped as (
    select *
    from {{ source('bronze', 'WAS_METERED_USAGE_RAW') }}
    qualify row_number() over (partition by reading_id order by _cdc_timestamp desc) = 1
)

select
    reading_id,
    account_id,
    meter_id,
    reading_timestamp,
    date_trunc('hour', reading_timestamp) as reading_hour,
    date_trunc('day', reading_timestamp) as reading_date,
    volume_litres,
    volume_litres / 1000000 as volume_ml,
    reading_type,
    quality_flag,
    source_system,
    created_at,
    _cdc_timestamp as ingested_at,
    case
        when volume_litres < 0 then 'INVALID_NEGATIVE'
        when volume_litres > 50000000 then 'SUSPECT_HIGH'
        when quality_flag = 'SUSPECT' then 'FLAGGED_AT_SOURCE'
        else 'VALIDATED'
    end as validation_status,
    case
        when quality_flag = 'SUSPECT' or volume_litres < 0 then false
        else true
    end as is_usable
from deduped
