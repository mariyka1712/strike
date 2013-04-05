require.once net/http;
require.once json;

declare -g couchdb_url;
declare -g couchdb_dbname;
declare -g couchdb_user="";
declare -g couchdb_pass="";
declare -g couchdb_path="";

#default write out
#write out the data as non-json
declare -g couchdb_expects="";

declare -g couchdb_result_method="";
declare -g couchdb_result_url="";
declare -g couchdb_result_status="";

declare -g couchdb_module_name="couchdb";

declare -g couchdb_session_login_auth_token="";

#function rest_result_parse {
# local opts=( "${@}" );
# echo "got rest_result_parse opts ${opts[@]}";
#}

# > HOST="https://ffsys.cloudant.com"
# > curl -vX POST $HOST/_session -H 'Content-Type: application/x-www-form-urlencoded' -d 'name=anna&password=secret'

# > curl -vX PUT $HOST/_all_dbs --cookie AuthSession=ZmZzeXM6NTBGNjdEOTY6vAyRr5A7XWPxDum-jkXglKKXgxU -H "X-CouchDB-WWW-Authenticate: Cookie" -H "Content-Type: application/x-www-form-urlencoded"
# {"ok":true}

# Set-Cookie: AuthSession=ZmZzeXM6NTBGNjdEOTY6vAyRr5A7XWPxDum-jkXglKKXgxU; Version=1; Path=/; HttpOnly

# centralized entry point for couchdb(3)
# http(3) requests so that it's easier to
# add before/after debugging statements
couchdb.run() {
  local opts=( "$@" );

  opts+=( "-H" "Content-Type: application/json" );

  # add session cookie authentication information
  if [ -n "${couchdb_session_login_auth_token:-}" ]; then
    opts+=( "-H" "X-CouchDB-WWW-Authenticate: Cookie" );
    opts+=( "-H" "Content-Type: application/x-www-form-urlencoded" );
    opts+=( "--cookie" "$couchdb_session_login_auth_token" );
  fi
  
  #echo "$FUNCNAME : using opts : ${#opts[@]} : ${opts[@]}";
  
  http.curl "${opts[@]}";
}

couchdb.session.login() {
  local host="${1:-}";
  local user="${2:-}";
  local pass="${3:-}";
  if [ -n "$host" ] && [ -n "$user" ] && [ -n "$pass" ]; then
    couchdb.run "POST" "${host}/_session" \
      "-H" "Content-Type: application/x-www-form-urlencoded" \
      "-d" "name=${user}&password=${pass}";
      
    local cookie="${http_header_0_set_cookie:-}";
    if [ -z "$cookie" ]; then
      console warn "could not retrieve cookie header information for couchdb session login";
    else
      #AuthSession=ZmZzeXM6NTBGNjgwOEM6ROf3Gcfux_kfV_x3VDmRPCGaQ84; Version=1; Path=/; HttpOnly
      couchdb_session_login_auth_token="${cookie%%;*}";
      #couchdb_session_login_auth_token="${couchdb_session_login_auth_token#AuthSession=}";
      echo "got auth session token: $couchdb_session_login_auth_token";
    fi
    
    #echo "got set cookie header: $http_header_0_set_cookie";
  fi
}

# updates the http(3) authentication information
# based on the current couchdb(3) authentication
couchdb.auth.update() {
  if [ -n "$couchdb_user" ] && [ -n "$couchdb_pass" ]; then
    http_auth_user="${couchdb_user}";
    http_auth_pass="${couchdb_pass}";
  fi
}

# TODO: deprecate
# sets the host and database name in use
couchdb.db() {
    local host="${1:-}";
    local dbname="${2:-}";
    host="${host%/}";
    couchdb_host="${host}";
    couchdb_dbname="${dbname}";
    couchdb_path="${host}/${dbname}";
}

couchdb.tasks() {
  local host="${1:-}";
  couchdb.run "GET" "${host}/_active_tasks";
}

couchdb.stats() {
  local host="${1:-}";
  couchdb.run "GET" "${host}/_stats";
}

couchdb.log() {
  local host="${1:-}";
  couchdb.run "GET" "${host}/_log";
}

couchdb.restart() {
  local host="${1:-}";
  couchdb.run "POST" "${host}/_restart";
}

couchdb.uuids() {
  local host="${1:-}";
  local count="${2:-}";
  local url="${host}/_uuids";
  if [[ "${count}" =~ ^[0-9]+$ ]]; then
    url+="?count=${count}";
  fi
  couchdb.run "GET" "${url}";
}

couchdb.db.list() {
  local host="${1:-}";
  #couchdb.auth.update;
  couchdb.run "GET" "${host}/_all_dbs";
}

couchdb.db.changes() {
  local host="${1:-}";
  local db="${2:-}";
  couchdb.run "GET" "${host}/${db}/_changes";
}

