select
    catchment_code,
    catchment_name,
    water_sharing_plan,
    regulatory_zone,
    area_km2,
    centroid_lat,
    centroid_lng,
    h3_index_res4
from {{ source('gold_source', 'DIM_CATCHMENTS') }}
