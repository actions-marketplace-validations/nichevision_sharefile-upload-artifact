# sharefile-upload-artifact action

This action uploads a build artifact to ShareFile, and creates a Share link as part of its output.

# Usage

```yaml
steps
    - uses: nichevision/sharefile-upload-artifact@v1
    with:
        path: |
         build/*.dll
         build/*.config
        exclude: '*.pdb'
        destination: releases/
        client-id: ${{ secrets.SHAREFILE_CLIENT_ID }}
        client-secret: ${{ secrets.SHAREFILE_CLIENT_SECRET }}
        username: ${{ secrets.SHAREFILE_USERNAME }}
        password: ${{ secrets.SHAREFILE_PASSWORD }}
        subdomain: 'mycompany'
```

## Outputs

### `share-url`
##### A url for the share created for the uploaded artifact. The user login must have permissions to share.
