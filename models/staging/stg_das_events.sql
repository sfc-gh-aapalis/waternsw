{{ config(materialized='view') }}

with deduped as (
    select *
    from {{ source('bronze', 'DAS_EVENTS_RAW') }}
    qualify row_number() over (partition by event_id order by _cdc_timestamp desc) = 1
)

select
    event_id,
    sensor_id,
    event_timestamp,
    date_trunc('day', event_timestamp) as event_date,
    event_type,
    event_value,
    event_unit,
    quality_code,
    _cdc_timestamp as ingested_at,
    case
        when quality_code in ('A', 'B') then 'VALIDATED'
        when quality_code = 'E' then 'ESTIMATED'
        when quality_code = 'S' then 'SUSPECT'
        else 'UNKNOWN'
    end as validation_status
from deduped
