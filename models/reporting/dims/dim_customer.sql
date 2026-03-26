{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='customer_key',
        on_schema_change='append_new_columns',
        tags=['cdm', 'dimension', 'customer']
    )
}}

with netsuite_customers as (
    select
        cast(ent.entity_id as varchar) as customer_id,
        {{ add_source_system_column('netsuite') }},
        ent.ENTITY_TITLE as customer_name,
        ent.entity_type as customer_type,
        null as payment_plan,
        ft.net_amount as annual_revenue,
        ent.last_modified_date
        
    from {{ source('gold_netsuite', 'dim_entity') }} ent
    left join {{ source('gold_netsuite', 'fact_transaction') }} ft 
        on cast(ent.CUSTOMER_ID as varchar) = cast(ft.entity_id as varchar)
    where lower(ent.entity_type) = 'customer'
    
    {% if is_incremental() %}
    and ent.last_modified_date > (
        select coalesce(max(last_modified_date), '1900-01-01'::timestamp)
        from {{ this }}
        where source_system = 'NETSUITE'
    )
    {% endif %}
),

sage_customers as (
    select
        customer_id,
        {{ add_source_system_column('sage') }},
        customer_name,
        customer_type,
        null as payment_plan,
        null as annual_revenue,
        last_modified_date
        
    from {{ source('gold_sage', 'dim_customer') }}
    
    {% if is_incremental() %}
    where last_modified_date > (
        select coalesce(max(last_modified_date), '1900-01-01'::timestamp)
        from {{ this }}
        where source_system = 'SAGE'
    )
    {% endif %}
),

unioned as (
    select * from netsuite_customers
    union all
    select * from sage_customers
),

final as (
    select
        -- Primary Key
        {{ generate_finance_key(['source_system', 'customer_id']) }} as customer_key,
        
        -- Source System
        source_system,
        
        -- Natural Key
        customer_id,
        
        -- Attributes
        customer_name,
        customer_type,
        payment_plan,
        
        -- Audit Columns
        last_modified_date,
        {{ get_audit_columns() }}
        
    from unioned
)

select * from final