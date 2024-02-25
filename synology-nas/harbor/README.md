# README

- [README](#readme)
  - [Configuring Authentication](#configuring-authentication)
    - [Configure OIDC Provider Authentication](#configure-oidc-provider-authentication)
      - [Configure Your OIDC Provider](#configure-your-oidc-provider)

## Configuring Authentication

### [Configure OIDC Provider Authentication](https://goharbor.io/docs/1.10/administration/configure-authentication/oidc-auth/)

#### Configure Your OIDC Provider

- Keycloak

1. Create REALM
2. Create client for harbor

    ``` yaml
    - General Settings:
        - Client type: OpenID Connect
        - Client ID: harbor
        - Name: harbor
        - Description: Client for Harbor
        - Always display in UI: false

    - Capability config:
        - Client authentication: true
        - Authorization: false
        - Authetication flow:
            - Standard flow: true
            - Direct access grants: true
            - Implicit flow: false
            - Service accounts roles: true
            - OAuth 2.0 Device Authorization Grant: false
            - OIDC CIBA Grant: false

    - Login settings:
        - Root URL: "https://mysticstorage.local:8443"
        - Home URL: "/"
        - Valid redirect  URIs:
            - "https://mysticstorage.local:8443/*"
        - Varid post logout redirect URIs:
            - "https://mysticstorage.local:8443"
        - Web origins:
            - "https://mysticstorage.local:8443"

    ```

3. Configure Harbor

    ``` yaml
    - Authentication:
        - Auth Mode: OIDC
        - OIDC Provider Name: keycloak
        - OIDC Endpoint: https://mysticstorage.local:9443/relms/cicd
        - OIDC Client ID: harbor
        - OIDC Client Secret: ""
        - Group Claim Name: ""
        - OIDC Admin Group: ""
        - OIDC Scope: "openid,profile,email,offline_access"
        - Verify Certificate: true
        - Automatic onboarding: true
        - Username Claim: preferred_username
    ```

4. Configure Harbor for Keycloak Authentication

    Harbor supports multiple methods for configuring Keycloak authentication:
