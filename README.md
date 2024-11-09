# Fog Upload R Scripts

Prerequisites:

1. Organization membership role of `admin` is required to create uploads.

2. At least one datastream must exist for each database/table that you want to load data into.

3. The datastream `datapoints_config` must contain an additional source field to permit upload. This must match the source that will be specified in the upload manifest.

## Sample datapoints config with source

```json
{
  "query": {
    "api": "fogrns",
    "db": "station_fog_csvs",
    "fc": "source_fonr_st0",
    "sc": "\"time\", \"Liters\"",
    "utc_offset": -28800,
    "coalesce": false,
    "source": "/fogrns/station_fog_csvs/source_fonr_st0"
  }
}
```

## Using the script

1. Ensure that the prerequisites are met above.

2. Create a `.env` file in this directory using the `sample.env` as an example. Put your Dendra credentials in here. NEVER check this into source control (use a `.gitignore` file). 

3. Install the R packages listed in the script `upload.r`.

4. Run the script, providing the required arguments:

	For example:

	```bash
	./upload.r --csv "FONR_STA_0_NN_20190710_20190913.csv" --comment "Production csv file import for fonr st0" --source "/fogrns/station_fog_csvs/source_fonr_st0" --station_id "672b9a9db1d7cdf52cecb5c3" --time_adjust 28800
	```

## Manual upload processing steps (live run)

1. Prepare an upload manifest as follows:

	- Provide a meaningful `comment`
	- Set the `source` to match the source of a given datastream
	- Set `dry_run` to `false`
	- Set `station_id`
	
	Sample:

	```json
	{
	    "organization_id": "6710031571c87f0c4e4bd317",
	    "spec":
	    {
	        "comment": "Production csv file import for ...",
	        "method": "csv",
	        "options":
	        {
	            "columns_name": "safe",
	            "context":
	            {
	                "source": "/fogrns/station_fog_csvs/source_fonr"
	            },
              "date_column": "Date",
              "dry_run": false,
              "from_line": 11,
              "time_adjust": 0,
              "time_column": "Time",
              "time_format": "M/D/YYYY h:mm:ss A"
	        }
	    },
	    "spec_type": "file/import",
	    "station_id": "REPLACE_WITH_A_VALID_STATION_ID",
	    "storage":
	    {
	        "method": "minio"
	    }
	}
	```

2. POST the manifest to the API. You may either:

	- POST the JSON to `/uploads`
	- Use the CLI, e.g. `den util create-upload --file="upload.json" --save`.

3. GET the manifest after a few seconds, or until the `presigned_put_info` is available.

4. PUT the CSV file to the URL at `result_pre.presigned_put_info.url`.

	CURL example:

	```bash
curl -H "Content-Type: text/csv" --upload-file my.csv "THE_PRESIGNED_PUT_URL"
	```

5. PATCH the manifest to activate it. Set `is_active` to `true`.

6. Wait for processing. GET the manifest every few seconds until the upload `state` is either `completed` or `error`.


## Manual upload processing steps (dry run)

1. Prepare an upload manifest as follows:

	- Provide a meaningful `comment`
	- Set the `source` to match the source of a given datastream
	- Set `dry_run` to `true`
	- Set `station_id`
	
	Sample:

	```json
	{
	    "organization_id": "6710031571c87f0c4e4bd317",
	    "spec":
	    {
	        "comment": "Production csv file import for ...",
	        "method": "csv",
	        "options":
	        {
	            "columns_name": "safe",
	            "context":
	            {
	                "source": "/fogrns/station_fog_csvs/source_fonr"
	            },
              "date_column": "Date",
              "dry_run": true,
              "from_line": 11,
              "time_adjust": 0,
              "time_column": "Time",
              "time_format": "M/D/YYYY h:mm:ss A"
	        }
	    },
	    "spec_type": "file/import",
	    "station_id": "REPLACE_WITH_A_VALID_STATION_ID",
	    "storage":
	    {
	        "method": "minio"
	    }
	}
	```

2. POST the manifest to the API. You may either:

	- POST the JSON to `/uploads`
	- Use the CLI, e.g. `den util create-upload --file="upload.json" --save`.

3. GET the manifest after a few seconds, or until the `presigned_put_info` is available.

4. PUT the CSV file to the URL at `result_pre.presigned_put_info.url`.

	CURL example:

	```bash
	curl -H "Content-Type: text/csv" --upload-file my.csv "THE_PRESIGNED_PUT_URL"
	```

5. PATCH the manifest to activate it. Set `is_active` to `true`.

6. Wait for processing. GET the manifest every few seconds until the upload `state` is either `completed` or `error`.

7. Examine the `sampled_data` in the manifest to ensure it looks correct.

8. PATCH the manifest again to submit for live. Patch operations can only be done on root level fields; hence in one PATCH operation you will:

	- Set `is_active` to `true`
	- Set `spec` to the original spec with `dry_run` set to `false`

9. Wait for processing. GET the manifest every few seconds until the upload `state` is either `completed` or `error`.
