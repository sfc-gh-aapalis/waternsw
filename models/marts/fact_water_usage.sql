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

enriched as (
    select
        du.account_id,
        du.meter_id,
        du.reading_date,
        date_trunc('month', du.reading_date) as reading_month,
        case when month(du.reading_date) >= 7
            then year(du.reading_date)::varchar || '-' || (year(du.reading_date)+1)::varchar
            else (year(du.reading_date)-1)::varchar || '-' || year(du.reading_date)::varchar
        end as financial_year,
        l.licence_id,
        l.catchment_code,
        l.holder_name,
        du.daily_usage_ml,
        count(*) over (partition by du.account_id, du.reading_date) as reading_count,
        l.extraction_limit_ml_per_year,
        a.allocation_ml as annual_allocation_ml
    from daily_usage du
    join {{ source('silver_source', 'WAS_ACCOUNTS_VALIDATED') }} acc
        on acc.account_id = du.account_id
    join {{ source('silver_source', 'WLS_LICENCES_VALIDATED') }} l
        on acc.account_id = 'ACC' || lpad(replace(l.licence_id, 'WAL', ''), 9, '0')
    left join {{ source('silver_source', 'WLS_ALLOCATIONS_VALIDATED') }} a
        on a.licence_id = l.licence_id
)

select
    account_id,
    meter_id,
    reading_date,
    reading_month,
    financial_year,
    licence_id,
    catchment_code,
    holder_name,
    daily_usage_ml,
    reading_count,
    0 as flagged_readings,
    extraction_limit_ml_per_year,
    annual_allocation_ml,
    sum(daily_usage_ml) over (
        partition by account_id,
        case when month(reading_date) >= 7 then year(reading_date) else year(reading_date)-1 end
        order by reading_date
    ) as ytd_usage_ml,
    case when annual_allocation_ml > 0 then
        round((sum(daily_usage_ml) over (
            partition by account_id,
            case when month(reading_date) >= 7 then year(reading_date) else year(reading_date)-1 end
            order by reading_date
        ) / annual_allocation_ml) * 100, 2)
    else null end as ytd_allocation_used_pct
from enriched
