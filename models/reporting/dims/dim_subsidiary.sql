{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='subsidiary_key',
        on_schema_change='append_new_columns',
        tags=['cdm', 'dimension', 'subsidiary']
    )
}}

with netsuite_subsidiaries as (
    select
        {{ generate_finance_key(['subsidiary_id']) }} as subsidiary_key,
        {{ add_source_system_column('netsuite') }},
        cast(subsidiary_id as varchar) as subsidiary_id,
        subsidiary_name,
        '1900-01-01'::timestamp as last_modified_date
    from {{ source('gold_netsuite', 'dim_subsidiary') }}
    
    {% if is_incremental() %}
    where last_modified_date > (
        select coalesce(max(last_modified_date), '1900-01-01'::timestamp)
        from {{ this }}
        where source_system = 'NETSUITE'
    )
    {% endif %}
),

sage_subsidiaries as (
    select
        {{ generate_finance_key(['subsidiary_id']) }} as subsidiary_key,
        {{ add_source_system_column('sage') }},
        cast(subsidiary_id as varchar) as subsidiary_id,
        subsidiary_title as subsidiary_name,
        last_modified_date
        
    from {{ source('gold_sage', 'dim_subsidiary') }}
    
    {% if is_incremental() %}
    where last_modified_date > (
        select coalesce(max(last_modified_date), '1900-01-01'::timestamp)
        from {{ this }}
        where source_system = 'SAGE'
    )
    {% endif %}
),

unioned as (
    select * from netsuite_subsidiaries
    union all
    select * from sage_subsidiaries
),

final as (
    select
        -- Primary Key
        subsidiary_key,
        
        -- Source System
        source_system,
        
        -- Natural Key
        subsidiary_id,
        
        -- Attributes
        subsidiary_name,
        
        -- Audit Columns
        last_modified_date,
        {{ get_audit_columns() }}
        
    from unioned
)

select * from final