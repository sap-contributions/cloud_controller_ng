# Local API Test

```bash
uaac target http://localhost:8080 --skip-ssl-validation
uaac token client get admin -s "adminsecret"
cf api http://localhost
cf login -u ccadmin -p secret
```

```bash
cf create-org test
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
export APP_GUID=$(cf curl /v3/apps -X POST -d "$(printf '{"name": "%s", "lifecycle": {"type": "cnb", "data": {}}, "relationships": {"space": {"data": {"guid": "%s"}}}}' "$(openssl rand -hex 5)" "$SPACE_GUID")" | tee /dev/tty | jq -r .guid)
```

## Create an empty package for the app

```bash
PACKAGE_GUID=$(cf curl /v3/packages -X POST -d "$(printf '{"type":"bits", "relationships": {"app": {"data": {"guid": "%s"}}}}' "$APP_GUID")" | tee /dev/tty | jq -r .guid)

cf create-package


BUILD_GUID=$(cf curl /v3/builds -X POST -d "$(printf '{ "package": { "guid": "%s" }, "lifecycle": { "type": "cnb", "data": {} } }' "$PACKAGE_GUID")" | tee /dev/tty | jq -r .guid)
```
```bash
curl -k "$CF_API_ENDPOINT/v3/packages/$PACKAGE_GUID/upload" -F bits=@"my-app.zip" -H "Authorization: $(cf oauth-token | grep bearer)"
```

```bash
BUILD_GUID=$(cf curl /v3/builds -X POST -d "$(printf '{ "package": { "guid": "%s" }, "lifecycle": { "type": "cnb", "data": {} } }' "$PACKAGE_GUID")" | tee /dev/tty | jq -r .guid)
```
