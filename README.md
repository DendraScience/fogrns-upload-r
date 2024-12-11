# Fog Upload R Script

Purpose:   
This project provides a script to be used with R-Studio for uploading CSV files into [Dendra](https://dendra.science). It is customized for fog monitoring data from the Fog RNS group.   

Prerequisites:

1. User must be an Administrator for the Organization that will receive the uploads. 

2. At least one datastream must exist for each database/table that you want to load data into.

3. The datastream `datapoints_config` must contain an additional **source** field to permit upload. This must match the source that will be specified in the upload manifest.

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

1. Install the [R scripting language](https://cran.rstudio.com/bin/windows/base/R-4.4.2-win.exe) and [R-Studio IDE](https://posit.co/download/rstudio-desktop/).

2. Download this git repository using the "code" button on the website and select zip file. Unzip into your Documents folder.
3. Create a `.env` file in this directory using the `sample.env` as an example. Put your Dendra credentials (login and password) in here. NEVER check this into source control (use a `.gitignore` file). 
4. Launch R-Studio. Navigate to the upload.r file and open.
5. Make sure the dependency libraries get intalled.  R-Studio may automatically detect and ask to install them.  If not, copy the "install.packages" commands to the Console tab and run each one.
6. Switch to the Terminal tab.  This is where you will run the upload.r script with arguments.
7. Run the script, providing the required arguments:

	For example:

	```bash
	./upload.r --csv "FONR_STA_0_NN_20190710_20190913.csv" --comment "Production csv file import for fonr st0" --source "/fogrns/station_fog_csvs/source_fonr_st0" --station_id "672b9a9db1d7cdf52cecb5c3" --time_adjust 25200
	```
### upload.r arguments explained
`--csv`: Data file. This is the comma separated value file holding datalogger measurements that will be uploaded.  
`--comment`: Metadata to give context to what this upload is. Will be stored with the CSV file.   
`--source`: posix-style filepath. This should match exactly the **source** listed in the datapoints_config section of the datastreams assiciated with this data.   
`--station_id`: Database ID of the station in Dendra this dataset belongs to.  This can be found on the station metadata page as 'id' in grey. It also shows up in the URL.   
`--time`: timezone offset in seconds.   
UTC: Greenwich meant time offset; 0 seconds.   
PST: Pacific Standard Time offset: 28800 seconds.   
PDT: Pacific Daylight Time offset: 25200 seconds.   
	
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
