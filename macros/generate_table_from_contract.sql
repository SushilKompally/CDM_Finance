{% macro get_registered_sources(table_name) %}
  {% set table_registrations = var('table_registrations', {}) %}
  {% set sources = table_registrations.get(table_name, []) %}
  {{ return(sources) }}
{% endmacro %}

{% macro generate_table_from_contract() %}
  {% set table_name = this.name %}
  {% set registered_sources = get_registered_sources(table_name) %}
  
  {% if registered_sources %}
    {# If we have registered sources, union them together #}
    {% set relations_list = [] %}
    {% for source_config in registered_sources %}
      {% set source_parts = source_config.source.split('.') %}
      {% set relation = source(source_parts[0], source_parts[1]) %}
      {% set _ = relations_list.append(relation) %}
    {% endfor %}
    
    {# Get contract columns to ensure all contract fields are available #}
    {% if execute %}
      {% set all_models = graph.nodes.values() | selectattr('resource_type', 'equalto', 'model') | list %}
      {% set matching_models = all_models | selectattr('name', 'equalto', this.identifier) | list %}
      {% set model_with_schema = matching_models[0] if matching_models else none %}
      
      {% if model_with_schema and model_with_schema.columns %}
        {% set contract_columns = model_with_schema.columns.values() | list %}
        
        {# Get columns that exist in source relations #}
        {% set source_columns = adapter.get_columns_in_relation(relations_list[0]) %}
        {% set source_column_names = source_columns | map(attribute='name') | map('upper') | list %}
        
        {# Build the union with explicit column selection to include contract fields #}
        (
        {%- for relation in relations_list %}
            SELECT 
            {%- for contract_col in contract_columns %}
                {% set col_name_upper = contract_col.name.upper() -%}
                {%- if col_name_upper in source_column_names %}
                "{{ contract_col.name.upper() }}"
                {%- else %}
                    {%- set sql_type = 'VARCHAR' %}
                    {%- if contract_col.data_type == 'uuid' %}
                        {%- set sql_type = 'VARCHAR' -%}
                    {%- elif contract_col.data_type == 'boolean' %}
                        {%- set sql_type = 'BOOLEAN' -%}
                    {%- elif contract_col.data_type == 'integer' or contract_col.data_type == 'bigint' %}
                        {%- set sql_type = 'INTEGER' -%}
                    {%- elif contract_col.data_type == 'numeric' %}
                        {%- set sql_type = 'NUMERIC' -%}
                    {%- elif contract_col.data_type == 'date' %}
                        {%- set sql_type = 'DATE' -%}
                    {%- elif contract_col.data_type.startswith('decimal') %}
                        {%- set sql_type = contract_col.data_type.upper() -%}
                    {%- endif -%}
                CAST(NULL AS {{ sql_type }}) as "{{ contract_col.name.upper() }}"
                {%- endif -%}
                {%- if not loop.last %},{% endif %}
            {% endfor %}
            FROM {{ relation }}
            {%- if not loop.last %}
            
            UNION ALL
            {% endif -%}
        {%- endfor %}
        )
      {% else %}
        {# Fallback to standard union if no contract found #}
        {{ dbt_utils.union_relations(relations=relations_list, exclude=["_dbt_source_relation"]) }}
      {% endif %}
    {% else %}
      {# Fallback during parsing #}
      {{ dbt_utils.union_relations(relations=relations_list, exclude=["_dbt_source_relation"]) }}
    {% endif %}
    
  {% else %}
    {# No registered sources - create empty table with contract structure #}
    {{ generate_empty_table_from_contract() }}
  {% endif %}
{% endmacro %}
