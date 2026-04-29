FROM python:3.13-slim

WORKDIR /app

# Install dbt with BigQuery adapter
RUN pip install --no-cache-dir dbt-bigquery

# Copy project files
COPY . .

# Run dbt — profiles.yml is in the project root so we point --profiles-dir here
ENTRYPOINT ["dbt", "run", "--profiles-dir", "/app"]