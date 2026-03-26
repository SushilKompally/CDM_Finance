{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='item_key',
        on_schema_change='append_new_columns',
        tags=['cdm', 'dimension', 'item']
    )
}}

with netsuite_items as (
    select
        -- Keys
        {{ add_source_system_column('netsuite') }},
        cast(item_id as varchar) as item_id,
        
        -- Attributes
        item_name,
        item_type,
        
        -- Metadata
        last_modified_date
    from {{ source('gold_netsuite', 'dim_item') }}
    
    {% if is_incremental() %}
    where last_modified_date > (
        select coalesce(max(last_modified_date), '1900-01-01'::timestamp)
        from {{ this }}
        where source_system = 'NETSUITE'
    )
    {% endif %}
),

sage_items as (
    select
        -- Keys
        {{ add_source_system_column('sage') }},
        cast(item_id as varchar) as item_id,
        
        -- Attributes
        item_name,
        item_type,
        
        -- Metadata
        last_modified_date
        
    from {{ source('gold_sage', 'dim_item') }}
    
    {% if is_incremental() %}
    where last_modified_date > (
        select coalesce(max(last_modified_date), '1900-01-01'::timestamp)
        from {{ this }}
        where source_system = 'SAGE'
    )
    {% endif %}
),

unioned as (
    select * from netsuite_items
    union all
    select * from sage_items
),

final as (
    select
        -- Primary Key
        {{ generate_finance_key(['source_system', 'item_id']) }} as item_key,
        
        -- Source System Info
        source_system,
        
        -- Natural Keys
        item_id,
        
        -- Attributes
        item_name,
        item_type,
        
        -- Audit Columns
        last_modified_date,
        {{ get_audit_columns() }}
        
    from unioned
)

select * from final