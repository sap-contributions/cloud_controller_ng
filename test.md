# Local API Test

```bash
cf craete-org test
cf target -o "test"

cf create-space test
cf target -o "test" -s "test"
```


```bash
export CF_API_ENDPOINT=$(cf api | grep -i "api endpoint" | awk '{print $3}')
export SPACE_GUID=$(cf space `cf target | tail -n 1 | awk '{print $2}'` --guid)
export APP_NAME=cnb-test-app-3

```

## Create an empty app

```bash
export APP_GUID=$(cf curl /v3/apps -X POST -d "$(printf '{"name": "%s", "lifecycle": {"type": "cnb", "data": {}}, "relationships": {"space": {"data": {"guid": "%s"}}}}' "cnb-test-4" "$SPACE_GUID")" | tee /dev/tty | jq -r .guid)
```

## Create an empty package for the app

```bash
PACKAGE_GUID=$(cf curl /v3/packages -X POST -d "$(printf '{"type":"bits", "relationships": {"app": {"data": {"guid": "%s"}}}}' "$APP_GUID")" | tee /dev/tty | jq -r .guid)

curl -k "$CF_API_ENDPOINT/v3/packages/$PACKAGE_GUID/upload" -F bits=@"my-app.zip" -H "Authorization: $(cf oauth-token | grep bearer)"
BUILD_GUID=$(cf curl /v3/builds -X POST -d "$(printf '{ "package": { "guid": "%s" }, "lifecycle": { "type": "buildpack", "data": { "buildpacks": ["ruby_buildpack", "go_buildpack"] } } }' "$PACKAGE_GUID")" | tee /dev/tty | jq -r .guid)
```
```bash
curl -k "$CF_API_ENDPOINT/v3/packages/$PACKAGE_GUID/upload" -F bits=@"my-app.zip" -H "Authorization: $(cf oauth-token | grep bearer)"
```

```bash
BUILD_GUID=$(cf curl /v3/builds -X POST -d "$(printf '{ "package": { "guid": "%s" }, "lifecycle": { "type": "buildpack", "data": { "buildpacks": ["ruby_buildpack", "go_buildpack"] } } }' "$PACKAGE_GUID")" | tee /dev/tty | jq -r .guid)
```
