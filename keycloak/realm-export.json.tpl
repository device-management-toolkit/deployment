{
  "realm": "console",
  "enabled": true,
  "sslRequired": "none",
  "registrationAllowed": false,
  "loginWithEmailAllowed": true,
  "duplicateEmailsAllowed": false,
  "resetPasswordAllowed": false,
  "editUsernameAllowed": false,
  "bruteForceProtected": true,
  "accessTokenLifespan": 3600,
  "clients": [
    {
      "clientId": "device-management-toolkit",
      "name": "Device Management Toolkit",
      "enabled": true,
      "publicClient": true,
      "standardFlowEnabled": true,
      "implicitFlowEnabled": false,
      "directAccessGrantsEnabled": false,
      "serviceAccountsEnabled": false,
      "redirectUris": [
        "https://__MPS_COMMON_NAME__/*",
        "http://localhost:4200/*"
      ],
      "webOrigins": [
        "+"
      ],
      "attributes": {
        "pkce.code.challenge.method": "S256",
        "post.logout.redirect.uris": "+"
      },
      "protocolMappers": [
        {
          "name": "audience-self",
          "protocol": "openid-connect",
          "protocolMapper": "oidc-audience-mapper",
          "consentRequired": false,
          "config": {
            "included.client.audience": "device-management-toolkit",
            "id.token.claim": "false",
            "access.token.claim": "true"
          }
        }
      ]
    }
  ],
  "users": [
    {
      "username": "standalone",
      "enabled": true,
      "emailVerified": true,
      "credentials": [
        {
          "type": "password",
          "value": "__CONSOLE_USER_PASSWORD__",
          "temporary": false
        }
      ],
      "realmRoles": [
        "default-roles-console"
      ]
    }
  ],
  "components": {
    "org.keycloak.keys.KeyProvider": [
      {
        "name": "rsa-generated",
        "providerId": "rsa",
        "subComponents": {},
        "config": {
          "active": ["true"],
          "enabled": ["true"],
          "priority": ["100"],
          "algorithm": ["RS256"],
          "privateKey": ["__SIGNING_PRIVATE_KEY__"],
          "certificate": ["__SIGNING_CERTIFICATE__"]
        }
      }
    ]
  }
}
