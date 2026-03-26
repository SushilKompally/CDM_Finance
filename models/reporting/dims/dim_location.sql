{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='location_key',
        on_schema_change='append_new_columns',
        tags=['cdm', 'dimension', 'location']
    )
}}

with netsuite_locations as (
    select
        -- Keys
        {{ add_source_system_column('netsuite') }},
        cast(LOCATION_ID as varchar) as location_id,
        
        -- Attributes
        LOCATION_NAME as location_name,
        
        -- Hierarchy
        cast(PARENT as varchar) as parent_location_key,
        
        -- Metadata
        last_modified_date        
    from {{ source('gold_netsuite', 'dim_locations') }}
    
    {% if is_incremental() %}
    where last_modified_date > (
        select coalesce(max(last_modified_date), '1900-01-01'::timestamp)
        from {{ this }}
        where source_system = 'NETSUITE'
    )
    {% endif %}
),

sage_locations as (
    select
        -- Keys
        {{ add_source_system_column('sage') }},
        cast(LOCATION_ID as varchar) as location_id,
        
        -- Attributes
        location_full_name as location_name,
        
        -- Hierarchy
        cast(PARENT as varchar) as parent_location_key,
        
        -- Metadata
        last_modified_date        
    from {{ source('gold_sage', 'dim_location') }}
    
    {% if is_incremental() %}
    where last_modified_date > (
        select coalesce(max(last_modified_date), '1900-01-01'::timestamp)
        from {{ this }}
        where source_system = 'SAGE'
    )
    {% endif %}
),

unioned as (
    select * from netsuite_locations
    union all
    select * from sage_locations
),

final as (
    select
        -- Primary Key
        {{ generate_finance_key(['location_id']) }} as location_key,
        
        -- Source System
        source_system,        
        -- Natural Keys
        location_id,
        
        -- Attributes
        location_name,
        
        -- Hierarchy
        parent_location_key,
        
        -- Audit Columns
        last_modified_date,
        {{ get_audit_columns() }}
        
    from unioned
)

select * from final