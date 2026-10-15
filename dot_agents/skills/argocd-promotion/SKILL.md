---
name: argocd-promotion
description: Verify image selection, Argo CD synchronization, and live deployment state; use before claiming a deployment is live or when promoting an image.
license: MIT
---

# Argo CD promotion

Treat image selection and Argo CD synchronization as separate controls. Argo CD Image Updater can select an image tag and write the change back to Git or the Application; it does not, by itself, establish that Argo CD has synced that desired state to the cluster.

## Verify the tenant's policy

1. Identify the application and environment. Read that tenant's deployment workflow and Image Updater configuration. Do not infer tag formats, filters, update strategies, write-back methods, or production policy from another tenant or a general convention.
2. Check which registry tag the Image Updater accepts, how it selects among matches, and where it writes the chosen image reference. If promotion re-tags an existing build, verify the promoted tag resolves to the exact image digest already validated in the earlier environment.
3. Separately inspect the Argo CD Application's effective sync policy and desired revision. Determine whether automated sync is enabled or a human must request Sync. For ApplicationSet-managed Applications, inspect the owning ApplicationSet; editing the generated Application may not change policy.
4. Follow the tenant's documented promotion procedure. Do not trigger a manual sync merely because a new tag appeared. Conversely, do not assume a tag change will deploy automatically just because Image Updater selected it.

## Verify live state

Before reporting an environment as deployed, inspect the corresponding Argo CD Application's current sync status, health, revision, and deployed image tag or digest. A merged PR, successful build, pushed tag, Image Updater update, or requested sync alone does not prove the workload is live. If the actual state cannot be verified, say so.

Use the repository's documented Argo CD access procedure for authentication. Do not disable TLS verification, reuse realm-specific short-lived credentials, or store tokens in skill files or CLI configuration.
