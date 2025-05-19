# Notes

## Setup immich

1. Create admin account
2. Select Storage template `2022/Feb/IMAGE_56437`
3. Login using authentik
4. _New API key_
5. Import images

```bash
docker exec -it immich_server bash
immich login https://immich.edvardsson.dev/api API_KEY
immich upload --include-hidden --recursive directory/
```

## Hardware Acceleration

_Administration > Settings > Video Transcoding Settings > Hardware Acceleration_

_Acceleration API: Quick Sync_
_Hardware decoding: true_

Accepted video codecs

- [x] H.264
- [x] HEVC
- [x] VP9
- [ ] AV1

## Setup authentik

### In authentik

1. Create a new (Client) Application
   1.1 The Provider type should be OpenID Connect or OAuth2
   1.1 The Client type should be Confidential
   1.1 The Application type should be Web
   1.1 The Grant type should be Authorization Code
   > **Make sure that Encryption Key is empty**
2. Configure Redirect URIs/Origins

The Sign-in redirect URIs should include:

`app.immich:///oauth-callback` - for logging in with OAuth from the Mobile App
`http://DOMAIN:PORT/auth/login` - for logging in with OAuth from the Web Client
`http://DOMAIN:PORT/user-settings` - for manually linking OAuth in the Web Client

### In Immich

_Administration > Settings > Authentication Settings > OAuth_

Insert:

- ISSUER URL
- CLIENT ID
- CLIENT SECRET

## Update clip model

_Administration > Settings > Machine Learning Settings > Smart Search > Enable smart search_

[clip-models](https://immich.app/docs/features/searching#clip-models)
ViT-B-16-SigLIP2\_\_webli
