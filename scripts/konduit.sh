#!/bin/bash
# Connect to a backend service via an app instance
#

# TODO
#
# - usually more than one redis service. Set default and how to override?
# - test against azure redis service when available
# - confirm before running if interactive, a flag to run without confirmation?
#

# Stop the script in case a command fails. Cleanup will still run
# Fail when a variable is unexpectedly not set
# If variable $VAR can be unset, use ${VAR:-} to provide a default "" value
set -euo pipefail

help() {
   echo
   echo "Script to connect to a k8 backing service via an app service"
   echo

   echo "Syntax:"
   echo "   konduit [-a|-c|-h|-q|-x|-i file-name|-p postgres-var|-m sqlserver-var|-r redis-var|-e auth-mode|-s server-name|-t timeout|-n namespace] app-name -- command [args]"
   echo "      Connect to the default database for app-name"
   echo
   echo "or konduit [-a|-c|-h|-q|-x|-i file-name|-p postgres-var|-m sqlserver-var|-r redis-var|-e auth-mode|-s server-name|-t timeout|-n namespace] -b db-name app-name -- command [args]"
   echo "      Connect to database 'db-name' using URL and credentials from app-name"
   echo
   echo "or konduit [-a|-c|-h|-q|-x|-i file-name|-p postgres-var|-m sqlserver-var|-r redis-var|-e auth-mode|-s server-name|-t timeout|-n namespace] -u 'connection-string' app-name -- command [args]"
   echo "      Connect using the supplied database URL or SQL Server connection string"
   echo
   echo "or konduit [-a|-c|-h|-q|-x|-i file-name|-m sqlserver-var|-r redis-var|-e auth-mode|-t timeout|-n namespace] -d keyvault-db-name -k key-vault app-name -- command [args]"
   echo "      Connect to a specific database from app-name"
   echo "      Requires a secret containing the DB URL in the specified Azure KV,"
   echo "      with name {keyvault-db-name}-database-url"
   echo
   echo "options:"
   echo "   -a                Backend is an AKS service. Default is Azure backing service."
   echo "   -c                Input file is compressed. Requires -i."
   echo "   -b db-name        Override database name if connecting to a db other than the app default."
   echo "                     In case of redis, it is the database index: 0, 1, 2..."
   echo "   -d keyvault-db-name        Database name in keyvault secret name, required for the -k option"
   echo "                     It can only contain alphanumerical characters and hyphens"
   echo "   -e auth-mode      SQL Server authentication mode: sql or entra. Default: auto-detect from connection string."
   echo "   -i file-name      Input file for SQL commands. Supports psql and sqlcmd; use -c for gzip-compressed files."
   echo "   -k key-vault      Key vault that holds the Azure secret containing the DB URL."
   echo "                     The secret {db-name}-database-url must exist in this vault,"
   echo "                     and contain a full connection URL or SQL Server connection string."
   echo "   -n namespace      Namespace where the app can be found. Required in case the user doesn't have cluster admin access."
   echo "   -p postgres-var   Variable for postgres [defaults to DATABASE_URL if not set]"
   echo "                     Only valid for commands psql, pg_dump or pg_restore"
   echo "   -m sqlserver-var  Variable for SQL Server connection string [defaults to SQLSERVER_CONNECTION_STRING]"
   echo "                     Only valid for command sqlcmd"
   echo "                     With -x, searches envFrom Secrets/ConfigMaps and reports available setting names if missing."
   echo "   -q                Quiet mode. Do not echo informational messages"
   echo "   -r redis-var      Variable for redis cache [defaults to REDIS_URL if not set]"
   echo "                     Only valid for command redis-cli"
   echo "   -s server-name    Override server name. Postgres only, used to access PTR server. Hostname without .postgres.database.azure.com suffix."
   echo "   -t timeout        Timeout in seconds. Default is 28800 but 3600 for file-based SQL and backup commands."
   echo "   -u 'connection-string' Full connection URL/string if different from the app value used for tunnelling."
   echo "                     It should be enclosed in quotes to avoid shell interpretation"
   echo "   -x                Runs konduit through a separate pod"
   echo "   -h                Print this help."
   echo
   echo "parameters:"
   echo "   app-name     app name to connect to."
   echo "   command      command to run."
   echo "                  valid commands are psql, pg_dump, pg_restore, redis-cli or sqlcmd"
   echo "   args         args for the command"
   echo
   echo "connection string formats:"
   echo "                     postgres://ADMIN_USER:URLENCODED(ADMIN_PASSWORD)@DB_HOSTNAME:5432/DB_NAME"
   echo "                     or rediss://:PASSWORD=@DB_HOSTNAME:6380/0"
   echo "                     The ADMIN_PASSWORD can be url encoded using terraform console"
   echo "                     using CMD: urlencode(ADMIN_PASSWORD)"
   echo "                     SQL Server: Server=tcp:server.database.windows.net,1433;Database=db;User ID=user;Password=******"
   echo "                     SQL logins for Azure SQL are server-qualified automatically for tunnel routing."
   echo
   echo "SQL Server example:"
   echo "   konduit -m SQLSERVER_CONNECTION_STRING my-app -- sqlcmd"
   echo "   konduit -m SQLSERVER_CONNECTION_STRING -e entra my-app -- sqlcmd -Q 'SELECT TOP 10 * FROM dbo.TableName'"
}

