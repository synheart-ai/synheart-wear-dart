raw prompt

there is some changes in the service so we need to update this sdk, in the werable connection from cloud for the whoop and garmin the auto flow is changes the v2 auth is this so update the Sdk

Managed OAuth


GET
/auth/callback/{provider}
Unified OAuth Callback (UI)
Endpoint for OAuth providers to redirect users back to Synheart. Completes the handshake server-side and redirects to the app.

Parameters
Try it out
Name	Description
provider *
string
(path)
Provider (whoop, garmin)

provider
code *
string
(query)
Authorization code from provider

code
state *
string
(query)
Secure CSRF state

state
Responses
Response content type

text/html
Code	Description

POST
/auth/connect/{provider}
Initiate OAuth Connection (Managed)
Starts the "Managed" OAuth flow. Returns a secure authorization URL and state. End-users will be redirected back to the integration's configured redirect_uri upon completion.

Parameters
Try it out
Name	Description
provider *
string
(path)
Provider (whoop, garmin)

provider
request *
object
(body)
Connection parameters

Example Value
Model
{
  "app_id": "app-123",
  "user_id": "user-456"
}
Parameter content type

application/json
Responses
Response content type

application/json
Code	Description
200
OK

Example Value
Model
{
  "authorization_url": "https://api.whoop.com/oauth/authorize?...",
  "state": "random_state_string"
}
400
Bad Request

Example Value
Model
{
  "details": "app_id is required",
  "error": "Bad Request",
  "message": "Invalid request parameters"
}


THE SDK is when connect it send the app id and user id and also need a header sqeurity every request from the SDK need the app id that the platform give and the app api key those env are important so we need thsi every request so after send connect the wear service validat the request and start oauth flow then reutrn the auth url then the SDK open that URL and after user login we dont need the callback auth callback here in the SDK in the enw upate he callback is handled by the wear service so after login the provider redirect to user our callback then after we change the token and other staff then redirect the user to returl url the user set in the configeration integration in the plaform so update all auth flow for the cloud with this remove old one and clean up the SDK and then


in the data fetch from whoop and garmin the SDK also have to use this api to featch dails data from the wear service for whoop
			r.Get("/whoop/data/{user_id}/recovery", h.GetWHOOPData)
			r.Get("/whoop/data/{user_id}/sleep", h.GetWHOOPData)
			r.Get("/whoop/data/{user_id}/cycles", h.GetWHOOPData)

we have this apis this api will use to featch the data from wear servie

GET
/whoop/data/{user_id}/recovery
Get WHOOP data
Fetches data from WHOOP (recovery, sleep, workouts, cycles)

Parameters
Try it out
Name	Description
user_id *
string
(path)
User ID

user_id
app_id *
string
(query)
App ID

app_id
project_id *
string
(query)
Project ID

project_id
start
string
(query)
Start time (RFC3339)

start
end
string
(query)
End time (RFC3339)

end
limit
integer
(query)
Limit

Default value : 10

10
cursor
string
(query)
Pagination cursor

cursor
Responses
Response content type

application/json
Code	Description
200
OK

Example Value
Model
{
  "app_id": "app-123",
  "cursor": "next_page_token",
  "data_type": "recovery",
  "has_more": true,
  "records": [
    {
      "additionalProp1": {}
    }
  ],
  "user_id": "user-123",
  "vendor": "whoop"
}
400
Bad Request

Example Value
Model
{
  "details": "app_id is required",
  "error": "Bad Request",
  "message": "Invalid request parameters"
}

and for garmin also we have this
			// Garmin data endpoints
			r.Get("/garmin/data/{user_id}/dailies", h.GetGarminData)
			r.Get("/garmin/data/{user_id}/sleep", h.GetGarminData)

but the garmin is diffrent the data for this request will arrive thoth real time connection we have a serviveec called ramen service its inspired by uber ream grpc push notificaiton service that push the real time data to the grcp connected mobile clients to the sdk so our ramen service details are here @SDK_GUIDE.md  @SDK_RFC.md
so analize this SDK docs and understand about the reamn service the SDK need to integration this and also this reamn connction will activate when the app is active so also add this logics in the connection and also for the requested data designt he SDK profficenal and refactor all the SDK and you can remove any thing






Plan
SDK Cloud Auth, Data APIs, and RAMEN Integration Plan

Summary of Changes







Area



Current



New





OAuth



GET authorize + POST callback in SDK



POST /auth/connect/{provider} → open URL → callback handled by wear service





Auth Headers



app_id in query only



x-app-id + x-api-key on every request





WHOOP Data



/v1/{vendor}/data/...



