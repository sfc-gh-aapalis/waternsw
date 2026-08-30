with daily_usage as (
    select
        account_id,
        meter_id,
        reading_date,
        sum(volume_ml) as daily_usage_ml
    from {{ ref('stg_metered_usage') }}
    where is_usable = true
    group by account_id, meter_id, reading_date
),

exceedance_calc as (
    select
        du.account_id,
        du.meter_id,
        du.reading_date,
        du.daily_usage_ml,
        l.licence_id,
        l.licence_number,
        l.holder_name,
        l.catchment_code,
        a.allocation_ml as annual_allocation_ml,
        a.allocation_ml / 365 as daily_allocation_ml,
        round((du.daily_usage_ml / nullif(a.allocation_ml / 365, 0) - 1) * 100, 2) as daily_exceedance_pct
    from daily_usage du
    join {{ source('silver_source', 'WAS_ACCOUNTS_VALIDATED') }} acc
        on acc.account_id = du.account_id
    join {{ source('silver_source', 'WLS_LICENCES_VALIDATED') }} l
        on acc.account_id = 'ACC' || lpad(replace(l.licence_id, 'WAL', ''), 9, '0')
    join {{ source('silver_source', 'WLS_ALLOCATIONS_VALIDATED') }} a
        on a.licence_id = l.licence_id
)

select
    {{ dbt_utils.generate_surrogate_key(['account_id', 'reading_date', 'licence_id']) }} as compliance_event_id,
    account_id,
    licence_id,
    licence_number,
    holder_name,
    catchment_code,
    reading_date as event_date,
    daily_usage_ml,
    daily_allocation_ml,
    annual_allocation_ml,
    daily_exceedance_pct,
    case
        when daily_exceedance_pct > 50 then 'CRITICAL'
        when daily_exceedance_pct > 25 then 'HIGH'
        when daily_exceedance_pct > 10 then 'MODERATE'
        else 'LOW'
    end as severity,
    case
        when daily_exceedance_pct > 10 then true
        else false
    end as requires_investigation
from exceedance_calc
where daily_exceedance_pct > 0
