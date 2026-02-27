#!/usr/bin/env bash
# test/test_parser.sh — Tests for .bru file parsing

# Source the modules
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/output.sh"
source "$PROJECT_ROOT/lib/env.sh"
source "$PROJECT_ROOT/lib/parser.sh"

FIXTURES="$PROJECT_ROOT/test/fixtures"
SAMPLE="$FIXTURES/sample-collection"
EDGE="$FIXTURES/edge-cases"

# -- HTTP Method Parsing --

test_parse_get_method() {
  parse_bru_file "$SAMPLE/users/get-user.bru"
  assert_eq "GET" "$BX_METHOD" "parse GET method"
}

test_parse_post_method() {
  parse_bru_file "$SAMPLE/users/create-user.bru"
  assert_eq "POST" "$BX_METHOD" "parse POST method"
}

test_parse_put_method() {
  parse_bru_file "$EDGE/put-request.bru"
  assert_eq "PUT" "$BX_METHOD" "parse PUT method"
}

test_parse_patch_method() {
  parse_bru_file "$EDGE/patch-request.bru"
  assert_eq "PATCH" "$BX_METHOD" "parse PATCH method"
}

test_parse_delete_method() {
  parse_bru_file "$EDGE/all-methods.bru"
  assert_eq "DELETE" "$BX_METHOD" "parse DELETE method"
}

test_parse_options_method() {
  parse_bru_file "$EDGE/options-request.bru"
  assert_eq "OPTIONS" "$BX_METHOD" "parse OPTIONS method"
}

test_parse_head_method() {
  parse_bru_file "$EDGE/head-request.bru"
  assert_eq "HEAD" "$BX_METHOD" "parse HEAD method"
}

# -- URL Parsing --

test_parse_url_with_variables() {
  parse_bru_file "$SAMPLE/users/get-user.bru"
  assert_eq "{{baseUrl}}/users/{{userId}}" "$BX_URL" "parse URL with variables"
}

test_parse_url_with_port() {
  parse_bru_file "$EDGE/special-chars.bru"
  assert_contains "$BX_URL" ":8080" "URL with port number"
}

# -- Header Parsing --

test_parse_headers() {
  parse_bru_file "$SAMPLE/users/get-user.bru"
  assert_eq "2" "${#BX_HEADERS[@]}" "parse correct number of headers"
  assert_contains "${BX_HEADERS[0]}" "Accept" "first header key"
  assert_contains "${BX_HEADERS[1]}" "X-Request-Id" "second header key"
}

test_skip_disabled_headers() {
  parse_bru_file "$EDGE/disabled-headers.bru"
  assert_eq "2" "${#BX_HEADERS[@]}" "skip disabled headers"
  assert_contains "${BX_HEADERS[0]}" "Accept" "first enabled header"
  assert_contains "${BX_HEADERS[1]}" "X-Enabled" "second enabled header"
}

test_no_headers() {
  parse_bru_file "$EDGE/no-headers.bru"
  assert_eq "0" "${#BX_HEADERS[@]}" "no headers is valid"
}

test_headers_with_colons_in_value() {
  parse_bru_file "$EDGE/special-chars.bru"
  assert_eq "2" "${#BX_HEADERS[@]}" "headers with colons in values"
  assert_contains "${BX_HEADERS[0]}" "abc:def:ghi" "colon in bearer value"
}

# -- Query Params --

test_parse_query_params() {
  parse_bru_file "$SAMPLE/users/get-user.bru"
  assert_eq "1" "${#BX_QUERY_PARAMS[@]}" "parse query params (skip disabled)"
  assert_contains "${BX_QUERY_PARAMS[0]}" "include" "query param key"
}

test_parse_query_block() {
  parse_bru_file "$EDGE/query-block.bru"
  assert_eq "3" "${#BX_QUERY_PARAMS[@]}" "parse query block (skip disabled+comments)"
  assert_contains "${BX_QUERY_PARAMS[0]}" "page" "first query param"
  assert_contains "${BX_QUERY_PARAMS[1]}" "limit" "second query param"
  assert_contains "${BX_QUERY_PARAMS[2]}" "search" "third query param"
}

# -- Body:JSON Parsing --

test_parse_json_body() {
  parse_bru_file "$SAMPLE/users/create-user.bru"
  assert_eq "json" "$BX_BODY_TYPE" "body type is json"
  assert_contains "$BX_BODY" '"name"' "JSON body contains name field"
  assert_contains "$BX_BODY" '"nested"' "JSON body contains nested object"
}