init_setup() {
   if [ "${RUNCMD}" != "psql" ] && [ "${RUNCMD}" != "pg_dump" ] && [ "${RUNCMD}" != "pg_restore" ] && [ "${RUNCMD}" != "redis-cli" ] && [ "${RUNCMD}" != "sqlcmd" ]; then
      echo
      echo "Error: invalid command ${RUNCMD}"
      echo "Only valid commands are psql, pg_dump, pg_restore, redis-cli or sqlcmd"
      help
      exit 1
   fi

   if [ "${RUNCMD}" = "sqlcmd" ] && ! command -v sqlcmd >/dev/null 2>&1; then
      echo "Error: sqlcmd is required for SQL Server connections. Install Microsoft's sqlcmd command-line tool."
      exit 1
   fi

   if [ -z "${Timeout:-}" ]; then
      # Default timeout for psql/pg_dump/pg_restore set to 8 hours. Increase if required.
      # This is to allow for long running queries or backups.
      # The timeout is reset for each command run.
      # The timeout can be overridden with the -t option.
      TMOUT=28800 # 8 hour timeout default for nc tunnel
      if { [ "${RUNCMD}" = "psql" ] || [ "${RUNCMD}" = "sqlcmd" ]; } && [ -n "${Inputfile:-}" ]; then
         # Default timeout for restore set to 1 hour. Increase if required.
         TMOUT=3600
      elif [ "${RUNCMD}" = "pg_dump" ] || [ "${RUNCMD}" = "pg_restore" ]; then
         # Default timeout for backup set to 1 hour. Increase if required.
         TMOUT=3600
      fi
   else
     TMOUT="${Timeout}"
   fi

   # If an input file is given, check it exists and is readable
   if [ -n "${Inputfile:-}" ] && [ ! -r "${Inputfile}" ]; then
      echo "Error: invalid input file"
      exit 1
   fi
   if [ -n "${CompressedInput:-}" ] && [ -z "${Inputfile:-}" ]; then
      echo "Error: -c requires an input file specified with -i"
      exit 1
   fi

   # Settings dependant on AKS or Azure backing service
   if [ -z "${AKS:-}" ]; then
      # redis backing service requires TLS set for redis-cli
      TLS="--tls"
      REDIS_PORT=6380
   else
      # redis aks service does not use TLS
      TLS=""
      REDIS_PORT=6379
   fi

   # Set default Redis var if not set
   if [ -z "${Redis:-}" ]; then
      Redis="REDIS_URL"
   fi

   # Set default Postgres var if not set
   if [ -z "${Postgres:-}" ]; then
      Postgres="DATABASE_URL"
   fi

   if [ -z "${SQLServer:-}" ]; then
      SQLServer="SQLSERVER_CONNECTION_STRING"
   fi

   # Set default Quiet var if not set
   if [ -z "${Quiet:-}" ]; then
      Quiet="False"
   fi

   # Get the deployment namespace
   if [[ -z "${NAMESPACE:-}" ]]; then
      NAMESPACE=$(kubectl get deployments -A | grep "${INSTANCE} " | awk '{print $1}')
   fi

   # Set service ports
   DB_PORT=5432

   # Set variables if using a separate deployment to access the database
   if [ -n "${Jumppod:-}" ]; then
      OLDINST=${INSTANCE}
      INSTANCE="konduit-app-${RANDOM}"
      PODJSON=$(cat - << EOF
{
  "apiVersion": "apps/v1",
  "kind": "Deployment",
  "metadata": {
    "name": "${INSTANCE}",
    "labels": {
      "app": "konduit-app"
    }
  },
  "spec": {
    "replicas": 1,
    "selector": {
      "matchLabels": {
        "app": "konduit-app"
      }
    },
    "template": {
      "metadata": {
        "labels": {
          "app": "konduit-app"
        }
      },
      "spec": {
        "automountServiceAccountToken": false,
        "nodeSelector": {
          "teacherservices.cloud/node_pool": "applications",
          "kubernetes.io/os": "linux"
        },
        "containers": [
          {
            "name": "konduit-container",
            "image": "alpine:3.20.1",
            "command": [
              "sh",
              "-c",
              "sleep 10800"
            ],
            "securityContext": {
              "runAsUser": 1000,
              "runAsGroup": 3000,
              "capabilities": {
                "add": [
                  "NET_BIND_SERVICE"
                ],
                "drop": [
                  "ALL"
                ]
              },
              "allowPrivilegeEscalation": false,
              "privileged": false,
              "runAsNonRoot": true,
              "readOnlyRootFilesystem": true,
              "seccompProfile": {
                "type": "RuntimeDefault"
              }
            },
            "resources": {
              "requests": {
                "cpu": "10m",
                "memory": "50Mi"
              },
              "limits": {
                "cpu": "100m",
                "memory": "50Mi"
              }
            },
            "ports": [
              {
                "containerPort": 80
              }
            ]
          }
        ]
      }
    }
  }
}
EOF
)
      if [ "${Quiet}" != "True" ]; then
         echo "Using app ${INSTANCE} to connect to database for ${OLDINST}"
      fi
      echo ${PODJSON} | kubectl -n ${NAMESPACE} create -f - >/dev/null
      sleep 5
   else
      if [ "${Quiet}" != "True" ]; then
         echo "Using app ${INSTANCE} to connect to database"
      fi
   fi
}

