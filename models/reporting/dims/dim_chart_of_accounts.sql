{{
    config(
        materialized="incremental",
        incremental_strategy="merge",
        unique_key="account_key",
        on_schema_change="append_new_columns",
        tags=["cdm", "dimension", "account"],
    )
}}

with
    netsuite_accounts as (
        select
            -- Keys
            {{ generate_finance_key(["account_id"]) }} as account_key,
            {{ add_source_system_column("netsuite") }},
            cast(account_id as varchar) as account_id,

            -- Account Attributes
            account_number,
            account_name,
            account_type,
            account_description as description,
            display_name,

            -- Hierarchy
            cast(account_parent_id as varchar) as parent_account_id,
            display_name_with_hierarchy as full_hierarchy_name,

            -- Foreign Keys
            cast(department_id as varchar) as department_id,
            cast(class_id as varchar) as class_id,
            cast(subsidiary_id as varchar) as subsidiary_id,
            null as product_id,

            -- Metadata
            last_modified_date
        from {{ source("gold_netsuite", "dim_chartofaccounts") }}

        {% if is_incremental() %}
            where
                last_modified_date > (
                    select coalesce(max(last_modified_date), '1900-01-01'::timestamp)
                    from {{ this }}
                    where source_system = 'NETSUITE'
                )
        {% endif %}
    )
    ,

    sage_accounts as (

        select
            -- Keys
            {{ generate_finance_key(["acc.account_number"]) }} as account_key,
            {{ add_source_system_column("sage") }},
            cast(acc.account_id as varchar) as account_id,

            -- Account Attributes
            acc.account_number,
            acc.account_name as account_name,
            acc.account_type,
            acc.category as description,
            acc.account_name as display_name,

            -- Hierarchy
            cast(acc.alternative_account as varchar) as parent_account_id,
            acc.account_name as full_hierarchy_name,

            -- No foreign keys here (NOT RELATED IN SOURCE)
            null as department_id,
            null as class_id,
            null as subsidiary_id,
            null as product_id,

            acc.last_modified_date

        from {{ source("gold_sage", "dim_chartofaccounts") }} acc

        {% if is_incremental() %}
            where
                acc.last_modified_date > (
                    select coalesce(max(last_modified_date), '1900-01-01'::timestamp)
                    from {{ this }}
                    where source_system = 'SAGE'
                )
        {% endif %}
    ),

    unioned as (
        select *
        from netsuite_accounts
        union all
        select *
        from sage_accounts
    ),

    final as (

        select
            -- Primary Key
            u.account_key,

            -- Source System
            u.source_system,

            -- Natural Keys
            u.account_id,
            u.account_number,

            -- Attributes
            u.account_name,
            u.account_type,
            u.description,
            u.display_name,

            -- Hierarchy
            u.parent_account_id,
            u.full_hierarchy_name,

            -- Foreign Keys
            u.department_id,
            u.class_id,
            u.subsidiary_id,
            u.product_id,

            -- Mapping Columns (from map_coa_reporting)
            m.gaap_mapping_l1 as gaapmappingl1,
            m.gaap_mapping_l2 as gaapmappingl2,
            m.gaap_mapping_l3 as gaapmappingl3,
            m.gaap_mapping_l4 as gaapmappingl4,
            m.cashflow_l1 as cashflowl1,
            m.cashflow_l2 as cashflowl2,
            m.cashflow_l3 as cashflowl3,
            m.pandl_multiplier as pandlmultiplier,
            m.budget_multiplier as budgetmultiplier,
            m.debt_mapping as debtmapping,

            -- Audit Columns
            u.last_modified_date,
            {{ get_audit_columns() }}

        from unioned u

        left join
            {{ source("coa_mapping", "map_coa_reporting") }} m
            on u.account_id = m.account_id
            and upper(u.source_system) = upper(m.source_system)
            and current_date between m.effective_from and m.effective_to
    )

select *
from final
