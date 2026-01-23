# Deployment Information

## Glances
- **URL**: [https://glances.pxldi.de](https://glances.pxldi.de)
- **Namespace**: `glances`
- **Access**: Protected by Authelia. Requires privileged access for full host metrics.

## Obsidian LiveSync (CouchDB)
- **URL**: [https://obsidian-sync.pxldi.de](https://obsidian-sync.pxldi.de)
- **Namespace**: `obsidian-sync`
- **Access**: Basic Auth (provided by CouchDB).
- **Setup**:
  1. Create the `obsidian-sync-secret` with `COUCHDB_USER` and `COUCHDB_PASSWORD`.
  2. Log in to Fauxton UI at `https://obsidian-sync.pxldi.de/_utils/`.
  3. Create a database (e.g., `obsidian`).
  4. Configure the Obsidian LiveSync plugin with the server URL and credentials.

### Required Secrets Template
Create a file (e.g., `secret.yaml`) in `flux/apps/obsidian-sync/`, encrypt it with SOPS, and add it to `kustomization.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: obsidian-sync-secret
  namespace: obsidian-sync
type: Opaque
stringData:
  COUCHDB_USER: admin
  COUCHDB_PASSWORD: <your-secure-password>
```

## Backup & Restore
- **CouchDB**: Data is stored on Longhorn volumes.
- **Backup Strategy**: The PVC is labeled with `recurring-job.longhorn.io/source: enabled`, which triggers daily backups via the `backup-daily` RecurringJob in the `longhorn-system` namespace.
- **Verification**: Check the Longhorn UI to ensure backups are being created successfully for the `obsidian-sync` volume.