check_instance() {
   # make sure it's LC
   INSTANCE=$(echo "${INSTANCE}" | tr '[:upper:]' '[:lower:]')
   # Lets check the container exists and we can connect to it first
   if ! kubectl -n "${NAMESPACE}" exec -i deployment/"${INSTANCE}" -- echo > /dev/null; then
      echo "Error: Container does not exist or connection cannot be established"
      exit 1
   fi
}

is_port_in_use() {
   nc -z 127.0.0.1 $LOCAL_PORT 2>/dev/null
}

set_ports() {
   # Get a random DEST port for the k8 container
   # so there is minimal conflict between users
   DEST_PORT=$RANDOM
   until [ $DEST_PORT -gt 1024 ]; do
      DEST_PORT=$RANDOM
   done

   # Get a random LOCAL port
   # so we can have more than one session if wanted
   LOCAL_PORT=$RANDOM
   # try again if it's in use
   until [[ $LOCAL_PORT -gt 1024 && ! $(is_port_in_use $LOCAL_PORT) ]]; do
      LOCAL_PORT=$RANDOM
   done
}

set_db_psql() {
   PORT=${DB_PORT}
   # Get DB settings
   # Either from the app $DATABASE_URL or the AZURE KV secret
   #
   # Format for backing service
   #     postgres://ADMIN_USER:ADMIN_PASSWORD@s999t01-someapp-rv-review-99999-psql.postgres.database.azure.com:5432/someapp-postgres-review-99999
   # Format for k8 pod
   #     postgres://ADMIN_USER:ADMIN_PASSWORD@someapp-postgres-review-99999:5432/someapp-postgres-review-99999
   #

   if [ -n "${DB_URL_ARG:-}" ]; then
      ORIG_URL="${DB_URL_ARG}"
   elif [ -z "${KV:-}" ]; then
      if [ -z "${Jumppod:-}" ]; then
         ORIG_URL=$(echo "echo \$${Postgres}" | kubectl -n "${NAMESPACE}" exec -i deployment/"${INSTANCE}" -- sh)
      else
         SECRET=$(kubectl -n ${NAMESPACE} get deployment/$OLDINST -o jsonpath='{.spec.template.spec.containers[0].envFrom[1].secretRef.name}')
         ORIG_URL=$(kubectl -n ${NAMESPACE} get secret $SECRET -o jsonpath="{.data.$Postgres}" | base64 --decode)
      fi
   else
      ORIG_URL=$(az keyvault secret show --name "${KVDBName}"-database-url --vault-name "${KV}" | jq -r .value)
   fi
   DB_URL=$(echo "${ORIG_URL}" | sed "s|@.*/|@127.0.0.1:${LOCAL_PORT}/|g")
   DB_HOSTNAME=$(echo "${ORIG_URL}" | awk -F"@" '{print $2}' | awk -F":" '{print $1}')

   # Override the database name if requested
   if [ -n "${DBName:-}" ]; then
      # Replace the database name after the last /, and before ? if it's present
      DB_URL=$(echo "${DB_URL}" | sed "s|/[^/?]*\([?].*\)\?$|/${DBName}\1|")
   fi

   # Override the server name if requested
   if [ -n "${ServerName:-}" ]; then
      DB_HOSTNAME=${ServerName}.postgres.database.azure.com
   fi

   if [ -z "${ORIG_URL:-}" ] || [ -z "${DB_URL:-}" ] || [ -z "${DB_HOSTNAME:-}" ]; then
      echo "Error: invalid DB settings"
      exit 1
   fi
}