/whoop/data/{user_id}/{recovery,sleep,cycles} + project_id





Garmin Data



REST + webhooks



REST for dailies/sleep + RAMEN gRPC for real-time push





Connection State



SDK completes OAuth with code



Wear service completes; app receives deep link to return URL



1. Configuration Updates

File: src/main/kotlin/ai/synheart/wear/config/CloudConfig.kt





Add appApiKey: String (required) — API key from platform



Add projectId: String? (optional) — for WHOOP/Garmin data queries



Remove or deprecate redirectUri — no longer used for OAuth callback in SDK



Add ramenServiceUrl: String? — gRPC endpoint for RAMEN (e.g. https://ramen.synheart.ai or host:port)



Add returnUrl: String? — optional; for documentation/deep link handling (platform config drives actual redirect)



2. Managed OAuth v2 Flow

Remove:





completeOAuthFlow / connectWithCode — callback no longer handled by SDK



getAuthorizationUrl (GET) and handleOAuthCallback (POST) API calls



OAuth state persistence for callback validation (state still returned for optional app-side checks)

Add:





POST /auth/connect/{provider} with body { app_id, user_id }



Response: { authorization_url, state }



SDK returns authorization_url; app opens it in browser/Chrome Custom Tab



After login, provider redirects to wear service; wear service completes token exchange and redirects to platform-configured return URL



SDK needs a way to mark user as connected: markUserConnected(userId: String) — called when app receives success from return URL deep link (or after polling a "connection status" endpoint if one exists)

Files to modify:





WearServiceAPI.kt — replace OAuth endpoints



CloudModels.kt — add ConnectRequest, ConnectResponse



CloudWearableAdapter.kt — new connect flow, remove callback handling



WhoopProvider.kt — use new connect, remove connectWithCode



GarminProvider.kt — same



WearableProvider.kt — update interface: connect(userId: String) returns URL; add markConnected(userId: String) or similar



3. Request Authentication (Headers)

File: WearServiceAPI.kt and OkHttp/Retrofit setup





Add OkHttp interceptor that injects:





x-app-id: {cloudConfig.appId}



x-api-key: {cloudConfig.appApiKey}



Apply to all Wear Service requests



Remove app_id from query params where headers are sufficient (or keep for backward compatibility if service expects both)

Files: All adapters that create Retrofit/OkHttp clients (CloudWearableAdapter, WhoopProvider, GarminProvider) — centralize client creation with auth interceptor.



4. WHOOP Data API Alignment

Current: GET /v1/{vendor}/data/{user_id}/{type} with app_id in query

New (per user spec):





GET /whoop/data/{user_id}/recovery



GET /whoop/data/{user_id}/sleep



GET /whoop/data/{user_id}/cycles

Query params: app_id, project_id, start, end, limit, cursor

Files:





WearServiceAPI.kt — update paths and add project_id



WhoopProvider.kt — use new endpoints, pass project_id from config



Response envelope: data_type, has_more (add to CloudModels if needed)



5. Garmin Data API Alignment

REST (historical/manual fetch):





GET /garmin/data/{user_id}/dailies



GET /garmin/data/{user_id}/sleep

Query params: app_id, project_id, start, end, limit, cursor (as applicable)

Real-time: Via RAMEN gRPC (see Section 6)

Files:





WearServiceAPI.kt — align Garmin REST paths



GarminProvider.kt — use new endpoints; real-time data comes from RAMEN



6. RAMEN Service Integration (gRPC)

Purpose: Real-time push of Garmin (and potentially WHOOP) events to the SDK.

Architecture (from SDK_RFC.md and SDK_GUIDE.md):

sequenceDiagram
    participant App
    participant SDK
    participant RAMEN as RAMEN gRPC
    participant Wear as Wear Service REST

    Note over App: App in Foreground
    App->>SDK: initialize / resume
    SDK->>RAMEN: Subscribe(deviceId, userId, lastSeq)
    RAMEN->>SDK: connection_id, current_highest_seq
    loop Every 30s
        SDK->>RAMEN: Heartbeat
        RAMEN->>SDK: HeartbeatAck
    end
    RAMEN->>SDK: EventEnvelope
    SDK->>App: emit event
    SDK->>RAMEN: Ack(seq)
    SDK->>SDK: persist lastSeq
    Note over App: App in Background
    App->>SDK: pause
    SDK->>RAMEN: close stream

Implementation tasks:





Proto and gRPC setup





Add ramen.proto (or obtain from monorepo api/proto/ramen/) to src/main/proto/



Add protobuf + gRPC plugins and dependencies to build.gradle.kts



Generate Kotlin/Java stubs for Subscribe, SubscribeRequest, SubscribeResponse, EventEnvelope, Ack, Heartbeat, HeartbeatAck



RamenClient module





New package: ai.synheart.wear.ramen



RamenClient: manages gRPC channel, bidirectional stream, reconnection with exponential backoff



SubscribeRequest: device_id, user_id, last_seq



On EventEnvelope: emit to Flow<EventEnvelope>, send Ack(seq), persist last_seq (Room/SQLite/SharedPreferences)



Heartbeat every 30s; on 2 missed acks, close and reconnect



Lifecycle: connect when app is foreground, disconnect when background



App lifecycle integration





Use ProcessLifecycleOwner or Application.ActivityLifecycleCallbacks to detect foreground/background



When app goes to background: close RAMEN stream



When app comes to foreground: reopen stream with stored lastSeq



Persistence





Store last_acknowledged_seq per user (or per device) in SharedPreferences or a small local DB



On reconnect, send stored lastSeq in SubscribeRequest



Authentication





Add x-app-id and x-api-key to gRPC call metadata (per SDK_GUIDE.md)

Files to create:





src/main/proto/ramen.proto (or copy from api module)



ai.synheart.wear.ramen.RamenClient



ai.synheart.wear.ramen.RamenConfig



ai.synheart.wear.ramen.AppLifecycleObserver (or integrate with existing lifecycle)

Dependencies to add:





io.grpc:grpc-okhttp



io.grpc:grpc-protobuf



io.grpc:grpc-stub



com.google.protobuf:protobuf-java (or Kotlin)



Protobuf Gradle plugin



7. SDK Structure Refactor and Cleanup

Consolidation:





CloudWearableAdapter — keep as thin adapter for WearAdapter (readSnapshot, etc.); delegate to provider for OAuth and data



WhoopProvider — WHOOP-specific: Managed OAuth, WHOOP REST data (recovery, sleep, cycles)



GarminProvider — Garmin-specific: Managed OAuth, Garmin REST (dailies, sleep), RAMEN for real-time



Remove duplicate OAuth logic; single code path for both WHOOP and Garmin using new connect API

Remove/deprecate:





Old OAuth endpoints and models



connectWithCode from WearableProvider (replace with markConnected(userId) for when app gets success from return URL)



Garmin webhook/backfill complexity if not used by mobile SDK (or keep for server-side docs only)



Unused integration endpoints if not needed by SDK

WearableProvider interface changes:

// Before
suspend fun connect(): String
suspend fun connectWithCode(code: String, state: String, redirectUri: String): String

// After
suspend fun connect(userId: String): String  // returns auth URL
fun markConnected(userId: String)  // call when app receives success from return URL



8. Data Flow Summary

flowchart TB
    subgraph OAuth [Managed OAuth v2]
        A[App calls connect userId] --> B[SDK POST /auth/connect/provider]
        B --> C[Wear Service returns auth_url, state]
        C --> D[SDK returns auth_url to app]
        D --> E[App opens URL in browser]
        E --> F[User authorizes at provider]
        F --> G[Provider redirects to Wear Service callback]
        G --> H[Wear Service exchanges token, redirects to return URL]
        H --> I[App receives deep link]
        I --> J[App calls markConnected userId]
    end

    subgraph WHOOP_Data [WHOOP Data]
        K[App requests data] --> L[SDK GET /whoop/data/user_id/type]
        L --> M[Wear Service returns records]
    end

    subgraph Garmin_Data [Garmin Data]
        N[Historical] --> O[SDK GET /garmin/data/user_id/dailies or sleep]
        P[Real-time] --> Q[RAMEN gRPC push]
        Q --> R[SDK emits Flow to app]
    end



9. Testing Updates





Update CloudWearableAdapterTest.kt, WhoopProviderTest.kt, GarminProviderTest.kt for new OAuth flow and API paths



Add unit tests for RamenClient (with mock gRPC)



Update CloudConfigTest.kt for new fields



10. Documentation Updates





Update SDK_GUIDE.md with Managed OAuth flow and RAMEN integration steps



Update SDK_RFC.md if needed for v2 auth



Add migration notes for apps using connectWithCode



Open Questions for User





Connection confirmation: How does the app learn that OAuth succeeded? Does the return URL include ?success=true&user_id=xxx, or is there a separate "connection status" API the SDK should poll?



Proto source: Is ramen.proto available in this repo or another (e.g. api module)? If not, we need the schema to generate stubs.



Ramen URL: What is the production RAMEN gRPC endpoint (host:port or URL)?



project_id: Is project_id required for all WHOOP/Garmin data calls, or optional?

