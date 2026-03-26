{{
    config(
        materialized="incremental",
        incremental_strategy="merge",
        unique_key="currency_key",
        on_schema_change="append_new_columns",
        tags=["cdm", "dimension", "currency"],
    )
}}

with netsuite_currencies as (
    select
        -- Keys
        {{ add_source_system_column("netsuite") }},
        cast(currency_id as varchar) as currency_id,

        -- Attributes
        currency_name,
        currency_symbol,
        is_base_currency,

        -- Metadata
        last_modified_date
    from {{ source("gold_netsuite", "dim_currency") }}

    {% if is_incremental() %}
        where
            last_modified_date > (
                select coalesce(max(last_modified_date), '1900-01-01'::timestamp)
                from {{ this }}
                where source_system = 'NETSUITE'
            )
    {% endif %}
),

sage_currencies as (
    select
        -- Keys
        {{ add_source_system_column("sage") }},
        cast(currency_id as varchar) as currency_id,

        -- Attributes
        currency_name,
        symbol as currency_symbol,
        null::boolean as is_base_currency, -- Placeholder to match NetSuite

        -- Metadata
        updated_at as last_modified_date -- Aliased to match NetSuite
    from {{ source("gold_sage", "dim_currency") }}

    {% if is_incremental() %}
        where
            updated_at > (
                select coalesce(max(last_modified_date), '1900-01-01'::timestamp)
                from {{ this }}
                where source_system = 'SAGE'
            )
    {% endif %}
),

unioned as (
    select * from netsuite_currencies
    union all
    select * from sage_currencies
),

final as (
    select
        -- Primary Key
        {{ generate_finance_key(["currency_id"]) }} as currency_key,

        -- Source System Info
        source_system,

        -- Natural Keys
        currency_id,

        -- Attributes
        currency_name,
        currency_symbol,
        is_base_currency,

        -- Audit Columns
        last_modified_date,
        {{ get_audit_columns() }}

    from unioned
)

select * from final