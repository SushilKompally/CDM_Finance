{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='employee_key',
        on_schema_change='append_new_columns',
        tags=['cdm', 'dimension', 'employee']
    )
}}

with netsuite_employees as (
    select
        -- Keys
        {{ add_source_system_column('netsuite') }},
        cast(EMPLOYEE_ID as varchar) as employee_id,
        
        -- Attributes
        JOB_DESCRIPTION as title,
        EMAIL as email,
        
        -- Foreign Keys
        cast(DEPARTMENT_ID as varchar) as department_key,
        cast(CLASS_ID as varchar) as class_key,
        cast(LOCATION_ID as varchar) as location_key,
        cast(SUBSIDIARY as varchar) as subsidiary_key,
        
        -- Status and Audit
         case 
            when upper(IS_INACTIVE) = 'true' then true 
            else false 
        end as is_inactive,
        last_modified_date
        
    from {{ source('gold_netsuite', 'dim_employees') }}
    
    {% if is_incremental() %}
    where last_modified_date > (
        select coalesce(max(last_modified_date), '1900-01-01'::timestamp)
        from {{ this }}
        where source_system = 'NETSUITE'
    )
    {% endif %}
),

sage_employees as (
    select
        -- Keys
        {{ add_source_system_column('sage') }},
        cast(EMPLOYEE_ID as varchar) as employee_id,
        
        -- Attributes
        employee_name as title,
        EMAIL as email,
        
        -- Foreign Keys
        cast(DEPARTMENT_ID as varchar) as department_key,
        CLASS_ID as class_key,
        cast(LOCATION_ID as varchar) as location_key,
        cast(SUBSIDIARY as varchar) as subsidiary_key,
        
        -- Status and Audit
        case 
            when upper(IS_INACTIVE) = 'ACTIVE' then true 
            else false 
        end as is_inactive,
        last_modified_date
        
    from {{ source('gold_sage', 'dim_employee') }}
    
    {% if is_incremental() %}
    where last_modified_date > (
        select coalesce(max(last_modified_date), '1900-01-01'::timestamp)
        from {{ this }}
        where source_system = 'SAGE'
    )
    {% endif %}
),

unioned as (
    select * from netsuite_employees
    union all
    select * from sage_employees
),

final as (
    select
        -- Primary Key
        {{ generate_finance_key(['employee_id']) }} as employee_key,
        
        -- Source System
        source_system,
        
        -- Natural Keys
        employee_id,
        
        -- Attributes
        title,
        email,
        
        -- Foreign Keys
        department_key,
        class_key,
        location_key,
        subsidiary_key,
        
        -- Flags
        is_inactive,
        
        -- Audit Columns
        last_modified_date,
        {{ get_audit_columns() }}
        
    from unioned
)

select * from final