set_db_redis() {
   PORT=${REDIS_PORT}
   # Get DB settings
   # Either from the app $REDIS_URL or the AZURE KV secret
   #
   # Format for backing service
   #     rediss://:somepassword=@s9999t99-att-env-redis-service.redis.cache.windows.net:6380/0
   # Format for k8 pod
   #     redis://someapp-redis-review-99999:6379/0

   if [ -n "${DB_URL_ARG:-}" ]; then
      ORIG_URL="${DB_URL_ARG}"
   elif [ -z "${KV:-}" ]; then
      if [ -z "${Jumppod:-}" ]; then
         ORIG_URL=$(echo "echo \$${Redis}" | kubectl -n "${NAMESPACE}" exec -i deployment/"${INSTANCE}" -- sh)
      else
         SECRET=$(kubectl -n ${NAMESPACE} get deployment/$OLDINST -o jsonpath='{.spec.template.spec.containers[0].envFrom[1].secretRef.name}')
         ORIG_URL=$(kubectl -n ${NAMESPACE} get secret $SECRET -o jsonpath="{.data.$Redis}" | base64 --decode)
      fi
   else
      ORIG_URL=$(az keyvault secret show --name "${KVDBName}"-database-url --vault-name "${KV}" | jq -r .value)
   fi

   if [ -z "${AKS:-}" ]; then
      DB_URL=$(echo "${ORIG_URL}" | sed "s|@.*/|@127.0.0.1:${LOCAL_PORT}/|g" | sed "s|rediss://|rediss://default|g")
      DB_HOSTNAME=$(echo "${ORIG_URL}" | awk -F"@" '{print $2}' | awk -F":" '{print $1}')
   else
      DB_URL=$(echo "$ORIG_URL" | sed "s|//.*|//127.0.0.1:${LOCAL_PORT}/|g")
      DB_HOSTNAME=$(echo "$ORIG_URL" | awk -F"/" '{print $3}' | awk -F":" '{print $1}')
   fi

   # Override the database name if requested
   if [ -n "${DBName:-}" ]; then
      DB_URL=$(echo "${DB_URL}" | sed "s|[^/]*$|${DBName}|g")
   fi

   if [ -z "${ORIG_URL:-}" ] || [ -z "${DB_URL:-}" ] || [ -z "${DB_HOSTNAME:-}" ]; then
      echo "Error: invalid DB settings"
      exit 1
   fi
}

