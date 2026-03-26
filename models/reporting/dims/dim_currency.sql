{{ config(
    materialized="table",
    post_hook="{{ add_contract_columns() }}"
) }}
{{ generate_table_from_contract() }}
