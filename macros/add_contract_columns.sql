{% macro add_contract_columns() %}
  {% if execute %}
    {% set target_relation = this %}
    {% set existing_relation = load_cached_relation(target_relation) %}
    
    {# Always try to add missing columns, whether table existed before or was just created #}
    {% set relation_to_check = target_relation %}
    
    {# Get contract columns from dbt's parsed schema #}
    {% set all_models = graph.nodes.values() | selectattr('resource_type', 'equalto', 'model') | list %}
    {% set matching_models = all_models | selectattr('name', 'equalto', this.identifier) | list %}
    {% set model_with_schema = matching_models[0] if matching_models else none %}
    
    {% if model_with_schema and model_with_schema.columns %}
      {% set contract_columns = model_with_schema.columns.values() | list %}
      {% set actual_columns = adapter.get_columns_in_relation(relation_to_check) %}
      {% set actual_column_names = actual_columns | map(attribute='name') | list %}
        
        {% do log("Checking contract columns for " ~ this.identifier, info=true) %}
        
        {% for contract_col in contract_columns %}
          {# 
            Snowflake case handling:
            - Unquoted identifiers in Snowflake are automatically uppercased (e.g., CREATE TABLE foo -> FOO)
            - Quoted identifiers preserve case (e.g., CREATE TABLE "foo" -> foo)
            - YAML contracts are case-insensitive, so we normalize to uppercase for Snowflake
            - Compare uppercase contract column against actual table columns as-is to avoid duplicates
            
            Note: For other adapters (PostgreSQL, BigQuery, etc.), this logic may need adjustment
            based on their identifier case handling rules. Consider adding case sensitivity 
            configuration to YAML contracts if cross-adapter support is needed.
          #}
          {% set contract_col_name = contract_col.name.upper() %}
          
          {# Check if column exists with different case #}
          {% set case_mismatch = false %}
          {% set existing_case_variant = none %}
          {% for actual_col in actual_column_names %}
            {% if actual_col.upper() == contract_col_name and actual_col != contract_col_name %}
              {% set case_mismatch = true %}
              {% set existing_case_variant = actual_col %}
              {% do log("⚠️  CASE MISMATCH: Column '" ~ actual_col ~ "' exists but contract expects '" ~ contract_col_name ~ "'. Check for case-sensitive column naming issues.", info=true) %}
              {% break %}
            {% endif %}
          {% endfor %}
          
          {% if contract_col_name not in actual_column_names %}
            {# Determine appropriate data type for Snowflake #}
            {% set snowflake_type = contract_col.data_type %}
            {% if contract_col.data_type == 'numeric' %}
              {% set snowflake_type = 'NUMBER(38,3)' %}
            {% elif contract_col.data_type == 'uuid' %}
              {% set snowflake_type = 'VARCHAR' %}
            {% elif contract_col.data_type == 'text' %}
              {% set snowflake_type = 'VARCHAR' %}
            {% elif contract_col.data_type == 'integer' %}
              {% set snowflake_type = 'INTEGER' %}
            {% endif %}
            
            {# Get default value if specified in meta #}
            {% set default_clause = '' %}
            {% if contract_col.meta and contract_col.meta.default is defined %}
              {% set default_clause = ' DEFAULT ' ~ contract_col.meta.default %}
            {% endif %}
            
            {% set alter_sql %}
              ALTER TABLE {{ relation_to_check }} ADD COLUMN {{ contract_col_name }} {{ snowflake_type }}{{ default_clause }}
            {% endset %}
            
            {% do log("Adding missing column: " ~ contract_col_name ~ " (" ~ snowflake_type ~ ")", info=true) %}
            {% do run_query(alter_sql) %}
          {% endif %}
        {% endfor %}
      {% else %}
        {% do log("No schema contract found for " ~ this.identifier, info=true) %}
      {% endif %}
  {% endif %}
{% endmacro %}