couchdb.db.revslimit() {
  local host="${1:-}";
  local db="${2:-}";
  local amount="${3:-}";
  local url="${host}/${db}/_revs_limit";
  if [[ "${amount}" =~ ^[0-9]+$ ]]; then
    couchdb.run "PUT" "${url}" "-d" "${amount}";
  else
    couchdb.run "GET" "${url}";
  fi
}

couchdb.db.add() {
  local host="${1:-}";
  local db="${2:-}";
  couchdb.run "PUT" "${host}/${db}";
}

couchdb.db.rm() {
  local host="${1:-}";
  local db="${2:-}";
  couchdb.run "DELETE" "${host}/${db}";
}

couchdb.db.compact() {
  local host="${1:-}";
  local db="${2:-}";
  local design="${3:-}";
  local url="${host}/${db}/_compact";
  if [ -n "${design}" ]; then
    url+="/${design}";
  fi
  couchdb.run "POST" "${url}";
}

couchdb.db.cleanup() {
  local host="${1:-}";
  local db="${2:-}";
  couchdb.run "POST" "${host}/${db}/_view_cleanup";
}

couchdb.db.info() {
  local host="${1:-}";
  local db="${2:-}";
  couchdb.run "GET" "${host}/${db}";
}

couchdb.db.alldocs() {
  local host="${1:-}";
  local db="${2:-}";
  local querystring="${3:-}";
  local url="${host}/${db}/_all_docs"
  if [ -n "$querystring" ]; then
    url+="${querystring}";
  fi
  couchdb.run "GET" "${url}";
}

couchdb.doc.get() {
  local host="${1:-}";
  local db="${2:-}";
  local id="${3:-}";
  local url="${host}/${db}/${id}";
  couchdb.run "GET" "${url}";
}

couchdb.doc.rm() {
  local host="${1:-}";
  local db="${2:-}";
  local id="${3:-}";
  local rev="${4:-}";
  local url="${host}/${db}/${id}?rev=${rev}";
  couchdb.run "DELETE" "${url}";
}

couchdb.doc.head() {
  local host="${1:-}";
  local db="${2:-}";
  local id="${3:-}";
  local url="${host}/${db}/${id}";
  couchdb.run "GET" "${url}" --head;
}

couchdb.doc.save() {
  local host="${1:-}";
  local db="${2:-}";
  local doc="${3:-}";
  local id="${4:-}";
  if [ -f "${doc}" ]; then
    local url="${host}/${db}";
    local method="POST";
    if [ -n "${id}" ]; then
      url+="/${id}";
      method="PUT";
    fi
    couchdb.run "${method}" "${url}" \
      -# --data-binary "@${doc}";
  fi
}

# query a view document
couchdb.view() {
  local viewdoc="${1:-views}";
  local view="${2:-}";
  local querystring="${3:-}";
  local path="_design/${viewdoc}/_view/${view}";
  
  if [ -n "$querystring" ]; then
    path="${path}${querystring}";
  fi
  
  #if [ ! -z "$couchdb_view_options" ]; then
  # echo "got view options...";
  #fi
  http_curl "GET" "${path}";
  
  #reset the view options
  #couchdb_view_options="";
}

# DEPRECATED
function couchdb_print {
  console info "[%s] %s %s" "$couchdb_result_status" "$couchdb_result_method" "$couchdb_result_url";
}

function couchdb_head {
  local path="${1:-/}";
  http_curl "HEAD" "$path" "-I";
}

function couchdb_get {
  local path="${1:-/}";
  http_curl "GET" "$path";
}

function couchdb_put {
  local path="${1:-/}";
  http_curl "PUT" "$path";
}

function couchdb_put_file {
  local path="${1:-/}";
  local file="${2:-}";
  http_curl "PUT" "$path" "--data-binary" "@${file}";
}

function couchdb_put_data {
  local path="${1:-/}";
  local data="${2:-}";
  http_curl "PUT" "$path" "-H" "'Content-Type: application/json'" "-d" "'$data'";
}

function couchdb_info {
  http_curl "GET" "/";
}

function couchdb_get_url {
  local path=${1:-};
  local db=${2:-"$couchdb_dbname"};
  local out="${couchdb_url}/$db";
  http_base_url="$out";
  
  #strip any leading slash
  #path=${path#/};
  #out="${out}/${path}";
  #_result="$out";
}

function couchdb_auth {
  local url="$1"; 
  local dbname="$2";
  local user="${3:-}";
  local pass="${4:-}";
  
  local module="$couchdb_module_name";
  
  eval "${module}_url"="$url";
  eval "${module}_dbname"="$dbname";
  eval "${module}_user"="$user";
  eval "${module}_pass"="$pass";
  
  couchdb_get_url;
  
  #echo "$couchdb_url";
  #echo "$couchdb_dbname";  
}