test_parse_nested_json_body() {
  parse_bru_file "$EDGE/multiline-body.bru"
  assert_eq "json" "$BX_BODY_TYPE" "body type is json"
  assert_contains "$BX_BODY" '"deeply"' "deeply nested body"
  assert_contains "$BX_BODY" '"levels"' "nested levels"
}

test_parse_empty_json_body() {
  parse_bru_file "$EDGE/empty-body.bru"
  # Empty body:json block should result in empty body
  assert_eq "none" "$BX_BODY_TYPE" "empty body block results in no body type"
}

# -- Body:form-urlencoded --

test_parse_form_body() {
  parse_bru_file "$EDGE/form-body.bru"
  assert_eq "form" "$BX_BODY_TYPE" "body type is form"
  assert_eq "2" "${#BX_BODY_FORM[@]}" "form body has 2 fields (disabled skipped)"
  assert_contains "${BX_BODY_FORM[0]}" "username" "form username field"
  assert_contains "${BX_BODY_FORM[1]}" "password" "form password field"
}

# -- Body:multipart-form --

test_parse_multipart_body() {
  parse_bru_file "$EDGE/multipart-body.bru"
  assert_eq "multipart" "$BX_BODY_TYPE" "body type is multipart"
  assert_eq "2" "${#BX_BODY_FORM[@]}" "multipart has 2 fields"
  assert_contains "${BX_BODY_FORM[1]}" "@" "file reference"
}

# -- Body:xml --

test_parse_xml_body() {
  parse_bru_file "$EDGE/xml-body.bru"
  assert_eq "xml" "$BX_BODY_TYPE" "body type is xml"
  assert_contains "$BX_BODY" "<user>" "XML contains user element"
}

# -- Body:text --

test_parse_text_body() {
  parse_bru_file "$EDGE/text-body.bru"
  assert_eq "text" "$BX_BODY_TYPE" "body type is text"
  assert_contains "$BX_BODY" "plain text" "text body content"
}

# -- Body:graphql --

test_parse_graphql_body() {
  parse_bru_file "$EDGE/graphql-body.bru"
  assert_eq "graphql" "$BX_BODY_TYPE" "body type is graphql"
  assert_contains "$BX_BODY" "users" "graphql query"
  assert_contains "$BX_BODY_GRAPHQL_VARS" '"limit"' "graphql vars"
}

# -- Auth:bearer --

test_parse_bearer_auth() {
  parse_bru_file "$SAMPLE/users/get-user.bru"
  assert_eq "bearer" "$BX_AUTH_TYPE" "auth type is bearer"
  assert_eq "{{token}}" "$BX_AUTH_TOKEN" "bearer token value"
}

# -- Auth:basic --

test_parse_basic_auth() {
  parse_bru_file "$EDGE/basic-auth.bru"
  assert_eq "basic" "$BX_AUTH_TYPE" "auth type is basic"
  assert_eq "{{user}}" "$BX_AUTH_USER" "basic auth username"
  assert_eq "{{pass}}" "$BX_AUTH_PASS" "basic auth password"
}

# -- Script/test/docs blocks (should be ignored) --

test_ignore_script_blocks() {
  parse_bru_file "$EDGE/with-scripts.bru"
  assert_eq "GET" "$BX_METHOD" "method parsed despite script blocks"
  assert_eq "1" "${#BX_HEADERS[@]}" "headers parsed despite script blocks"
}

# -- CRLF line endings --

test_parse_crlf() {
  parse_bru_file "$EDGE/crlf-line-endings.bru"
  assert_eq "GET" "$BX_METHOD" "parse CRLF file method"
  assert_eq "2" "${#BX_HEADERS[@]}" "parse CRLF file headers"
}

# -- Collection.bru parsing --

test_parse_collection_bru() {
  BX_COLLECTION_HEADERS=()
  BX_COLLECTION_AUTH_TYPE="none"
  BX_COLLECTION_AUTH_TOKEN=""
  parse_collection_bru "$SAMPLE/collection.bru"
  assert_eq "2" "${#BX_COLLECTION_HEADERS[@]}" "collection headers count"
  assert_eq "bearer" "$BX_COLLECTION_AUTH_TYPE" "collection auth type"
  assert_eq "{{collectionToken}}" "$BX_COLLECTION_AUTH_TOKEN" "collection auth token"
}
