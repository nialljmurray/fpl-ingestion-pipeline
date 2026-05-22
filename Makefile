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

trigger-ingestion:
	curl -X POST $(INGESTION_URL) \
		-H "Authorization: bearer $$(gcloud auth print-identity-token)"

trigger-loading:
	@read -p "Enter run_timestamp: " ts; \
	curl -X POST $(LOADING_URL) \
		-H "Authorization: bearer $$(gcloud auth print-identity-token)" \
		-H "Content-Type: application/json" \
		-d "{\"run_timestamp\": \"$$ts\"}"
