{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='entity_key',
        on_schema_change='append_new_columns',
        tags=['cdm', 'dimension', 'entity']
    )
}}

with netsuite_entities as (
    select
        -- Keys
        {{ add_source_system_column('netsuite') }},
        cast(entity_id as varchar) as entity_id,
        
        -- Attributes
        coalesce(concat(first_name, ' ', last_name), entity_title) as entity_name, -- Logic: altname / firstname+lastname
        entity_type,
        
        -- Foreign Keys
        cast(employee_id as varchar) as employee_id,
        cast(customer_id as varchar) as customer_id,
        cast(vendor_id as varchar) as vendor_id,
        
        -- Metadata
        last_modified_date        
    from {{ source('gold_netsuite', 'dim_entity') }}
    
    {% if is_incremental() %}
    where last_modified_date > (
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
        cast(entity_id as varchar) as entity_id, -- Maps to Natural Code
        
        -- Attributes
        entity_name,
        entity_type, -- Maps to STATUS / TYPE
        
        -- Logic to separate IDs based on entity_type
        case when lower(entity_type) = 'employee' then cast(entity_id as varchar) else null end as employee_id,
        case when lower(entity_type) = 'customer' then cast(entity_id as varchar) else null end as customer_id,
        case when lower(entity_type) = 'vendor'   then cast(entity_id as varchar) else null end as vendor_id,
        
        -- Metadata
        last_modified_date        
    from {{ source('gold_sage', 'dim_entity') }}
    
    {% if is_incremental() %}
    where last_modified_date > (
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
        {{ generate_finance_key(['entity_id']) }} as entity_key,
        
        -- Source System Info
        source_system,
        
        -- Natural Keys
        entity_id,
        
        -- Attributes
        entity_name,
        entity_type,
        
        -- Separated IDs
        employee_id,
        customer_id,
        vendor_id,
        
        -- Audit Columns
        last_modified_date,
        {{ get_audit_columns() }}
        
    from unioned
)

select * from final