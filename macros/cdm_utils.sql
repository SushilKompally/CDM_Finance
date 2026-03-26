{% macro generate_finance_key(columns) %}
    {{ dbt_utils.generate_surrogate_key(columns) }}
{% endmacro %}

-- Get incremental filter with configurable lookback
{% macro get_incremental_filter(timestamp_column, lookback_days=None) %}
    {% if is_incremental() %}
        {% set lb_days = lookback_days or var('lookback_days', 3) %}
        where {{ timestamp_column }}::timestamp >= (
            select dateadd(
                day,
                -{{ lb_days }},
                coalesce(max({{ timestamp_column }}::timestamp), '1900-01-01'::timestamp)
            )
            from {{ this }}
        )
    {% endif %}
{% endmacro %}

-- Add source system column
{% macro add_source_system_column(source_name) %}
    '{{ source_name | upper }}' as source_system
{% endmacro %}

-- Safe cast with optional default value
{% macro safe_cast(column_name, target_type, default_value=None) %}
    {% if default_value %}
        coalesce(
            try_cast({{ column_name }} as {{ target_type }}),
            {{ default_value }}
        )
    {% else %}
        try_cast({{ column_name }} as {{ target_type }})
    {% endif %}
{% endmacro %}

-- Get audit columns
{% macro get_audit_columns() %}
    current_timestamp() as _created_at,
    current_timestamp() as _updated_at,
    '{{ invocation_id }}' as _dbt_run_id
{% endmacro %}

-- Normalize amount with optional exchange rate
{% macro normalize_amount(amount_column, exchange_rate_column=None) %}
    {% if exchange_rate_column %}
        round({{ amount_column }} * coalesce({{ exchange_rate_column }}, 1), 2)
    {% else %}
        round({{ amount_column }}, 2)
    {% endif %}
{% endmacro %}

-- Get soft delete filter
{% macro get_soft_delete_filter(deleted_flag_column='is_deleted') %}
    {% if var('enable_soft_deletes', true) %}
        where coalesce({{ deleted_flag_column }}, false) = false
    {% endif %}
{% endmacro %}

-- Union multiple relations
{% macro union_relations(relations, source_column_name='source_system') %}
    {% for relation in relations %}
        select
            *,
            '{{ relation.name | upper }}' as {{ source_column_name }}
        from {{ relation }}
        {% if not loop.last %}
        union all
        {% endif %}
    {% endfor %}
{% endmacro %}

-- Get lookback timestamp
{% macro get_lookback_timestamp(days=3) %}
    dateadd(day, -{{ days }}, current_timestamp())
{% endmacro %}

-- Standardize phone number
{% macro standardize_phone_number(phone_column) %}
    regexp_replace(
        regexp_replace({{ phone_column }}, '[^0-9]', ''),
        '^1',
        ''
    )
{% endmacro %}

-- Standardize email
{% macro standardize_email(email_column) %}
    lower(trim({{ email_column }}))
{% endmacro %}

-- Get fiscal year
{% macro get_fiscal_year(date_column, fiscal_year_start_month=1) %}
    case
        when month({{ date_column }}) >= {{ fiscal_year_start_month }}
        then year({{ date_column }})
        else year({{ date_column }}) - 1
    end
{% endmacro %}

-- Get fiscal quarter
{% macro get_fiscal_quarter(date_column, fiscal_year_start_month=1) %}
    case
        when month({{ date_column }}) >= {{ fiscal_year_start_month }}
        then floor((month({{ date_column }}) - {{ fiscal_year_start_month }}) / 3) + 1
        else floor((12 - {{ fiscal_year_start_month }} + month({{ date_column }})) / 3) + 1
    end
{% endmacro %}

-- Get default currency
{% macro get_default_currency() %}
    '{{ var("default_currency", "USD") }}'
{% endmacro %}