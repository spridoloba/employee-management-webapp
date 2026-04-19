# Contributing

Thanks for contributing to `employee-management-webapp`. This file covers
branch conventions, commit style, and the local checks you should run
before opening a PR.

## Branch Conventions

- `main` — protected. Only PRs merged via GitHub; the `ci_main_push` workflow
  cuts a release tag on every merge.
- `refactoring`, `feat/*`, `fix/*`, `docs/*`, `ci/*` — work branches. Open a
  PR against `main`.

Rebase onto `main` rather than merging `main` into your branch.

## Commit Style

[Conventional Commits](https://www.conventionalcommits.org/). Examples:

```
feat(helm): add dev/prod values split and NetworkPolicy
fix(docker): use JRE 17 runtime to match build toolchain
docs(readme): document SealedSecrets workflow
ci(pr): add kubeconform + Trivy scans
chore(deps): bump spring-boot to 3.3.4
```

Scope tags in use: `docker`, `compose`, `helm`, `k8s`, `terraform`,
`ci`, `scripts`, `docs`, `deps`.

Release versioning is driven by commit messages — `feat:` bumps minor,
`fix:` bumps patch, `BREAKING CHANGE:` footer bumps major.

## Local Checks Before Pushing

Run what CI runs:

```bash
# 1. Java build
mvn -B package

# 2. Helm
helm lint helm-charts/emapp/
helm lint helm-charts/emapp/ -f helm-charts/emapp/values-dev.yaml
helm lint helm-charts/emapp/ -f helm-charts/emapp/values-prod.yaml

# 3. Kubeconform
helm template emapp helm-charts/emapp -f helm-charts/emapp/values-dev.yaml \
  | kubeconform -strict -summary -schema-location default \
      -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

# 4. Terraform
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform init -backend=false
terraform -chdir=terraform validate

# 5. Docker build (optional, slow)
docker build -t emapp:dev .

# 6. End-to-end on Kind (optional)
./scripts/dev-setup.sh
```

## Editing the Helm Chart

- Never hard-code names; use `{{ include "emapp.fullname" . }}` and the
  helpers in `_helpers.tpl`.
- Gate every optional resource by a `.Values.app.<feature>.enabled` flag.
- Put environment-agnostic defaults in `values.yaml`; put per-env
  differences in `values-dev.yaml` / `values-prod.yaml`.
- After changing templates, render both value files and diff the output
  to make sure the change only affects the environments you expect.

## Editing Terraform

- Keep providers pinned (`~>` not `>=`).
- Put variables in `variables.tf` with types, defaults, and descriptions.
- `terraform fmt` must pass — CI rejects unformatted code.

## Secrets

- Dev uses a plain `Secret` created from `.env`.
- Prod uses SealedSecrets — encrypt with `scripts/seal-secret.sh` and
  commit the `encryptedData` block into `values-prod.yaml`.
- Never commit `.env`, `terraform.tfvars`, or plaintext Kubernetes
  Secrets. `.gitignore` covers the usual suspects; if in doubt, add it.

## PR Checklist

- [ ] Conventional Commit title
- [ ] Rebased on latest `main`
- [ ] `ci_pr.yml` is green
- [ ] If touching Helm templates: `helm template` diff reviewed for both
      dev and prod values
- [ ] If touching Terraform: `terraform plan` reviewed
- [ ] Docs updated if user-facing behaviour changes