connection_string_value() {
   local key="$1"
   printf '%s\n' "${ORIG_URL}" | awk -v key="${key}" '
      function check_token(token, separator, name, value) {
         separator = index(token, "=")
         if (separator == 0) {
            return
         }
         name = substr(token, 1, separator - 1)
         value = substr(token, separator + 1)
         gsub(/^[ \t]+|[ \t]+$/, "", name)
         gsub(/^[ \t]+|[ \t]+$/, "", value)
         if (tolower(name) != tolower(key)) {
            return
         }
         if (substr(value, 1, 1) == "{" && substr(value, length(value), 1) == "}") {
            value = substr(value, 2, length(value) - 2)
            gsub(/}}/, "}", value)
         } else if ((substr(value, 1, 1) == "\"" && substr(value, length(value), 1) == "\"") ||
                    (substr(value, 1, 1) == "\047" && substr(value, length(value), 1) == "\047")) {
            value = substr(value, 2, length(value) - 2)
         }
         print value
         found = 1
      }
      {
         token = ""
         in_braces = 0
         quote = ""
         for (i = 1; i <= length($0); i++) {
            character = substr($0, i, 1)
            if (in_braces) {
               token = token character
               if (character == "}") {
                  if (substr($0, i + 1, 1) == "}") {
                     token = token "}"
                     i++
                  } else {
                     in_braces = 0
                  }
               }
            } else if (quote != "") {
               token = token character
               if (character == quote) {
                  if (substr($0, i + 1, 1) == quote) {
                     token = token quote
                     i++
                  } else {
                     quote = ""
                  }
               }
            } else if (character == ";") {
               check_token(token)
               if (found) {
                  exit
               }
               token = ""
            } else {
               token = token character
               separator = index(token, "=")
               if (separator > 0 && character == "{" && substr(token, separator + 1) ~ /^[ \t]*[{]$/) {
                     in_braces = 1
               } else if (separator > 0 && (character == "\"" || character == "\047") &&
                          substr(token, separator + 1) ~ /^[ \t]*["\047]$/) {
                     quote = character
               }
            }
         }
         check_token(token)
      }'
}

load_sqlserver_envfrom() {
   local references reference resource name prefix data keys
   local available_names=""
   local found="False"
   references=$(printf '%s' "${DEPLOYMENT_JSON}" | jq -c '.spec.template.spec.containers[0].envFrom[]?')
   ORIG_URL=""
   while IFS= read -r reference; do
      [ -n "${reference}" ] || continue
      if printf '%s' "${reference}" | jq -e '.secretRef' >/dev/null; then
         resource="secret"
         name=$(printf '%s' "${reference}" | jq -r '.secretRef.name')
      else
         resource="configmap"
         name=$(printf '%s' "${reference}" | jq -r '.configMapRef.name')
      fi
      prefix=$(printf '%s' "${reference}" | jq -r '.prefix // ""')
      data=$(kubectl -n "${NAMESPACE}" get "${resource}/${name}" -o json)
      keys=$(printf '%s' "${data}" | jq -r --arg prefix "${prefix}" '(.data // {}) | keys[] | $prefix + .')
      available_names="${available_names}${keys}"$'\n'
      if printf '%s' "${data}" | jq -e --arg setting "${SQLServer}" --arg prefix "${prefix}" \
         '(.data // {}) | keys | any(.[]; $prefix + . == $setting)' >/dev/null; then
         ORIG_URL=$(printf '%s' "${data}" | jq -r --arg key "${SQLServer#"${prefix}"}" '.data[$key]')
         if [ "${resource}" = "secret" ]; then
            ORIG_URL=$(printf '%s' "${ORIG_URL}" | base64 --decode)
         fi
         found="True"
      fi
   done <<< "${references}"
   if [ "${found}" != "True" ]; then
      echo "Error: SQL Server setting '${SQLServer}' was not found in deployment '${OLDINST}'." >&2
      echo "Use -m with the SQL connection-string environment-variable name. Available envFrom setting names:" >&2
      printf '%s' "${available_names}" | sed '/^$/d' >&2
      exit 1
   fi
}

set_db_sqlserver() {
   PORT=1433
   if [ -n "${DB_URL_ARG:-}" ]; then
      ORIG_URL="${DB_URL_ARG}"
   elif [ -z "${KV:-}" ]; then
      if [ -z "${Jumppod:-}" ]; then
         ORIG_URL=$(kubectl -n "${NAMESPACE}" exec -i "deployment/${INSTANCE}" -- printenv "${SQLServer}")
      else
         DEPLOYMENT_JSON=$(kubectl -n "${NAMESPACE}" get "deployment/${OLDINST}" -o json)
         ENV_SPEC=$(printf '%s' "${DEPLOYMENT_JSON}" | jq -c --arg name "${SQLServer}" '[.spec.template.spec.containers[]?.env[]? | select(.name == $name)][0] // empty')
         if [ -n "${ENV_SPEC}" ] && printf '%s' "${ENV_SPEC}" | jq -e 'has("value")' >/dev/null; then
            ORIG_URL=$(printf '%s' "${ENV_SPEC}" | jq -r '.value')
         elif [ -n "${ENV_SPEC}" ] && printf '%s' "${ENV_SPEC}" | jq -e '.valueFrom.secretKeyRef' >/dev/null; then
            SECRET=$(printf '%s' "${ENV_SPEC}" | jq -r '.valueFrom.secretKeyRef.name')
            SECRET_KEY=$(printf '%s' "${ENV_SPEC}" | jq -r '.valueFrom.secretKeyRef.key')
            ORIG_URL=$(kubectl -n "${NAMESPACE}" get "secret/${SECRET}" -o "jsonpath={.data.${SECRET_KEY}}" | base64 --decode)
         else
            SQL_CANDIDATES=$(printf '%s' "${DEPLOYMENT_JSON}" | jq -c '[.spec.template.spec.containers[]?.env[]? | select((.value // "") | test("(^|;)[[:space:]]*(Server|Data Source)[[:space:]]*="; "i"))]')
            SQL_CANDIDATE_COUNT=$(printf '%s' "${SQL_CANDIDATES}" | jq 'length')
            if [ "${SQL_CANDIDATE_COUNT}" -eq 1 ]; then
               ORIG_URL=$(printf '%s' "${SQL_CANDIDATES}" | jq -r '.[0].value')
            elif [ "${SQL_CANDIDATE_COUNT}" -gt 1 ]; then
               SQL_CANDIDATE_NAMES=$(printf '%s' "${SQL_CANDIDATES}" | jq -r '[.[].name] | join(", ")')
               echo "Error: multiple SQL Server connection settings found: ${SQL_CANDIDATE_NAMES}. Specify one with -m."
               exit 1
            else
               load_sqlserver_envfrom
            fi
         fi
      fi
   else
      ORIG_URL=$(az keyvault secret show --name "${KVDBName}-database-url" --vault-name "${KV}" | jq -r .value)
   fi

   if [ -z "${ORIG_URL:-}" ] || [ "${ORIG_URL}" = "null" ]; then
      echo "Error: SQL Server connection setting is empty. Check the setting selected with -m or the Key Vault secret." >&2
      exit 1
   fi

   DB_SERVER=$(connection_string_value "Server")
   if [ -z "${DB_SERVER}" ]; then
      DB_SERVER=$(connection_string_value "Data Source")
   fi
   DB_SERVER="${DB_SERVER#tcp:}"
   DB_HOSTNAME="${DB_SERVER%%,*}"
   if [[ "${DB_SERVER}" == *,* ]]; then
      PORT="${DB_SERVER##*,}"
   fi
   DB_DATABASE=$(connection_string_value "Initial Catalog")
   if [ -z "${DB_DATABASE}" ]; then
      DB_DATABASE=$(connection_string_value "Database")
   fi
   DB_USER=$(connection_string_value "User ID")
   if [ -z "${DB_USER}" ]; then
      DB_USER=$(connection_string_value "UID")
   fi
   DB_PASSWORD=$(connection_string_value "Password")
   if [ -z "${DB_PASSWORD}" ]; then
      DB_PASSWORD=$(connection_string_value "Pwd")
   fi

   if [ -n "${DBName:-}" ]; then
      DB_DATABASE="${DBName}"
   fi

   if [ -z "${DB_HOSTNAME:-}" ] || [ -z "${DB_DATABASE:-}" ]; then
      echo "Error: SQL Server connection setting was loaded but is missing required fields:" >&2
      if [ -z "${DB_HOSTNAME:-}" ]; then
         echo "  Server or Data Source" >&2
      fi
      if [ -z "${DB_DATABASE:-}" ]; then
         echo "  Database or Initial Catalog (or specify -b database-name)" >&2
      fi
      exit 1
   fi
   if ! [[ "${PORT}" =~ ^[0-9]+$ ]] || [ "${PORT}" -lt 1 ] || [ "${PORT}" -gt 65535 ]; then
      echo "Error: invalid SQL Server port in connection string"
      exit 1
   fi

   SQL_AUTH="${SQLAuth:-auto}"
   if [ "${SQL_AUTH}" = "auto" ]; then
      if [ -n "${DB_USER}" ] && [ -n "${DB_PASSWORD}" ]; then
         SQL_AUTH="sql"
      else
         SQL_AUTH="entra"
      fi
   fi
   if [ "${SQL_AUTH}" != "sql" ] && [ "${SQL_AUTH}" != "entra" ]; then
      echo "Error: SQL Server authentication mode must be 'sql' or 'entra'"
      exit 1
   fi
   if [ "${SQL_AUTH}" = "sql" ] && { [ -z "${DB_USER}" ] || [ -z "${DB_PASSWORD}" ]; }; then
      echo "Error: SQL login authentication requires User ID and Password in the connection string"
      exit 1
   fi
}

open_tunnels() {
   # Open netcat tunnel between k8 deployment and postgres database
   # Timeout of 8 hours set for an interactive session
   # Testing for kubectl deployment with multiple replicas always hit the same pod (the first one?),
   # will have to revisit if it becomes an issue
   echo 'nc -v -lk -p '${DEST_PORT}' -w '${TMOUT}' -e /usr/bin/nc -w '${TMOUT} "${DB_HOSTNAME}" "${PORT}" | kubectl -n "${NAMESPACE}" exec -i deployment/"${INSTANCE}" -- sh &

   # Open local tunnel to k8 deployment
   kubectl port-forward -n "${NAMESPACE}" deployment/"${INSTANCE}" ${LOCAL_PORT}:${DEST_PORT} &
}

run_psql() {
   if [ -z "${Inputfile:-}" ]; then
      psql -d "$DB_URL" --no-password "${OTHERARGS[@]}"
   elif [ -z "${CompressedInput:-}" ]; then
      psql -d "$DB_URL" --no-password "${OTHERARGS[@]}" <"$Inputfile"
   else
      gzip -d --to-stdout "${Inputfile}" | psql -d "$DB_URL" --no-password "${OTHERARGS[@]}"
   fi
}

run_pgdump() {
   if [ "${#OTHERARGS[@]}" -eq 0 ]; then
      echo "ERROR: Must supply arguments for pg_dump"
      exit 1
   fi
   pg_dump -d "$DB_URL" --no-password "${OTHERARGS[@]}"
}

run_pg_restore() {
   if [ "${#OTHERARGS[@]}" -eq 0 ]; then
      echo "ERROR: Must supply arguments for pg_restore"
      exit 1
   fi
   pg_restore -d "$DB_URL" --no-password "${OTHERARGS[@]}"
}

run_redis() {
   local -a args=(-u "$DB_URL")
   if [ -n "${TLS:-}" ]; then
      args+=("$TLS")
   fi
   redis-cli "${args[@]}" "${OTHERARGS[@]}"
}

run_sqlcmd() {
   local -a args=(-S "tcp:127.0.0.1,${LOCAL_PORT}" -d "${DB_DATABASE}" -N -F "${DB_HOSTNAME}" -b)
   local login="${DB_USER}"
   if [ "${SQL_AUTH}" = "entra" ]; then
      args+=(-G)
      if [ -n "${DB_USER}" ]; then
         args+=(-U "${DB_USER}")
      fi
   else
      # Azure's gateway needs the logical server identity when connecting through localhost.
      if [[ "${DB_HOSTNAME}" == *.database.windows.net && "${login}" != *@* ]]; then
         login="${login}@${DB_HOSTNAME}"
      fi
      args+=(-U "${login}")
   fi

   if [ -n "${Inputfile:-}" ]; then
      if [ -n "${CompressedInput:-}" ]; then
         gzip -d --to-stdout "${Inputfile}" | SQLCMDPASSWORD="${DB_PASSWORD:-}" sqlcmd "${args[@]}" "${OTHERARGS[@]}"
      else
         SQLCMDPASSWORD="${DB_PASSWORD:-}" sqlcmd "${args[@]}" "${OTHERARGS[@]}" -i "${Inputfile}"
      fi
   elif [ -n "${DB_PASSWORD:-}" ]; then
      SQLCMDPASSWORD="${DB_PASSWORD}" sqlcmd "${args[@]}" "${OTHERARGS[@]}"
   else
      sqlcmd "${args[@]}" "${OTHERARGS[@]}"
   fi
}

cleanup() {
   unset DB_URL DB_HOSTNAME ORIG_URL
   pkill -15 -f "kubectl port-forward.*${LOCAL_PORT}"
   sleep 3 # let the port-forward finish
   if [ -n "${Jumppod:-}" ]; then
      echo ${PODJSON} | kubectl -n ${NAMESPACE} delete -f -
   else
      kubectl -n "${NAMESPACE}" exec -i deployment/"${INSTANCE}" -- pkill -15 -f "nc -v -lk -p ${DEST_PORT}"
   fi
   trap - EXIT
   exit
}

# Get the options
while getopts "ahcxqd:i:k:r:n:p:s:t:u:b:e:m:" option; do
   case $option in
   a)
      AKS="True"
      ;;
   b)
      DBName=$OPTARG
      ;;
   e)
      SQLAuth=$OPTARG
      ;;
   c)
      CompressedInput="True"
      ;;
   d)
      KVDBName=$OPTARG
      ;;
   k)
      KV=$OPTARG
      ;;
   m)
      SQLServer=$OPTARG
      ;;
   i)
      Inputfile=$OPTARG
      ;;
   n)
      NAMESPACE=$OPTARG
      ;;
   p)
      Postgres=$OPTARG
      ;;
   q)
      Quiet="True"
      ;;
   r)
      Redis=$OPTARG
      ;;
   s)
      ServerName=$OPTARG
      ;;
   t)
      Timeout=$OPTARG
      ;;
   u)
      DB_URL_ARG=$OPTARG
      ;;
   x)
      Jumppod="True"
      ;;
   h)
      help
      exit
      ;;
   \?)
      echo "Error: Invalid option"
      exit 1
      ;;
   esac
done
shift "$((OPTIND - 1))"
INSTANCE=${1:-}
if [ -z "$INSTANCE" ]; then
   echo "Error: Must provide instance name as parameter e.g. apply-qa, apply-review-1234"
   help
   exit 1
fi
# $2 is --
RUNCMD=${3:-}
if [[ -z "$RUNCMD" ]]; then
   echo "Error: missing command name"
   help
   exit 1
fi
shift 3
OTHERARGS=("$@")

###
### Main
###

trap 'cleanup >/dev/null 2>&1 || true' EXIT SIGHUP SIGTERM
init_setup
check_instance
set_ports
# Get DB settings and set the CMD to run
case $RUNCMD in
psql)
   set_db_psql
   CMD="run_psql"
   ;;
pg_dump)
   set_db_psql
   CMD="run_pgdump"
   ;;
pg_restore)
   set_db_psql
   CMD="run_pg_restore"
   ;;
redis-cli)
   set_db_redis
   CMD="run_redis"
   ;;
sqlcmd)
   set_db_sqlserver
   CMD="run_sqlcmd"
   ;;
esac
open_tunnels >/dev/null 2>&1
sleep 5 # Need to allow the connections to open
$CMD    # Run the command
