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
