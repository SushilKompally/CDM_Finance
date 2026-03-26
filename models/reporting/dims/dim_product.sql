{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='product_key',
        on_schema_change='append_new_columns',
        tags=['cdm', 'dimension', 'product']
    )
}}

with netsuite_products as (
    select
        -- Keys
        {{ generate_finance_key(['ITEM_ID']) }} as product_key,
        {{ add_source_system_column('netsuite') }},
        cast(ITEM_ID as varchar) as product_id,
        
        -- Attributes
        ITEM_NAME as product_name,
        ITEM_TYPE as product_type,
        
        -- Placeholder for User Input columns
        null as product_category,
        null as product_subcategory,
        
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

sage_products as (
    select
        -- Keys
        {{ generate_finance_key(['ITEM_ID']) }} as product_key,
        {{ add_source_system_column('sage') }},
        cast(ITEM_ID as varchar) as product_id,
        
        -- Attributes
        ITEM_NAME as product_name,
        ITEM_TYPE as product_type,
        
        -- Placeholder for User Input columns
        null as product_category,
        null as product_subcategory,
        
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
    select * from netsuite_products
    union all
    select * from sage_products
),

final as (
    select
        -- Primary Key
        product_key,
        
        -- Source System Info
        source_system,
        
        -- Natural Keys
        product_id,
        
        -- Attributes
        product_name,
        product_type,
        product_category,
        product_subcategory,
        
        -- Audit Columns
        last_modified_date,
        {{ get_audit_columns() }}
        
    from unioned
)

select * from final