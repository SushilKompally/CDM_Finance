{{
    config(
        materialized="incremental",
        incremental_strategy="merge",
        unique_key="ebitda_adjustment_key",
        on_schema_change="append_new_columns",
        tags=["cdm", "fact", "budget"],
    )
}}

with
    netsuite_budget as (
        select
            -- Keys
            {{
                dbt_utils.generate_surrogate_key(
                    [
                        "'NETSUITE'",
                        "cast(ACCOUNT_ID as varchar)",
                        "cast(SUBSIDIARY_ID as varchar)",
                        "cast(POSTING_PERIOD_ID as varchar)",
                    ]
                )
            }} as ebitda_adjustment_key,
            {{ add_source_system_column("netsuite") }},

            -- Foreign Keys
            cast(subsidiary_id as varchar) as subsidiarykey,
            cast(account_id as varchar) as chartofaccountkey,
            cast(class_id as varchar) as classkey,
            cast(department_id as varchar) as departmentkey,
            cast(location_id as varchar) as locationkey,
            cast(posting_period_id as varchar) as accountingperiodkey,
            cast(currency_id as varchar) as currency,
            cast(entity_id as varchar) as customerkey,
            cast(item_id as varchar) as itemkey,
            cast(item_id as varchar) as productkey,

            -- Adjustment Details
            null as adjustment_type,
            null as adjustment_description,
            null as amount,
            null as converted_amount,
            -- Metadata
            last_modified_date

        from {{ source("gold_netsuite", "fact_transaction") }}  -- Sourced from fact_transaction

        {% if is_incremental() %}
            where
                last_modified_date > (
                    select coalesce(max(last_modified_date), '1900-01-01'::timestamp)
                    from {{ this }}
                    where source_system = 'NETSUITE'
                )
        {% endif %}
    ),

    sage_budget as (
        select
            -- Keys
            {{
                dbt_utils.generate_surrogate_key(
                    [
                        "'SAGE'",
                        "cast(ACCOUNT_ID as varchar)",
                        "cast(SUBSIDIARY_ID as varchar)",
                        "cast(REPORTING_PERIOD_ID as varchar)",
                    ]
                )
            }} as ebitda_adjustment_key,
            {{ add_source_system_column("sage") }},

            -- Foreign Keys
            cast(subsidiary_id as varchar) as subsidiarykey,
            cast(account_id as varchar) as chartofaccountkey,
            cast(classid as varchar) as classkey,
            cast(department_id as varchar) as departmentkey,
            cast(location_id as varchar) as locationkey,
            cast(reporting_period_id as varchar) as accountingperiodkey,
            cast(currency_id as varchar) as currency,
            cast(customer_id as varchar) as customerkey,
            cast(itemid as varchar) as itemkey,
            cast(itemid as varchar) as productkey,

             -- Adjustment Details
            null as adjustment_type,
            null as adjustment_description,
            null as amount,
            null as converted_amount,

            -- Metadata
            last_modified_date

        from {{ source("gold_sage", "fact_transaction") }}  -- Sourced from fact_transaction

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
        from netsuite_budget
        union all
        select *
        from sage_budget
    ),

    final as (
        select
            -- Primary Key
            ebitda_adjustment_key,

            -- Source System Info
            source_system,
            ebitda_adjustment_key as adjustment_id,

            -- Foreign Keys
            subsidiarykey as subsidiary_key,
            chartofaccountkey as chart_of_account_key,
            classkey as class_key,
            departmentkey as department_key,
            locationkey as location_key,
            accountingperiodkey as accounting_period_key,
            currency,
            customerkey,
            itemkey,
            productkey,

             -- Adjustment Details
            adjustment_type,
            adjustment_description,
            amount,
            converted_amount,

            -- Audit Columns
            last_modified_date,
            {{ get_audit_columns() }}

        from unioned
    )

select *
from final
