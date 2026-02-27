# .bru Feature Parity

Tracking which `.bru` file features are supported by bx.

| Feature | Status | Notes |
|---------|--------|-------|
| GET/POST/PUT/PATCH/DELETE | Supported | |
| OPTIONS/HEAD | Supported | |
| Headers | Supported | Disabled (`~`) and comments (`//`) handled |
| Query params | Supported | Both `query` and `params:query` |
| body:json | Supported | Nested braces handled |
| body:form-urlencoded | Supported | |
| body:multipart-form | Supported | File references (`@`) supported |
| body:xml | Supported | |
| body:text | Supported | |
| body:graphql | Supported | |
| body:graphql:vars | Supported | |
| auth:bearer | Supported | |
| auth:basic | Supported | |
| auth:digest | Not yet | Planned |
| auth:oauth2 | Not yet | Planned |
| Environment variables | Supported | vars + vars:secret |
| Collection-level headers | Supported | From collection.bru |
| Collection-level auth | Supported | From collection.bru |
| Pre-request scripts | Won't add | JavaScript -- out of scope |
| Post-response scripts | Won't add | JavaScript -- out of scope |
| Tests/assertions | Won't add | Use Bruno CLI for test runs |
| Client certificates | Not yet | Planned |
| Proxy support | Not yet | Planned |
| .env file loading | Not yet | Planned |
