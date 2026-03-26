{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='vendor_key',
        on_schema_change='append_new_columns',
        tags=['cdm', 'dimension', 'vendor']
    )
}}

with netsuite_entities as (
    select
        -- Keys
        {{ add_source_system_column('netsuite') }},
        vendor_id,
        
        -- Attributes
        entity_title as vendor_name, -- Logic: altname / firstname+lastname        
        -- Metadata
        last_modified_date        
    from {{ source('gold_netsuite', 'dim_entity') }}
    where lower(entity_type) = 'vendor'
    
    {% if is_incremental() %}
    and last_modified_date > (
        select coalesce(max(last_modified_date), '1900-01-01'::timestamp)
        from {{ this }}
        where source_system = 'NETSUITE'
    )
    {% endif %}
),

sage_entities as (
    select
        -- Keys
        {{ add_source_system_column('sage') }},
        cast(entity_id as varchar) as vendor_id, -- Maps to Natural Code
        
        -- Attributes
        entity_name as vendor_name,        
        -- Metadata
        last_modified_date        
    from {{ source('gold_sage', 'dim_entity') }}
    where lower(entity_type) = 'vendor'
    
    {% if is_incremental() %}
    and last_modified_date > (
        select coalesce(max(last_modified_date), '1900-01-01'::timestamp)
        from {{ this }}
        where source_system = 'SAGE'
    )
    {% endif %}
),

unioned as (
    select * from netsuite_entities
    union all
    select * from sage_entities
),

final as (
    select
        -- Primary Key
        {{ generate_finance_key(['vendor_id']) }} as vendor_key,
        
        -- Source System Info
        source_system,
        
        -- Natural Keys
        vendor_id,
        
        -- Attributes
        vendor_name,
        

        -- Audit Columns
        last_modified_date,
        {{ get_audit_columns() }}
        
    from unioned
)

select * from final