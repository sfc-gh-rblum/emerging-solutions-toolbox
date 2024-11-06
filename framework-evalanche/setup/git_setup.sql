SET (streamlit_warehouse)=(SELECT CURRENT_WAREHOUSE());

CREATE DATABASE IF NOT EXISTS GENAI_UTILITIES
COMMENT = '{"origin": "sf_sit",
            "name": "evalanche",
            "version": {"major": 1, "minor": 0}}';

CREATE SCHEMA IF NOT EXISTS GENAI_UTILITIES.EVALUATION
COMMENT = '{"origin": "sf_sit",
            "name": "evalanche",
            "version": {"major": 1, "minor": 0}}';

-- Create API Integration for Git
CREATE OR REPLACE API INTEGRATION git_api_integration_snowflake_labs_emerging_solutions_toolbox
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/Snowflake-Labs')
  ENABLED = TRUE;

-- Create Git Repository
CREATE OR REPLACE GIT REPOSITORY GENAI_UTILITIES.EVALUATION.git_evalanche
  API_INTEGRATION = git_api_integration_snowflake_labs_emerging_solutions_toolbox
  ORIGIN = 'https://github.com/Snowflake-Labs/emerging-solutions-toolbox.git';

ALTER GIT REPOSITORY GENAI_UTILITIES.EVALUATION.git_evalanche FETCH;

CREATE OR ALTER TABLE GENAI_UTILITIES.EVALUATION.SAVED_EVALUATIONS
(EVAL_NAME VARCHAR,
DESCRIPTION VARCHAR,
METRIC_NAMES ARRAY,
SOURCE_SQL VARCHAR,
PARAM_ASSIGNMENTS VARIANT,
ASSOCIATED_OBJECTS VARIANT,
MODELS VARIANT)
COMMENT = '{"origin": "sf_sit",
            "name": "evalanche",
            "version": {"major": 1, "minor": 0}}';

CREATE OR ALTER TABLE GENAI_UTILITIES.EVALUATION.AUTO_EVALUATIONS
(EVAL_NAME VARCHAR,
DESCRIPTION VARCHAR,
METRIC_NAMES ARRAY,
SOURCE_SQL VARCHAR,
PARAM_ASSIGNMENTS VARIANT,
ASSOCIATED_OBJECTS VARIANT,
MODELS VARIANT)
COMMENT = '{"origin": "sf_sit",
            "name": "evalanche",
            "version": {"major": 1, "minor": 0}}';

CREATE OR ALTER TABLE GENAI_UTILITIES.EVALUATION.CUSTOM_METRICS
(METRIC_NAME VARCHAR,
STAGE_FILE_PATH VARCHAR,
CREATED_DATETIME TIMESTAMP,
SHOW_METRIC BOOLEAN,
CREATION_USER VARCHAR)
COMMENT = '{"origin": "sf_sit",
            "name": "evalanche",
            "version": {"major": 1, "minor": 0}}';

-- Create stage for App logic
CREATE STAGE IF NOT EXISTS GENAI_UTILITIES.EVALUATION.STREAMLIT_STAGE
DIRECTORY = (ENABLE = true)
COMMENT = '{"origin": "sf_sit",
            "name": "evalanche",
            "version": {"major": 1, "minor": 0}}';

-- Copy Files from Git Repository into App Stage
COPY FILES
  INTO @GENAI_UTILITIES.EVALUATION.STREAMLIT_STAGE
  FROM @GENAI_UTILITIES.EVALUATION.git_evalanche/branches/main/framework-evalanche/
  FILES=('src.zip');

COPY FILES
  INTO @GENAI_UTILITIES.EVALUATION.STREAMLIT_STAGE/src/
  FROM @GENAI_UTILITIES.EVALUATION.git_evalanche/branches/main/framework-evalanche/src/
  PATTERN='.*[.]py';

COPY FILES
  INTO @GENAI_UTILITIES.EVALUATION.STREAMLIT_STAGE
  FROM @GENAI_UTILITIES.EVALUATION.git_evalanche/branches/main/framework-evalanche/
  FILES=('home.py', 'environment.yml');

COPY FILES
  INTO @GENAI_UTILITIES.EVALUATION.STREAMLIT_STAGE/pages/
  FROM @GENAI_UTILITIES.EVALUATION.git_evalanche/branches/main/framework-evalanche/pages/
  PATTERN='.*[.]py';

-- Helper SPROC to remove custom_metrics
CREATE OR REPLACE PROCEDURE GENAI_UTILITIES.EVALUATION.DELETE_METRIC(metric_name string)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.9'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
EXECUTE AS CALLER
AS
$$
def run(session, metric_name):
    STAGE = "@GENAI_UTILITIES.EVALUATION.STREAMLIT_STAGE"
    TABLE = "GENAI_UTILITIES.EVALUATION.CUSTOM_METRICS"
    file_path = f"{STAGE}/{metric_name}.pkl"
    query = f"rm {file_path}"
    
    try:
        session.sql(query).collect()
        metrics_tbl = session.table(TABLE)
        metrics_tbl.delete(metrics_tbl["METRIC_NAME"] == metric_name)
        return f"{file_path} removed."
    except Exception as e:
        return f"An error occurred: {e}"
$$;

-- Create Streamlit
CREATE OR REPLACE STREAMLIT GENAI_UTILITIES.EVALUATION.EVALUATION_APP
ROOT_LOCATION = '@GENAI_UTILITIES.EVALUATION.STREAMLIT_STAGE'
MAIN_FILE = 'home.py'
TITLE = "Evalanche: GenAI Evaluation Application"
QUERY_WAREHOUSE = $streamlit_warehouse
COMMENT = '{"origin": "sf_sit",
            "name": "evalanche",
            "version": {"major": 1, "minor": 0}}';
