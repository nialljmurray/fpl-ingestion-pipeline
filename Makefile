include .env

deploy-ingestion:
	gcloud functions deploy fpl_ingestion \
		--gen2 \
		--project=$(PROJECT_ID) \
		--region=$(REGION) \
		--runtime=python311 \
		--trigger-http \
		--entry-point=main \
		--source=./ingestion \
		--no-allow-unauthenticated \
		--timeout=540

deploy-loading:
	gcloud functions deploy fpl_loading \
		--gen2 \
		--project=$(PROJECT_ID) \
		--region=$(REGION) \
		--runtime=python311 \
		--trigger-http \
		--entry-point=main \
		--source=./loading \
		--no-allow-unauthenticated \
		--timeout=300

deploy-workflow:
	gcloud workflows deploy fpl-pipeline \
		--project=$(PROJECT_ID) \
		--location=$(REGION) \
		--source=workflow.yaml

run-workflow:
	gcloud workflows run fpl-pipeline \
		--project=$(PROJECT_ID) \
		--location=$(REGION)

create-scheduler:
	gcloud scheduler jobs create http fpl-pipeline-nightly \
		--project=$(PROJECT_ID) \
		--location=$(REGION) \
		--schedule="0 3 * * *" \
		--time-zone="UTC" \
		--uri="https://workflowexecutions.googleapis.com/v1/projects/$(PROJECT_ID)/locations/$(REGION)/workflows/fpl-pipeline/executions" \
		--message-body="{}" \
		--oauth-service-account-email=$(SCHEDULER_SA)

trigger-ingestion:
	curl -X POST $(INGESTION_URL) \
		-H "Authorization: bearer $$(gcloud auth print-identity-token)"

trigger-loading:
	@read -p "Enter run_timestamp: " ts; \
	curl -X POST $(LOADING_URL) \
		-H "Authorization: bearer $$(gcloud auth print-identity-token)" \
		-H "Content-Type: application/json" \
		-d "{\"run_timestamp\": \"$$ts\"}"

DBT_SECRET_NAMES = DBT_SA_TYPE DBT_SA_PROJECT_ID DBT_SA_PRIVATE_KEY_ID DBT_SA_PRIVATE_KEY \
                   DBT_SA_CLIENT_EMAIL DBT_SA_CLIENT_ID DBT_SA_AUTH_URI DBT_SA_TOKEN_URI \
                   DBT_SA_AUTH_PROVIDER_CERT_URL DBT_SA_CLIENT_CERT_URL

create-dbt-secrets:
	@for secret in $(DBT_SECRET_NAMES); do \
		gcloud secrets create $$secret \
			--project=$(PROJECT_ID) \
			--replication-policy=automatic 2>/dev/null \
			&& echo "Created: $$secret" \
			|| echo "Already exists (skipped): $$secret"; \
	done

push-dbt-secrets:
	@printf '%s' "$(DBT_SA_TYPE)" | gcloud secrets versions add DBT_SA_TYPE --project=$(PROJECT_ID) --data-file=-
	@printf '%s' "$(DBT_SA_PROJECT_ID)" | gcloud secrets versions add DBT_SA_PROJECT_ID --project=$(PROJECT_ID) --data-file=-
	@printf '%s' "$(DBT_SA_PRIVATE_KEY_ID)" | gcloud secrets versions add DBT_SA_PRIVATE_KEY_ID --project=$(PROJECT_ID) --data-file=-
	@printf '%s' "$(DBT_SA_PRIVATE_KEY)" | gcloud secrets versions add DBT_SA_PRIVATE_KEY --project=$(PROJECT_ID) --data-file=-
	@printf '%s' "$(DBT_SA_CLIENT_EMAIL)" | gcloud secrets versions add DBT_SA_CLIENT_EMAIL --project=$(PROJECT_ID) --data-file=-
	@printf '%s' "$(DBT_SA_CLIENT_ID)" | gcloud secrets versions add DBT_SA_CLIENT_ID --project=$(PROJECT_ID) --data-file=-
	@printf '%s' "$(DBT_SA_AUTH_URI)" | gcloud secrets versions add DBT_SA_AUTH_URI --project=$(PROJECT_ID) --data-file=-
	@printf '%s' "$(DBT_SA_TOKEN_URI)" | gcloud secrets versions add DBT_SA_TOKEN_URI --project=$(PROJECT_ID) --data-file=-
	@printf '%s' "$(DBT_SA_AUTH_PROVIDER_CERT_URL)" | gcloud secrets versions add DBT_SA_AUTH_PROVIDER_CERT_URL --project=$(PROJECT_ID) --data-file=-
	@printf '%s' "$(DBT_SA_CLIENT_CERT_URL)" | gcloud secrets versions add DBT_SA_CLIENT_CERT_URL --project=$(PROJECT_ID) --data-file=-
