{{
    config(
        materialized="incremental",
        incremental_strategy="merge",
        unique_key="class_key",
        on_schema_change="append_new_columns",
        tags=["cdm", "dimension", "class"],
    )
}}

with
    netsuite_classes as (
        select
            -- Keys
            {{ add_source_system_column("netsuite") }},
            cast(class_id as varchar) as class_id,

            -- Attributes
            class_name,

            -- Metadata
            last_modified_date
        from {{ source("gold_netsuite", "dim_classification") }}

        {% if is_incremental() %}
            where
                last_modified_date > (
                    select coalesce(max(last_modified_date), '1900-01-01'::timestamp)
                    from {{ this }}
                    where source_system = 'NETSUITE'
                )
        {% endif %}
    ),

    sage_classes as (
        select
            -- Keys
            {{ add_source_system_column("sage") }},
            cast(class_id as varchar) as class_id,

            -- Attributes
            class_name as class_name,

            -- Metadata
            last_modified_date
        from {{ source("gold_sage", "dim_classification") }}

        {% if is_incremental() %}
            where
                last_modified_date > (
                    select coalesce(max(last_modified_date), '1900-01-01'::timestamp)
                    from {{ this }}
                    where source_system = 'SAGE'
                )
        {% endif %}
    ),

    unioned as (
        select *
        from netsuite_classes
        union all
        select *
        from sage_classes
    ),

    final as (
        select
            -- Primary Key
            {{ generate_finance_key(["class_id"]) }} as class_key,

            -- Source System Info
            source_system,

            -- Natural Keys
            class_id,

            -- Attributes
            class_name,

            -- Audit Columns
            last_modified_date,
            {{ get_audit_columns() }}

        from unioned
    )

select *
from final
