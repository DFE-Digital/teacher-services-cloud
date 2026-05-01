# Requires
# - $AIRBYTE_URL e.g. https://airbyte-bat.cluster2.development.teacherservices.cloud
# - $CLIENT_ID
# - $CLIENT_SECRET

generate_post_data()
{
  cat <<EOF
{
  "client_id": "${CLIENT_ID}",
  "client_secret": "${CLIENT_SECRET}",
  "grant-type": "client_credentials"
}
EOF
}

# list current workspaces
curl -s --request POST \
 --url "$AIRBYTE_URL/api/v1/applications/token" \
 --header 'accept: application/json' \
 --header 'content-type: application/json' \
 --data "$(generate_post_data)" \
  | jq -r '.access_token' \
  | awk '{print "Authorization: Bearer", $1}' \
  | curl -s --request GET \
--url "${AIRBYTE_URL}/api/public/v1/workspaces" \
--header 'accept: application/json' \
--header "@-" | jq
