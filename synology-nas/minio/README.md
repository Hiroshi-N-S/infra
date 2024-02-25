# README

- [README](#readme)
  - [Configuring Authentication](#configuring-authentication)
    - [Configure MinIO for Authentication using Keycloak](#configure-minio-for-authentication-using-keycloak)

## Configuring Authentication

### [Configure MinIO for Authentication using Keycloak](https://min.io/docs/minio/macos/operations/external-iam/configure-keycloak-identity-management.html#)

1. Configure or Create a Client for Accessing Keycloak

    Authenticate to the Keycloak `Administrative console` and navigate to `Clients`.

    Select `Create client` and follow the instructions to create a new Keycloak client for MinIO. Fill in the specified inputs as follows:

    ``` yaml
    Settings:
        General Settings:
            Client type: OpenID Connect
            Client ID: minio
            Name: MinIO
            Description: Client for MinIO
            Always display in UI: true
        Capability config:
            Client authentication: true
            Authorization: false
            Authetication flow:
                Standard flow: true
                Direct access grants: true
                Implicit flow: false
                Service accounts roles: false
                OAuth 2.0 Device Authorization Grant: false
                OIDC CIBA Grant: false
        Login settings:
            Root URL: "http://mysticstorage.local:9001"
            Home URL: "/realms/cicd/account/"
            Valid redirect URIs:
                - "*"
            Varid post logout redirect URIs:
                - ""
            Web origins:
                - "http://mysticstorage.local:9001"
    Keys:
        Use JWKS URL: true
    Advanced:
        Advanced Settings:
            Access Token Lifespan: Expires in 1 Hours
    ```

2. Create Client Scope for MinIO Client

    Navigate to the client scopes view and create a new client scope for MinIO authorization:

    ``` yaml
    Settings:
        Name: minio-authorization
        Description: Client scope for MinIO authorization
        Include in token scope: true
    ```

    Once created, select the scope from the list and navigate to mappers.

    Select `Configure a new mapper` to create a new mapping:

    ``` yaml
    Add mapper:
        Mapper type: User Attribute
        Name: minio-policy-mapper
        User Attribute: policy
        Token Claim Name: policy
        Claim JSON Type: String
        Add to ID token: true
        Multivalued: true
        Aggregate attribute values: true
    ```

    Once created, assign the Client Scope to the MinIO client.

    1. Navigate to `Clients` and select the MinIO client.
    2. Select `Client scopes`, then select `Add client scope`.
    3. Select the previously created scope and set the `Assigned type` to `default`.

3. Apply the Necessary Attribute to Keycloak Users/Groups

    You must assign an attribute named `policy` to the Keycloak Users or Groups. Set the value to any [policy](https://min.io/docs/minio/macos/administration/identity-access-management/policy-based-access-control.html#minio-policy) on the MinIO deployment.

    For Users, navigate to `Users` and select or create the User:

    ``` yaml
    Attributes:
        - Key: policy
          Value: consoleAdmin
    ```

    For Groups, navigate to `Groups` and select or create the Group:

    ``` yaml
    Attributes:
        - Key: policy
          Value: consoleAdmin
    ```

    You can assign users to groups such that they inherit the specified `policy` attribute. If you set the Mapper settings to enable `Aggregate attribute values`, Keycloak includes the aggregated array of policies as part of the authenticated user’s JWT token. MinIO can use this list of policies when authorizing the user.

    You can test the configured policies of a user by using the Keycloak API:

    ``` sh
    curl -d "client_id=minio" \
         -d "client_secret=Z6GJ9dC6VCsYP0d1PJEfWUVEjIlcircR" \
         -d "grant_type=password" \
         -d "username=lilith" \
         -d "password=pianoforte" \
         http://mysticstorage.local:8080/realms/cicd/protocol/openid-connect/token
    ```

4. Configure MinIO for Keycloak Authentication

    MinIO supports multiple methods for configuring Keycloak authentication:

    - Using the MinIO Console

        Log in as a user with administrative privileges for the MinIO deployment such as a user with the `consoleAdmin` policy.

        Select `Identity` from the left-hand navigation bar, then select `OpenID`. Select `Create Configuration` to create a new configuration.

        Enter the following information into the modal:

        ``` yaml
        Name: Keycloak
        Config URL: http://mysticstorage.local:8080/realms/cicd/.well-known/openid-configuration
        Client ID: minio
        Client Secret: Z6GJ9dC6VCsYP0d1PJEfWUVEjIlcircR
        Claim Name: ""
        Display Name: SSO_IDENTIFIER
        Claim Prefix: ""
        Scopes: minio-authorization
        Redirect URI Dynamic: true
        ```

    - Using environment variables set prior to starting MinIO

        Set the following environment variables:

        ``` yaml
        MINIO_IDENTITY_OPENID_CONFIG_URL_KEYCLOAK_PRIMARY="http://mysticstorage.local:8080/realms/cicd/.well-known/openid-configuration"
        MINIO_IDENTITY_OPENID_CLIENT_ID_KEYCLOAK_PRIMARY="minio"
        MINIO_IDENTITY_OPENID_CLIENT_SECRET_KEYCLOAK_PRIMARY="Z6GJ9dC6VCsYP0d1PJEfWUVEjIlcircR"
        MINIO_IDENTITY_OPENID_DISPLAY_NAME_KEYCLOAK_PRIMARY="SSO_IDENTIFIER"
        MINIO_IDENTITY_OPENID_SCOPES_KEYCLOAK_PRIMARY="minio-authorization"
        MINIO_IDENTITY_OPENID_REDIRECT_URI_DYNAMIC_KEYCLOAK_PRIMARY="on"
        ```
