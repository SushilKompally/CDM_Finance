{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='department_key',
        on_schema_change='append_new_columns',
        tags=['cdm', 'dimension', 'department']
    )
}}

with netsuite_departments as (
    select
        cast(department_id as varchar) as department_id,
        {{ add_source_system_column('netsuite') }},
        department_name,
        department_full_name as full_hierarchy_name,
        cast(parent as varchar) as parent_department_id,
        last_modified_date
        
    from {{ source('gold_netsuite', 'dim_departments') }}
    
    {% if is_incremental() %}
    where last_modified_date > (
        select coalesce(max(last_modified_date), '1900-01-01'::timestamp)
        from {{ this }}
        where source_system = 'NETSUITE'
    )
    {% endif %}
),

sage_departments as (
    select
        department_id,
        {{ add_source_system_column('sage') }},
        department_name,
        department_name as full_hierarchy_name,
        parent as parent_department_id,
        last_modified_date
        
    from {{ source('gold_sage', 'dim_department') }}
    
    {% if is_incremental() %}
    where last_modified_date > (
        select coalesce(max(last_modified_date), '1900-01-01'::timestamp)
        from {{ this }}
        where source_system = 'SAGE'
    )
    {% endif %}
),

unioned as (
    select * from netsuite_departments
    union all
    select * from sage_departments
),

final as (
    select
        -- Primary Key
        {{ generate_finance_key(['department_id']) }} as department_key,
        
        -- Source System
        source_system,
        
        -- Natural Key
        department_id,
        
        -- Attributes
        department_name,
        full_hierarchy_name,
        parent_department_id,
        {{ generate_finance_key(['source_system', 'parent_department_id']) }} as parent_department_key,
        
        -- Audit Columns
        last_modified_date,
        {{ get_audit_columns() }}
        
    from unioned
)

select * from final