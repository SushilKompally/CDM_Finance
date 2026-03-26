{{
    config(
        materialized="incremental",
        incremental_strategy="merge",
        unique_key="FinanceTransactionKey",
        on_schema_change="append_new_columns",
        tags=["cdm", "fact", "transaction"],
    )
}}

with
    netsuite_transactions as (
        select
            -- Keys
            {{
                dbt_utils.generate_surrogate_key(
                    [
                        "'NETSUITE'",
                        "cast(TRANSACTION_ID as varchar)",
                        "cast(TRANSACTION_LINE_ID as varchar)",
                    ]
                )
            }} as financetransactionkey,
            {{ add_source_system_column("netsuite") }},
            cast(transaction_id as varchar)
            || '-'
            || cast(transaction_line_id as varchar) as transactionuniqueid,
            cast(transaction_id as varchar) as transactionid,
            cast(transaction_line_id as varchar) as transactionlineid,

            -- Foreign Keys
            cast(account_id as varchar) as chartofaccountkey,
            cast(class_id as varchar) as classkey,
            cast(item_id as varchar) as itemkey,
            cast(item_id as varchar) as productkey,
            cast(department_id as varchar) as departmentkey,
            cast(subsidiary_id as varchar) as subsidiarykey,
            cast(location_id as varchar) as locationkey,
            cast(entity_id as varchar) as entitykey,
            cast(entity_id as varchar) as customerkey,  -- Mapped from ENTITY_ID (customer)
            cast(entity_id as varchar) as vendorkey,  -- Mapped from ENTITY_ID (vendor)
            cast(posting_period_id as varchar) as accountingperiodkey,
            cast(currency_id as varchar) as currency,

            -- Dates
            cast(tran_date as date) as transactiondate,
            cast(start_date as date) as postingperioddate,
            cast(due_date as date) as duedate,
            cast(close_date as date) as closedate,

            -- Measures
            cast(amount as float) as amount,
            cast(converted_net_amount as float) as convertedamount,
            cast(amount_paid as float) as openamount,
            cast(quantity as float) as quantity,

            -- Attributes
            cast(transaction_type as varchar) as transactiontype,
            cast(accounting_line_type as varchar) as debitcreditflag,
            cast(transaction_status_id as varchar) as transactionstatus,
            cast(transaction_accounting_posting_flag as varchar) as postingflag,

            -- Metadata
            last_modified_date

        from {{ source("gold_netsuite", "fact_transaction") }}

        {% if is_incremental() %}
            where
                last_modified_date > (
                    select coalesce(max(last_modified_date), '1900-01-01'::timestamp)
                    from {{ this }}
                    where source_system = 'NETSUITE'
                )
        {% endif %}
    ),

    sage_transactions as (
        select
            -- Keys
            {{
                dbt_utils.generate_surrogate_key(
                    [
                        "'SAGE'",
                        "cast(TRAN_ID as varchar)",
                        "cast(TRANSACTION_LINE_NUMBER as varchar)",
                    ]
                )
            }} as financetransactionkey,
            {{ add_source_system_column("sage") }},
            cast(tran_id as varchar)
            || '-'
            || cast(transaction_line_number as varchar) as transactionuniqueid,
            cast(tran_id as varchar) as transactionid,
            cast(transaction_line_number as varchar) as transactionlineid,

            -- Foreign Keys
            cast(account_number as varchar) as chartofaccountkey,
            cast(classid as varchar) as classkey,
            cast(itemid as varchar) as itemkey,
            cast(itemid as varchar) as productkey,

            cast(department_id as varchar) as departmentkey,
            cast(subsidiary_id as varchar) as subsidiarykey,
            cast(location_id as varchar) as locationkey,
            coalesce(
                cast(customer_id as varchar), cast(vendor_id as varchar)
            ) as entitykey,
            cast(customer_id as varchar) as customerkey,
            cast(vendor_id as varchar) as vendorkey,
            tran_id as accountingperiodkey,
            cast(currency_id as varchar) as currency,

            -- Dates
            cast(tran_date as date) as transactiondate,
            cast(start_date as date) as postingperioddate,
            cast(due_date as date) as duedate,
            cast(close_date as date) as closedate,

            -- Measures
            cast(
                coalesce(nullif(cast(amount as varchar), 'NULL'), '0') as float
            ) as amount,
            cast(
                coalesce(nullif(cast(trx_amount as varchar), 'NULL'), '0') as float
            ) as convertedamount,
            cast(
                coalesce(nullif(cast(total_due as varchar), 'NULL'), '0') as float
            ) as openamount,
            cast(
                coalesce(nullif(cast(quantity as varchar), 'NULL'), '0') as float
            ) as quantity,

            -- Attributes
            cast(transaction_type as varchar) as transactiontype,
            cast(account_type as varchar) as debitcreditflag,
            cast(state as varchar) as transactionstatus,
            cast(state as varchar) as postingflag,

            -- Metadata
            last_modified_date

        from {{ source("gold_sage", "fact_transaction") }}

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
        from netsuite_transactions
        union all
        select *
        from sage_transactions
    )

select *, {{ get_audit_columns() }}
from unioned
