#!/usr/bin/env Rscript --vanilla
#
# PACKAGES:
# install.packages("checkmate")
# install.packages("dotenv")
# install.packages("jsonlite")
# install.packages('httpuv')
# install.packages('httr2')
# install.packages('R.utils')
#
# USAGE:
# ./upload.r --csv "FONR_STA_0_NN_20190710_20190913.csv" --comment "My cool upload" --source "/fogrns/station_fog_csvs/source_fonr" --station_id "STATION_ID" --time_adjust 28800
#

library(dotenv)
library(checkmate)
library(R.utils, include.only = "commandArgs")
library(jsonlite)
library(httr2)

args = commandArgs(asValues = TRUE)

assertString(args$csv)
assertString(args$comment)
assertString(args$source)
assertString(args$station_id)
assertString(args$time_adjust)

req <- request("https://api.dendra.science")
auth <- req |>
    req_url_path("/v2/authentication") |>
    req_body_json(list(
        strategy = "local", 
        email = Sys.getenv("EMAIL"), 
        password = Sys.getenv("PASSWORD")
        )) |>
    req_perform() |>
    resp_body_json()

#  Prepare an upload manifest
template <- fromJSON('{
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
                "source": "/fogrns/database/measurement"
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
    "station_id": "000000000000000000000000",
    "storage":
    {
        "method": "minio"
    }
}')

template$spec$comment = args$comment
template$spec$options$context$source = args$source
template$spec$options$time_adjust = strtoi(args$time_adjust)
template$station_id = args$station_id

# POST the manifest to the API
upload <- req |>
    req_url_path("/v2/uploads") |>
    req_auth_bearer_token(auth$accessToken) |>
    req_body_json(template) |>
    req_perform() |>
    resp_body_json()

sprintf("Created upload manifest: %s", upload$`_id`)

# GET the manifest after a few seconds
Sys.sleep(5)

upload <- req |>
    req_url_path("/v2/uploads") |>
    req_url_path_append(upload$`_id`) |>
    req_auth_bearer_token(auth$accessToken) |>
    req_perform() |>
    resp_body_json()

assertString(upload$state, fixed = "pending")
assertString(upload$result_pre$presigned_put_info$url)

# PUT the CSV file to the URL 
sprintf("Uploading file to bucket: %s", args$csv)

status <- request(upload$result_pre$presigned_put_info$url) |>
    req_progress() |>
    req_body_file(args$csv, type = "text/csv") |>
    req_method("PUT") |>
    req_perform() |>
    resp_status()

assertInteger(status, lower = 200, upper = 200)

#  PATCH the manifest to activate it
print("Activating upload...")

patch <- fromJSON('{
  "$set": {
    "is_active": true
  }
}')

status <- req |>
    req_url_path("/v2/uploads") |>
    req_url_path_append(upload$`_id`) |>
    req_auth_bearer_token(auth$accessToken) |>
    req_body_json(patch) |>
    req_method("PATCH") |>
    req_perform() |>
    resp_status()

assertInteger(status, lower = 200, upper = 200)

# Wait for processing
msg = ""
repeat {
    print("Checking upload...")

    upload <- req |>
        req_url_path("/v2/uploads") |>
        req_url_path_append(upload$`_id`) |>
        req_auth_bearer_token(auth$accessToken) |>
        req_perform() |>
        resp_body_json()

    if (upload$state == 'completed') {
        msg <- sprintf("Processing completed, check %s.upload.json for results", upload$`_id`)
        write(toJSON(upload, auto_unbox = TRUE, digits = 9, pretty = TRUE), paste(upload$`_id`, "upload.json", sep = "."))
        break
    }
    if (upload$state == 'error') {
        msg <- sprintf("Processing failed, check %s.upload.json for results", upload$`_id`)
        write(toJSON(upload, auto_unbox = TRUE, digits = 9, pretty = TRUE), paste(upload$`_id`, "upload.json", sep = "."))
        break
    }

    Sys.sleep(3)
}

print(msg)
